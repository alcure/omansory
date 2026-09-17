<p align="center">
  <img src="share/omansory/on.jpg" alt="Omansory — retrowave masonry for Omarchy" width="100%">
</p>

<p align="center">
  <a href="README.pt-BR.md">Português (Brasil)</a>
  ·
  <a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-aab3bc?labelColor=0b0f14"></a>
  <img alt="Omarchy 4" src="https://img.shields.io/badge/Omarchy-4-fda52b?labelColor=0b0f14">
  <img alt="Hyprland 0.55+" src="https://img.shields.io/badge/Hyprland-0.55%2B-05d9e8?labelColor=0b0f14">
</p>

# Omansory

Per-workspace **masonry** for [Omarchy](https://omarchy.org/) / Hyprland. Shortcuts pack tiled windows on **the active workspace only**. Other workspaces keep dwindle, scrolling, or whatever they already use.

This is a Hyprland Lua layout (`lua:omansory`). It does **not** ride on top of scrolling: while it is on, that workspace *is* Omansory. Windows stay axis-aligned rectangles (no L-shapes). Inner gaps are turned off on that workspace so tiles meet without a wallpaper strip.

## Install

```sh
git clone https://github.com/alcure/omansory.git
cd omansory
chmod +x install.sh bin/omansory
./install.sh
```

The installer:

1. Symlinks the layout into `~/.config/hypr/omansory.lua` and the CLI into `~/.local/bin/omansory`.
2. Inserts marked `-- BEGIN omansory` blocks in `hyprland.lua` and `bindings.lua` (timestamped backups first).
3. **Replaces Super+Shift+O** (stock Obsidian) with the fit-masonry toggle.
4. Remaps Obsidian to **Super+Shift+Alt+O**.
5. Binds **Super+Alt+O** to center mode.
6. Enables the bar widget **to the right of the clock**.
7. Copies the retrowave stills used in notifications.

If `omarchy refresh hyprland` wipes those blocks, run `./install.sh` again.

## Usage

| Key | Action |
| --- | --- |
| `Super+Shift+O` | Toggle **Masonry** (fit) on the active workspace |
| `Super+Alt+O` | Toggle **Center** mode (same workspace). Second press turns Omansory off |
| `Super+Shift+K` | Pin / unpin the focused window (magenta border). Center pins the hub automatically |
| `Super+Shift+←↑↓→` | Swap the focused tile with its neighbor (skips the locked hub in center) |
| `Super+-` / `Super++` | Grow / shrink the focused share (same keys as Omarchy) |
| `Super+Shift+-` / `Super+Shift++` | Shorten / grow the focused window vertically |
| Bar glyph | Right of the clock. **2×2 squares** = Masonry Mode; **inner square + frame** = Central Mode. Click toggles fit |
| `Super+Shift+Alt+O` | Obsidian (after install) |
| `Super+L` | Omarchy dwindle ↔ scrolling (replaces Omansory on that workspace) |

A compact retrowave wall switch flashes under the bar: **MASONRY ON / OFF** or **CENTER ON / CENTER OFF**.

### Fit mode (`Super+Shift+O`)

Squarified treemap that **fills the work area**. Browsers and editors get more space than terminals. No full-width single-app bars, no overlapping tiles, leftover holes are absorbed by a neighbor. Inner `gaps_in` is 0 while Omansory is on.

### Center mode (`Super+Alt+O`)

The **focused** window becomes the hub, sized like **scrolling with one app** on this machine (`layout.single_window_aspect_ratio` when that Omarchy toggle is on, otherwise `scrolling.column_width`). It is locked (magenta border). Other windows fill the leftover ring. Super+Shift+arrows reorder satellites; the hub stays. Press again to turn Center (and Omansory) **off**. Use Super+Shift+O to switch to fit without leaving Omansory.

### CLI

```sh
omansory toggle          # fit on/off
omansory center          # center on/off (Super+Alt+O)
omansory on
omansory off
omansory status [--json]
omansory mode fit|center|columns
omansory cols 3          # 1–6, or + / -
omansory lock            # Super+Shift+K
omansory swap left       # or right / up / down
omansory resize h -100
omansory resize v 100
omansory reset           # recompute packing
omansory refresh         # reload the bar plugin; do not restart the shell
omansory install
omansory uninstall
```

Floating / pinned windows (including Omarchy `Super+O` pop-out) are left alone.

Reload the bar with `omansory refresh` or `omarchy-shell shell rescanPlugins`. **Do not** `omarchy restart shell` or force a renderer reload to pick up plugin tweaks — that leaves unpainted strips.

## Uninstall

```sh
omansory uninstall
```

Removes the marked config blocks and symlinks. The git clone stays. Inner gaps return to Omarchy’s default on that workspace.

## Requirements

Omarchy 4, Hyprland ≥ 0.55 (Lua config), `hyprctl`, `jq`, `python3`, `omarchy-notification-send`.

## License

MIT. See [CHANGELOG](CHANGELOG.md).
