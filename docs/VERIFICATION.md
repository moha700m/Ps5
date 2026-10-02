# Verification status

This table distinguishes source/build verification from device testing.
Artifact links and actual CI results are added by the Windows workflow; a
missing artifact or runtime file fails the job rather than being reported as a
successful package.

| Check | Result | Environment/evidence |
| --- | --- | --- |
| Upstream source reviewed and pinned | Verified | KytyPS5 `b3e419ff1101999525fa2d061ada1d102cf788b1`; see `docs/UPSTREAM.md` |
| Recursive dependencies and patches | Workflow-gated | Windows checkout initializes pinned refs and applies tracked patches; exact refs are in `upstream.lock`; the source ZIP includes the applied files and patches |
| Windows clang-cl/Ninja/CMake/Qt build | BLOCKED: updated run is `action_required` with zero jobs; fix not yet Windows-validated | [Run 36964603879](https://github.com/moha700m/Ps5/actions/runs/36964603879) requires owner approval. The preceding [run 36963280910](https://github.com/moha700m/Ps5/actions/runs/36963280910) failed downloading `msys2-runtime-3.5.4-2` before Qt, configure, build, CTest, or packaging. The workflow now pins vcpkg `9624c70bcc649d9ecff24185a72b12e0001de6f7`, whose lock records runtime `3.6.5-1` and its SHA-512 |
| Local Linux CMake configure | PASS with SDL console mode only | CMake 3.31.6 / Qt 6.4.2 configured the patched source with pinned FetchContent dependencies and verified the FFmpeg archive digest; the normal desktop configure lacked X11/Wayland development packages. This does not validate Windows or a desktop UI |
| Local Linux full launcher build | BLOCKED on a pinned upstream error | GCC 13.3 rejects the default constructor of `Ngs2RackOptionUnion` in `src/libs/ngs2.cpp:1183` because its members have non-trivial constructors. This is outside the UI/diagnostic patches; no emulation change was made. The required Windows clang-cl workflow remains approval-gated |
| All registered upstream CTest regressions | BLOCKED: current revision build job did not start | The workflow builds `kyty_tests` and runs CTest with `--no-tests=error`; no result exists for the current source. [Earlier run 36951845559](https://github.com/moha700m/Ps5/actions/runs/36951845559) was still at toolchain verification on the preceding revision |
| Installed EXE, Qt runtime, third-party/Qt/FFmpeg licenses, ZIP entries, archive CRC, SHA-256 | Workflow-gated | `scripts/package-windows.ps1`; missing licenses/runtime/source entries fail packaging |
| Focused localization/configuration and renderer-classification tests | PASS (local Linux, Qt 6.4.2) | `LauncherPolicyTests.cpp` compiled with clang++ and passed; covers language persistence, first-run completion persistence, translation selection, and unknown/unsupported/supported classification |
| SDL dialog and launcher-form compile checks | PASS (syntax/UI generation only) | Controller dialog compiled syntax-only against SDL3; Qt `uic` generated the patched main dialog. No GUI or physical controller was exercised |
| Packaging/source ZIP script fixture | PASS (synthetic inputs only) | Temporary fake x64 PE headers, runtime files, and license fixtures exercised archive-entry/CRC/hash checks; both SHA-256 files verified and extracted source ZIP patch detection passed. This is not a Windows build or deliverable |
| Tracked native Arabic/English UI, saved choice, RTL/LTR layout | Implemented; GUI test NOT TESTED | Built-in Qt translator and persistent interface-language setting; main UI plus selected game-library controls |
| First-run onboarding | Implemented; GUI flow NOT TESTED | Offers actual hardware report, existing game-folder settings/scan, and real SDL tester in order; every step can be skipped |
| Hardware diagnostics | Implemented; physical GPU test NOT TESTED | Queries Vulkan loader/devices and checks reported API/features/extensions; surface, queue presentation, and format checks remain explicitly unknown |
| SDL gamepad diagnostic | Implemented; physical controller test NOT TESTED | Reads live SDL axes/buttons and polls connection/hotplug; does not claim in-game mapping or haptics |
| Multi-GPU renderer selection, full dialog translation, controller deadzone/settings, save backup/export | NOT IMPLEMENTED in this change | Diagnostics enumerate adapters only; some upstream dialogs remain English; the tester does not change input mappings or add save-management behavior |
| GUI startup and RTL screenshots | NOT TESTED | No Windows desktop session/screenshots are available here |
| Physical Vulkan GPU rendering | NOT TESTED | Owner must test on a compatible Windows PC |
| Specific game boot/menu/in-game/playable test | NOT TESTED | Owner must record title, version/title ID, status, duration, and crashes |
| Physical controller live test / in-game input | NOT TESTED | Owner must connect the controller, verify the diagnostic, and test actual game input |

The new run 36964603879 is `action_required` with zero jobs, so the owner must
approve it before any Windows validation can execute. The preceding executed
run, 36963280910, failed dependency installation before Qt setup or CMake due
to the removed MSYS2 runtime `3.5.4-2`. This change pins a vcpkg revision
recording runtime `3.6.5-1` and checks `glslangValidator` 16.1.0 before
configure. Windows configure/build/CTest and both ZIPs remain unverified and
no Windows artifact exists.

## Owner hardware checks

1. On a Windows 10/11 x64 PC with a current Vulkan 1.3-capable driver, extract
   the ZIP and start `launcher.exe`; save logs and note GPU and driver versions.
2. Connect a controller supported by the pinned SDL build. Verify it is
   detected and test actual input in a legally obtained game; note wired or
   Bluetooth mode and disconnect/reconnect behavior.
3. For each game, record the exact version/title ID, whether it boots, reaches
   its menu, enters gameplay, remains playable, test duration, rendering issues,
   and crashes. Do not treat an emulator startup or CI build as a game test.
