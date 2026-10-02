# MohammedLab PS5 — complete implementation task

Owner authorization: implement this project in moha700m/Ps5 and open a draft PR. The owner wants a real Windows PS5 emulator derivative, using a credible existing engine rather than a mock UI. Finish all stages that the environment permits in the same PR; baseline source/workflow alone is not completion.

## Engine and reproducibility
Use https://github.com/KytyPS5/KytyPS5 pinned initially at b3e419ff1101999525fa2d061ada1d102cf788b1 (upstream commit timestamp 2026-10-01T21:15:53Z). Review the actual source, README, CMakeLists.txt, .gitmodules and .github/workflows/build.yml at that commit before implementing.
Record provenance in docs/UPSTREAM.md and an upstream.lock: repository URL, full SHA, dependency refs/checksums, compiler and Qt versions, patch list. Do not track floating main/latest dependencies when an exact ref is available.
Prefer importing the upstream source into this repository with provenance and preserving notices, so our native Qt changes are actually committed. A pinned submodule plus version-controlled, deterministic patches is acceptable; NEVER leave uncommitted nested-submodule edits or point at commits not reachable from an accessible repository. Initialize all recursive submodules and record FetchContent/release dependencies too.
Preserve the real engine: native guest execution, PS5 loader, filesystem, shader recompiler, guest GPU and Vulkan backend. Do not fabricate missing emulation with fake outputs, mock games, empty API stubs described as working, or PS4 emulation relabeled PS5.
Do not copy an upstream binary and present it as a build of our modifications. Do not change engine or add another emulator without documenting a concrete blocker and rationale.

## Stage 1: actual Windows baseline
Build the unmodified pinned baseline before risky changes. Use Windows Actions, VS2022 x64 developer environment, clang-cl (cl.exe is unsupported), Ninja, CMake >=3.22.1, compatible pinned Qt6 MSVC2022 x64 Concurrent/Network/Widgets, Vulkan headers/tooling and glslangValidator. Adapt the pinned upstream workflow rather than guessing toolchain versions.
Configure from the source root; build launcher, kyty_emulator, kyty_tests; run CTest with output-on-failure and build every test executable registered with CTest. Record exact commands/results. Never mask failures using continue-on-error or false success.
Use cmake --install into a staging directory, then validate real runtime files. Add dependency caching where appropriate, bounded retries for transient downloads, meaningful logs and adequate timeouts. Report action_required honestly; workflow approval needs the owner and is not a passing build.

## Stage 2: native Arabic/English product
Develop the existing Qt launcher as MohammedLab PS5, with visible upstream attribution in About. Native desktop application, not Electron/browser wrapper.
Arabic RTL and English LTR: first-run language choice, immediate switch and persistence, readable Arabic font, translated user-facing dialogs, errors and diagnostics; proper layout direction and mixed-direction paths/title IDs. Do not translate internal identifiers or break hotkeys.
First-run flow: language -> real hardware check -> add game folder -> controller check -> launch library. Inspect what this engine actually accepts. Support legally provided game directories containing eboot.bin and existing upstream .zar paths where implemented. Handle missing/unsupported/corrupt inputs gracefully, no silent fallback.
Do NOT transplant RPCS3's PS3 firmware wizard into PS5. Only ask for system files if the pinned engine demonstrably requires them; explain exact supported inputs. Do not claim that installing retail firmware creates support for games.
Keep real library discovery, launch, logs, stop/exit handling, per-game settings and save locations. Persist configuration, preserve upstream saves and provide safe backup/export. No deleting games, saves or controller drivers.
UI controls must invoke real engine settings/operations. Unsupported features must be clearly labeled and disabled, not simulated.

