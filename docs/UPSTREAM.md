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
containing those pins. The FFmpeg source revision is
the pinned recursive gitlink; the actual static Windows archive digest is
recorded separately. The FFmpeg install step contributes its copyright,
build-log, and source provenance under `licenses/ffmpeg`. Qt license texts
and the installed vcpkg-port notices (glslang, SPIRV-Tools and SPIRV-Headers)
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
./_Build/vcpkg/vcpkg.exe install 'glslang[tools,opt]:x64-windows'
./scripts/apply-upstream-patches.ps1
cmake -S upstream/KytyPS5 -B _Build/windows -G Ninja `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl `
  -DCMAKE_PREFIX_PATH="$env:Qt6_DIR"
cmake --build _Build/windows --target launcher kyty_emulator kyty_tests
ctest --test-dir _Build/windows --output-on-failure --no-tests=error
```

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
