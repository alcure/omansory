# Changelog

## 1.5.1 — 2026-09-17

- Namespaced shell plugin id `alcure.omansory` for the [Omarchy plugin marketplace](https://plugins.omarchy.org/).
- Install via `omarchy plugin add https://github.com/alcure/omansory.git --enable`; Hyprland binds still need `install.sh`.
- Root `preview.png` for the directory listing.

## 1.5.0 — 2026-09-17

- Center hub matches a single window in scrolling (square aspect if that Omarchy toggle is on, otherwise `column_width`).
- Super+Alt+O toggles Center on/off and flashes **CENTER ON / CENTER OFF**; fit still flashes **MASONRY ON / OFF**.
- Bar glyph sits to the right of the clock: 2×2 squares for Masonry Mode, framed inner square for Central Mode.
- Fit packing does not overlap tiles, absorbs leftover holes, and sets `gaps_in` to 0 on Omansory workspaces.
- `omansory refresh` reloads the bar plugin without restarting the shell (avoids unpainted strips).

## 1.4.0 — 2026-09-17

- Center mode (`Super+Alt+O` / `omansory center`): focused window locked as a middle square, others as squares around it; satellites still swap with Super+Shift+arrows.

## 1.3.4 — 2026-09-17

- Super+Shift+Arrows swap the focused tile with its neighbor while Omansory is on (same keys fall through to Hyprland swap when it is off).

## 1.3.3 — 2026-09-17

- On/off flash is a compact English wall rocker (ON / OFF only). Layout toggle paints full frames instead of reloading the renderer, then shows the switch.

## 1.3.2 — 2026-09-17

- On/off flash is a small Winmarchy-style card under the bar: retrowave hero, scan line, pop/check, no full-screen dim.

## 1.3.1 — 2026-09-17

- Layout toggle waits for the new tiles, damages the whole monitor, reloads the renderer twice while popin is off, then restores animations — so leftover unrendered strips do not stick.

## 1.3.0 — 2026-09-17

- Fit mode uses a squarified treemap: mixed rectangles that fill the screen, no full-width single-app bars, still no L-shapes.
- Super+Shift+K (`omansory lock`) pins a window’s relative box per workspace, paints a magenta border, and restores that box when masonry is toggled back on.

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
