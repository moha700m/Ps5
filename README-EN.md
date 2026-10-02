# MohammedLab PS5

This Windows x64 build is based on the pinned KytyPS5 source revision recorded
in `build-manifest.txt`. Extract the ZIP and start `launcher.exe`. The emulator
requires a compatible Vulkan 1.3 graphics driver; hardware compatibility is not
guaranteed.

The upstream launcher and emulator are experimental. Game compatibility varies
by title, game version, GPU, and driver. This package contains no games, PS5
firmware, Sony SDK, or keys. Only use game data you are legally entitled to use.

Choose English or Arabic at first launch or switch immediately from the
language selector; the preference is saved for the next start. The current
Arabic translation covers the main launcher and selected library controls;
some advanced settings and dialogs remain in English. The hardware diagnostic
queries the installed Vulkan loader and enumerated devices, checks selected
renderer requirements, and marks surface/presentation compatibility unknown
because it does not create a renderer. It does not install drivers.

The SDL controller test displays live gamepad axes, buttons, and connection
state. This is an input diagnostic, not proof of in-game input, adaptive
triggers, or haptics. The first-run flow adds a language prompt and retains the
upstream real game-folder discovery; it is not a complete guided hardware
wizard.

See `README-AR.md` for Arabic notes and the source and license notices for
provenance and redistribution terms.
