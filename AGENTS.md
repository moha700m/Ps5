# Agent instructions

Read docs/IMPLEMENTATION_TASK.md completely before implementation. It is the owner's authorized full scope.

- Implement in moha700m/Ps5 only. Open a draft PR; no merging, publishing Releases, or upstream communication.
- Start from KytyPS5/KytyPS5 commit b3e419ff1101999525fa2d061ada1d102cf788b1. Review actual source and pinned upstream Windows workflow.
- Keep source and dependencies reproducible, recursive submodules initialized, and native modifications committed. No dirty nested source, floating versions or binaries substituted for source builds.
- Use clang-cl, Ninja, CMake and Qt6 on Windows. Preserve native execution, shader and GPU engines.
- Baseline/workflow is only stage one. Continue Arabic/English Qt setup, hardware diagnostics, real controller integration, final ZIP and matching source in the same PR.
- No fake functional controls, tests, compatibility claims or FPS claims. Clearly distinguish actual CI checks from unavailable physical GPU/game/controller tests.
- Preserve licenses/copyrights (GPL-2.0-only, original Kyty MIT and dependencies). Never include Sony firmware, games, keys, SDK or secrets.
- Required artifacts must fail if missing; validate EXEs, runtime resources, archive contents and checksums. Reports alone are not program delivery.
- Do not change moha700m/Ps3; that is an independent project.
