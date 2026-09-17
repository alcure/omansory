# Changelog

## 1.1.1 — 2026-09-17

- Fix overlapping / ghost windows when leaving Hyprland scrolling: ignore tape geometry, disable popin during the switch, drop leftover fullscreen, reset the masonry pack, and force a renderer reload.

## 1.1.0 — 2026-09-17

- Honor Omarchy window-resize keys on an Omansory workspace: Super± (width) and Super+Shift± (height), plus the Alt/Ctrl fine and coarse variants.
- Keep column membership stable while resizing; Super± falls through to stock `resizeactive` when Omansory is off.

## 1.0.0 — 2026-09-17

- First release: Lua masonry layout `lua:omansory` for Hyprland 0.55+ / Omarchy.
- Per-workspace toggle with Super+Shift+O (replaces stock Obsidian; Obsidian moves to Super+Shift+Alt+O).
- Retrowave on/off notifications with the Omarchy typeface (JetBrainsMono Nerd Font).
