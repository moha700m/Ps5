# Verification status

This table distinguishes source/build verification from device testing.
Artifact links and actual CI results are added by the Windows workflow; a
missing artifact or runtime file fails the job rather than being reported as a
successful package.

| Check | Result | Environment/evidence |
| --- | --- | --- |
| Upstream source reviewed and pinned | Verified | KytyPS5 `b3e419ff1101999525fa2d061ada1d102cf788b1`; see `docs/UPSTREAM.md` |
| Recursive dependencies and patches | Workflow-gated | Windows checkout initializes pinned refs and applies tracked patches; exact refs are in `upstream.lock`; the source ZIP includes the applied files and patches |
| Windows clang-cl/Ninja/CMake/Qt build | Latest run BLOCKED while building the pinned SwiftShader test ICD; Qt/Kyty configure, build, CTest, and packaging skipped | [Run 36985972744](https://github.com/moha700m/Ps5/actions/runs/36985972744), attempt 2, job [110771139730](https://github.com/moha700m/Ps5/actions/runs/36985972744/job/110771139730): SwiftShader reached build step 964/1201, then clang-cl treated unsupported `/MP` as `-Werror,-Wunused-command-line-argument` in `src/Reactor/Assert.cpp`. A tracked CI-only SwiftShader patch now omits `/MP` only for Clang; this follow-up has not run yet. The earlier run [36964661487](https://github.com/moha700m/Ps5/actions/runs/36964661487), job [110708466135](https://github.com/moha700m/Ps5/actions/runs/36964661487/job/110708466135), built Qt/Kyty targets but had 32/51 CTest passes; package skipped |
| Local Linux CMake configure | PASS with SDL console mode only | CMake 3.31.6 / Qt 6.4.2 configured the patched source with pinned FetchContent dependencies and verified the FFmpeg archive digest; the normal desktop configure lacked X11/Wayland development packages. This does not validate Windows or a desktop UI |
| Local Linux full launcher build | BLOCKED on a pinned upstream error | GCC 13.3 rejects the default constructor of `Ngs2RackOptionUnion` in `src/libs/ngs2.cpp:1183` because its members have non-trivial constructors. This is outside the UI/diagnostic patches; no emulation change was made. The Windows clang-cl configure/build completed successfully in run 36964661487 |
| CTest independent of Vulkan device | 32/32 PASS in run 36964661487 | Windows 2022 clang-cl/Ninja; full job log shows all 32 non-Vulkan-labeled tests passed |
| Vulkan-dependent CTest group | NOT TESTED successfully in run 36964661487 | 19 tests failed with missing Vulkan loader/device or SDL Vulkan window creation; follow-up labels these tests and requires a successful SwiftShader Vulkan 1.3 probe before running. If unavailable, exact labels are reported NOT TESTED and other tests remain required |
| Installed EXE, Qt runtime, third-party/Qt/FFmpeg licenses, ZIP entries, archive CRC, SHA-256 | NOT PRODUCED; package step skipped because the latest job failed building SwiftShader | `scripts/package-windows.ps1`; required EXEs, licenses, runtime/source entries and hashes fail packaging when missing |
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

Run 36985972744 (attempt 2) confirmed pinned source checkout and dependency
installation, then failed compiling SwiftShader: its MSVC-oriented `/MP` flag
became an error under clang-cl's warning-as-error settings. The tracked,
test-only patch guards only that option from clang-cl; it does not weaken
warnings or change the emulator source. The fix and downstream Vulkan probe,
CTest policy, and packaging have not yet run. Earlier run 36964661487 confirms
Qt/Kyty configure and build succeeded, but CTest passed 32/51 and packaging was
skipped. No Windows ZIP is available. Software rendering, if validated in CI,
does not verify physical GPUs or games.

## Owner hardware checks

1. On a Windows 10/11 x64 PC with a current Vulkan 1.3-capable driver, extract
   the ZIP and start `launcher.exe`; save logs and note GPU and driver versions.
2. Connect a controller supported by the pinned SDL build. Verify it is
   detected and test actual input in a legally obtained game; note wired or
   Bluetooth mode and disconnect/reconnect behavior.
3. For each game, record the exact version/title ID, whether it boots, reaches
   its menu, enters gameplay, remains playable, test duration, rendering issues,
   and crashes. Do not treat an emulator startup or CI build as a game test.
