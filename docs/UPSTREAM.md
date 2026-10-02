# Pinned engine provenance

MohammedLab PS5 includes the source of [KytyPS5](https://github.com/KytyPS5/KytyPS5)
as the recursive submodule `upstream/KytyPS5`. The gitlink pins
`b3e419ff1101999525fa2d061ada1d102cf788b1` (2026-10-01), whose parent tree
contains the real guest loader/execution path, PS5 guest-GPU command processing,
shader recompiler, Vulkan host renderer, Qt launcher, and SDL3 input integration.
This is an experimental emulator baseline, not a compatibility guarantee.

`upstream.lock` records the upstream submodule commits, the pinned
FetchContent refs visible in `3rdparty/CMakeLists.txt`, and the Windows tool
inputs. To reproduce the checkout, use:

```powershell
git submodule update --init --recursive
git -C upstream/KytyPS5 rev-parse HEAD
```

The root workflow builds this pinned source with recursive dependencies; it
does not download or substitute an upstream executable. Upstream's own
`3rdparty/patches/zarchive-reader.patch` is part of the pinned source and is
applied by its CMake FetchContent declaration. The vcpkg registry is selected
by the `windows-2022` runner image and is not independently pinned in this
repository; its installed glslang version is recorded in the workflow log.

Upstream code and dependency license notices remain in the recursive source
delivery. The engine is GPL-2.0-only; the original Kyty MIT notice and each
third-party license must be retained with any distribution. No Sony system
software, SDK, keys, or game content is included.