## Stage 3: generic compatible-PC diagnostics and controls
Target Windows10/11 x64 within actual upstream requirements. Do not tie settings to Mohammed's PC or any CPU/GPU model. Support Intel/AMD CPUs and NVIDIA/AMD/Intel GPUs when queried Vulkan features/extensions suffice. Do not promise any PC or all PS5 games.
Query OS, CPU architecture, RAM, GPU devices, Vulkan version/required capabilities, driver and storage where feasible. Report supported/unsupported/unknown with actual evidence; distinguish no Vulkan device from a test environment without physical GPU. Offer adapter choice on multi-GPU PCs and actionable Arabic/English messages without installing drivers automatically.
Keep safe upstream rendering defaults; don't impose global hacks, fake FPS gains, forced overclocking, security exclusions or administrator requirement. Advanced engine settings can be exposed only when implemented and explained.
Use upstream SDL/input integration for actual DualSense USB/Bluetooth, other supported controllers and keyboard. Implement live connection, buttons, sticks, triggers and hotplug test with real events, deadzone/settings persistence where supported. A joystick tester must not be called working in-game input without checking the engine integration. Do not promise adaptive triggers/haptics unless implemented and tested. No virtual-controller drivers required by default.

## Stage 4: distributable ZIP and source
Produce MohammedLab-PS5-Windows-x64.zip from the final modified source, SHA256 and manifest identifying our commit, upstream SHA, dependencies and configuration. Include the launcher, engine EXE, required DLLs, Qt platform plugins, translations/fonts/resources, README-AR.md/README-EN.md and license notices. Validate installed layout from actual CMake rules; don't guess archive paths.
Run archive existence/content/hash checks and dependency verification; fail packaging when required outputs are missing. Separate always-uploaded diagnostics/test reports from successfully validated binary uploads. Use if-no-files-found:error for required binaries.
End user: extract ZIP -> double-click launcher; no build tools, Python, terminal, manual JSON editing or admin privileges. A portable ZIP can contain multiple runtime files; do not claim a single self-contained EXE unless actually produced.
Include complete corresponding source archive or a precisely reproducible source delivery with all dependencies, patch application, build scripts and exact refs. Preserve GPL-2.0-only, original Kyty MIT notice, component licenses and original copyrights. Inventory actual Qt/SDL/FFmpeg and other bundled licenses. No Sony firmware, SDK, keys, copyrighted games/assets or third-party secrets in repo, CI or artifacts.

## Verification and final delivery
Add meaningful automated tests for new config, localization, file validation, diagnostics classification and packaging. Run upstream regressions and Windows builds after final changes. Test paths with spaces/Arabic text, missing DLL/resource, invalid game path, unsupported GPU/unknown capability, config restart, controller disconnect, clean extraction and source reproduction as feasible.
Write docs/VERIFICATION.md with a table of checks, exact commit/runner/environment, result and evidence links. Explicitly separate:
1. source/build/unit tests/ZIP validation in CI;
2. GUI startup/RTL screenshots actually tested;
3. physical GPU rendering;
4. specific owned game/version/title ID (boot/menu/in-game/playable, duration/crashes);
5. real controller input in-game.
Hosted CI compilation or software rendering DOES NOT establish physical GPU, game compatibility, FPS or DualSense functionality. Leave unavailable physical tests marked NOT TESTED with simple owner steps. No fabricated screenshots, test results or compatibility claims from upstream screenshots.
Deliver artifact download links, checksum, build evidence, source link, implementation checklist and remaining device tests. Keep issue open while required code/packaging work remains. If external hardware is the only remaining verification gap, deliver all feasible code/build artifacts with an honest limitation report.
Start with baseline, then CONTINUE stages 2-4 within the same draft PR. If a hosted build needs approval, implement independent source/UI/tests while awaiting it; do not stop at only a submodule and workflow. If blocked, state the exact error, attempted fix and actionable next step.
Do not merge PRs, publish Releases or contact/comment/open issues or PRs in KytyPS5 or any other upstream repository. Work only in the owner's moha700m/Ps5 repository; existing PS3 project is independent.
