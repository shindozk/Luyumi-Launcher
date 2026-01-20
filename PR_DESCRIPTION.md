Profile System & Mod Loading Fixes

Added a full profile system and fixed a few critical mod loading issues.

What changed

Profiles — Implemented proper profile management (create, switch, delete). Each profile now has its own isolated mod list.

Mod Isolation — Fixed ModManager so mods are strictly scoped to the active profile. Browsing and installing only affects the selected profile.

Critical Fix — Fixed a path bug where mods were being saved to ~/AppData/Local on macOS (Windows path) instead of ~/Library/Application Support. Mods now save to the correct location and load correctly in-game.

Stability — Added an auto-sync step before every launch to make sure the physical mods folder always matches the active profile.

UI — Added a profile selector dropdown and a profile management modal.