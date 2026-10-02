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
because it does not create a renderer. It lists adapters but does not offer
renderer selection or install drivers.

The first-run flow offers the real hardware report, the upstream game-folder
configuration and scan, and the SDL gamepad tester in sequence; each can be
skipped. The SDL test displays live axes, buttons, and connection state. It is
not proof of in-game input, adaptive triggers, or haptics. This onboarding is
not a complete compatibility wizard.

See `README-AR.md` for Arabic notes and the source and license notices for
provenance and redistribution terms.
