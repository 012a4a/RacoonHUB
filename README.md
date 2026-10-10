# RacoonHUB

Pull A Sword script using WindUI, tested with the Real executor on Windows.

## Private access and running on another machine

Keep the GitHub repository PRIVATE. Sign into the owning GitHub account on each machine, download the repository ZIP, and extract it. Run Install-RacoonHUB.ps1 in PowerShell to copy the script and photo into Real's folders. Then open Scripts/MCP/RacoonHUB.luau in Real while playing Pull A Sword.

The installer uses the current Windows user's LocalAppData path; it does not depend on the original machine's username. It copies files only and does not run the Luau code. No GitHub token or other credentials are included.

Privacy protects repository access. Anyone allowed to download or execute a client-side script can inspect or copy the delivered code. There is no permanent public raw link for a private GitHub file. For personal use, authenticated download is the simplest way to preserve repository privacy.

## Controls

The draggable raccoon photo opens/closes the menu and stays visible while open. F6 toggles auto-hit.

Combat includes auto-hit, walking approach, zone-ordered target selection, troopers-only targeting and optional nearby Bennet reward collection at 100%. Sword Drops includes name/rarity ESP, rarity filters and model previews. Loot includes auto-pull, optional return after a completed pull, and unlocked-only selling.

Auto-hit, approach, troopers-only mode, auto-sell and Bennet auto-claim start OFF. Auto-pull starts ON. No rebirth is performed.

Bennet collection requires being within ten studs and recognizes server-offered reward answers. A real 100% reward claim has not yet been verified. Physical icon dragging and the new post-pull return still need live interaction verification. Other executors are not guaranteed compatible.

## Files

- RacoonHUB.luau: script.
- racoon-hub.jpg: menu photo.
- Install-RacoonHUB.ps1: local Windows installer.
- short-events.md: notes checked against game version 1179.

