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
fails on unexpected dirty source. The CI build and source archive therefore
contain the same native changes without committing edits inside nested
submodules. One patch updates the pinned FFmpeg submodule CMake recipe to use
the exact Windows x64 release digest in `upstream.lock`, retry transient
downloads at most three times, and support source archives without Git
metadata.

The Windows workflow checks out vcpkg at the immutable commit in the lock,
verifies the `glslang` 15.1.0 port and features, then caches the resulting
installed tree under a key containing that pin. The FFmpeg source revision is
the pinned recursive gitlink; the actual static Windows archive digest is
recorded separately. The FFmpeg install step contributes its copyright,
build-log, and source provenance under `licenses/ffmpeg`.

The recursive source ZIP includes initialized submodule source files, the
patches and their application script, all pinned refs, and Qt license texts.
The exact FetchContent commits remain fetched by CMake during a source rebuild;
no generated `_Build` directory is required. A source ZIP is a source delivery,
not a prebuilt development environment.

Upstream code and dependency license notices remain in the recursive source
delivery. The engine is GPL-2.0-only; the original Kyty MIT notice and each
third-party license must be retained with any distribution. The package
script adds Qt's installed license texts and fails if those or FFmpeg
provenance files are missing. No Sony system software, SDK, keys, or game
content is included.
