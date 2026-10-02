# Verification status

This table distinguishes source/build verification from device testing.
Artifact links and actual CI results are added by the Windows workflow; a
missing artifact or runtime file fails the job rather than being reported as a
successful package.

| Check | Result | Environment/evidence |
| --- | --- | --- |
| Upstream source reviewed and pinned | Verified | KytyPS5 `b3e419ff1101999525fa2d061ada1d102cf788b1`; see `docs/UPSTREAM.md` |
| Recursive dependencies | Workflow-gated | Windows checkout initializes recursive submodules; package script checks source entries and records refs |
| Windows clang-cl/Ninja/CMake/Qt build | Not yet run in this session | Requires the `windows-2022` Actions runner; inspect the workflow run before claiming success |
| All registered upstream CTest regressions | Not yet run in this session | The workflow builds `kyty_tests` and runs CTest with `--no-tests=error` |
| Installed EXE, Qt runtime, ZIP entries, archive CRC, SHA-256 | Workflow-gated | `scripts/package-windows.ps1`; only uploaded on success |
| Arabic/English native UI and RTL layout | NOT IMPLEMENTED | The included UI remains the pinned upstream launcher |
| GUI startup and RTL screenshots | NOT TESTED | No Windows desktop session/screenshots are available here |
| Physical Vulkan GPU rendering | NOT TESTED | Owner must test on a compatible Windows PC |
| Specific game boot/menu/in-game/playable test | NOT TESTED | Owner must record title, version/title ID, status, duration, and crashes |
| Physical controller live test / in-game input | NOT TESTED | Owner must connect the controller and test actual game input; no separate tester is claimed |

## Owner hardware checks

1. On a Windows 10/11 x64 PC with a current Vulkan 1.3-capable driver, extract
   the ZIP and start `launcher.exe`; save logs and note GPU and driver versions.
2. Connect a controller supported by the pinned SDL build. Verify it is
   detected and test actual input in a legally obtained game; note wired or
   Bluetooth mode and disconnect/reconnect behavior.
3. For each game, record the exact version/title ID, whether it boots, reaches
   its menu, enters gameplay, remains playable, test duration, rendering issues,
   and crashes. Do not treat an emulator startup or CI build as a game test.
