# Changelog

## 1.2.1 — 2026-09-17

- Fit mode now fills the monitor with a weighted binary split: every window stays on-screen (no tile dropped “below”), leftover gaps are gone, and browsers/editors outrank terminals.

## 1.2.0 — 2026-09-17

- Bar glyph next to the workspaces (magenta when masonry is on, with the workspace ids) and a retrowave overlay flash on toggle.
- Default pack is interlocking skyline tiles (still rectangles — Wayland cannot clip L-shapes). `omansory mode columns` restores the old grid.

## 1.1.1 — 2026-09-17

- Fix overlapping / ghost windows when leaving Hyprland scrolling: ignore tape geometry, disable popin during the switch, drop leftover fullscreen, reset the masonry pack, and force a renderer reload.

## 1.1.0 — 2026-09-17

- Honor Omarchy window-resize keys on an Omansory workspace: Super± (width) and Super+Shift± (height), plus the Alt/Ctrl fine and coarse variants.
- Keep column membership stable while resizing; Super± falls through to stock `resizeactive` when Omansory is off.

## 1.0.0 — 2026-09-17

- First release: Lua masonry layout `lua:omansory` for Hyprland 0.55+ / Omarchy.
- Per-workspace toggle with Super+Shift+O (replaces stock Obsidian; Obsidian moves to Super+Shift+Alt+O).
- Retrowave on/off notifications with the Omarchy typeface (JetBrainsMono Nerd Font).
