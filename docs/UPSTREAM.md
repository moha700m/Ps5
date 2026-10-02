# Pinned engine provenance

MohammedLab PS5 includes the source of [KytyPS5](https://github.com/KytyPS5/KytyPS5)
as the recursive submodule `upstream/KytyPS5`. The gitlink pins
`b3e419ff1101999525fa2d061ada1d102cf788b1` (2026-10-01), whose parent tree
contains the real guest loader/execution path, PS5 guest-GPU command processing,
shader recompiler, Vulkan host renderer, Qt launcher, and SDL3 input integration.
This is an experimental emulator baseline, not a compatibility guarantee.

`upstream.lock` records the upstream submodule commits, the pinned
FetchContent refs visible in `3rdparty/CMakeLists.txt`, the vcpkg and glslang
revisions, the Windows FFmpeg artifact checksum, and build-action pins. To
reproduce the checkout, use:

```powershell
git submodule update --init --recursive
git -C upstream/KytyPS5 rev-parse HEAD
```

The root workflow applies the version-controlled patches in
`patches/upstream/` to clean recursive submodule worktrees before configuring.
`scripts/apply-upstream-patches.ps1` checks each patch before applying and
fails on unexpected dirty Git checkouts. It also recognizes an already-patched
source ZIP, which has no `.git` metadata. The CI build and source archive
therefore contain the same native changes without committing edits inside
nested submodules. One patch updates the pinned FFmpeg submodule CMake recipe
to use the exact Windows x64 release digest in `upstream.lock`, retry transient
downloads at most three times, and support source archives without Git
metadata.
The small Vulkan-Hpp patch makes existing extent, offset, and descriptor-value
assignments explicit; it resolves ambiguous assignment errors found in the
local pinned-source build without changing renderer behavior.

The Windows workflow checks out vcpkg at the immutable commit in the lock.
That revision records the MSYS2 runtime archive name and SHA-512 in the lock
(3.6.5-1), replacing the deleted 3.5.4-2 package used by the previous pin. It
verifies the `glslang` 16.1.0 port and `glslangValidator` version, with the
requested `tools,opt` features, then caches the installed tree under a key
containing those pins. It also installs pinned Vulkan-Loader and Vulkan-Tools
1.4.328.0 (their exact source SHA-512 hashes and Apache-2.0 licenses are in
`upstream.lock`) for the runtime and `vulkaninfo` probe, and builds the Apache-2.0
SwiftShader software ICD from the exact source commit in `upstream.lock`. Before
configuration, CI applies the tracked test-only patch
`patches/ci/0001-swiftshader-no-mp-for-clang-cl.patch`, which omits SwiftShader's
unsupported MSVC `/MP` option only for clang-cl; Ninja supplies build parallelism
and compiler warnings remain errors. The patch is checked and its SHA-256 is
recorded in the package manifest and recursive source archive. The software device is
used only for CI Vulkan-dependent tests; it is not included in the application
ZIP and does not represent physical-GPU validation. Its Apache-2.0 license is
collected in the binary and source archives. The FFmpeg source revision is
the pinned recursive gitlink; the actual static Windows archive digest is
recorded separately. The FFmpeg install step contributes its copyright,
build-log, and source provenance under `licenses/ffmpeg`. Qt license texts
and the installed vcpkg-port notices (glslang, SPIRV-Tools, SPIRV-Headers,
Vulkan-Tools, Vulkan-Loader, Volk and Vulkan-Headers)
are collected outside the engine tree into both binary and source deliveries.

The recursive source ZIP includes initialized submodule source files, the
already-applied native changes, their patches and application script, all
pinned refs, and Qt/vcpkg license texts. It omits Git metadata and generated
`_Build` files. `FetchContent` dependencies are fetched at the immutable
revisions in `upstream.lock` during configuration; FFmpeg's Windows archive is
downloaded only if missing and is verified against its recorded SHA-256.

To rebuild from the source ZIP on Windows, install the pinned Qt 6.10.3
MSVC2022 x64 package, Visual Studio 2022 x64 environment, CMake, Ninja and
clang-cl, then restore vcpkg and build:

```powershell
git clone https://github.com/microsoft/vcpkg.git _Build/vcpkg
git -C _Build/vcpkg checkout 9624c70bcc649d9ecff24185a72b12e0001de6f7
./_Build/vcpkg/bootstrap-vcpkg.bat -disableMetrics
./_Build/vcpkg/vcpkg.exe install 'glslang[tools,opt]:x64-windows' 'vulkan-tools:x64-windows' 'vulkan-loader:x64-windows'
./scripts/apply-upstream-patches.ps1
cmake -S upstream/KytyPS5 -B _Build/windows -G Ninja `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl `
  -DCMAKE_PREFIX_PATH="$env:Qt6_DIR"
cmake --build _Build/windows --target launcher kyty_emulator kyty_tests
```

To reproduce CI's software Vulkan tests, restore SwiftShader at the immutable
commit in `upstream.lock`:

```powershell
git clone https://github.com/google/swiftshader.git _Build/swiftshader
git -C _Build/swiftshader checkout 1e80438d2b93ef36a7c05f8d2b81233bac0e3d16
$swiftShaderPatch = (Resolve-Path patches/ci/0001-swiftshader-no-mp-for-clang-cl.patch).Path
git -C _Build/swiftshader apply --check $swiftShaderPatch
git -C _Build/swiftshader apply $swiftShaderPatch
cmake -S _Build/swiftshader -B _Build/swiftshader-build -G Ninja `
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-cl `
  -DCMAKE_CXX_COMPILER=clang-cl -DSWIFTSHADER_BUILD_TESTS=OFF `
  -DSWIFTSHADER_BUILD_BENCHMARKS=OFF -DSWIFTSHADER_BUILD_PVR=OFF
cmake --build _Build/swiftshader-build --target vk_swiftshader
$env:VK_ICD_FILENAMES = (Resolve-Path _Build/swiftshader-build/Windows/vk_swiftshader_icd.json)
$env:PATH = "$(Resolve-Path _Build/vcpkg/installed/x64-windows/bin);$env:PATH"
& _Build/vcpkg/installed/x64-windows/tools/vulkan-tools/vulkaninfo.exe
```

If the output enumerates Vulkan 1.3 SwiftShader, run the full test suite:

```powershell
ctest --test-dir _Build/windows --output-on-failure --no-tests=error
```

If no device is enumerated, keep all non-device tests required and list the
environment-limited group explicitly:

```powershell
ctest --test-dir _Build/windows -N -L requires-vulkan-device
ctest --test-dir _Build/windows -LE requires-vulkan-device --output-on-failure --no-tests=error
```

CI checks that `vulkaninfo` enumerates a Vulkan 1.3 SwiftShader device and
reports the engine's required device extensions and Vulkan 1.2/1.3/core
features before
running tests labeled `requires-vulkan-device`. If no device is available,
only those explicitly labeled tests are reported NOT TESTED; all independent
CTest tests remain mandatory. The test ICD and vulkaninfo are not bundled with
the emulator and do not establish physical GPU or game compatibility.

The patch script detects that the included source patches are already applied.
For a Git checkout instead, initialize recursive submodules first and run the
script only on clean pinned trees. This is a reproducible build recipe, not
evidence that a build or the final package has succeeded; see
`docs/VERIFICATION.md`.

Upstream code and dependency license notices remain in the recursive source
delivery. The engine is GPL-2.0-only; the original Kyty MIT notice and each
third-party license must be retained with any distribution. The package script
adds Qt/vcpkg notices and fails if required Qt, vcpkg or FFmpeg provenance
files are missing. No Sony system software, SDK, keys, or game content is
included.
