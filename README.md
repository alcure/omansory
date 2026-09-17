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

This is a Hyprland Lua layout (`lua:omansory`). It does **not** ride on top of scrolling: while it is on, that workspace *is* Omansory. Windows stay axis-aligned rectangles (no L-shapes).

## Install

```sh
git clone https://github.com/alcure/omansory.git
cd omansory
chmod +x install.sh bin/omansory
./install.sh
```

The installer:

1. Symlinks the layout into `~/.config/hypr/omansory.lua` and the CLI into `~/.local/bin/omansory`.
2. Inserts marked blocks in `hyprland.lua` and `bindings.lua` (timestamped backups first).
3. **Replaces Super+Shift+O** (stock Obsidian) with the fit-masonry toggle.
4. Remaps Obsidian to **Super+Shift+Alt+O**.
5. Binds **Super+Alt+O** to center mode.
6. Copies the retrowave stills used in notifications.

## Usage

| Key | Action |
| --- | --- |
| `Super+Shift+O` | Toggle **fit** masonry on the active workspace (treemap that fills the monitor) |
| `Super+Alt+O` | Toggle **center** mode: focused window as a locked square in the middle, others as squares around it |
| `Super+Shift+K` | Pin / unpin the focused window (magenta border). Center mode pins the hub automatically. |
| `Super+Shift+←↑↓→` | Swap the focused tile with its neighbor (skips the locked hub in center mode) |
| `Super+-` / `Super++` | Grow / shrink the focused share (same keys as Omarchy) |
| `Super+Shift+-` / `Super+Shift++` | Shorten / grow the focused window vertically |
| Bar glyph `󰕰` | Next to the workspace pills; click toggles fit masonry. Magenta + ids when on. |
| `Super+Shift+Alt+O` | Obsidian (after install) |
| `Super+L` | Still Omarchy’s dwindle ↔ scrolling toggle (replaces Omansory on that workspace if you use it) |

A compact retrowave **ON / OFF** wall switch flashes under the bar on toggle.

### Fit mode (`Super+Shift+O`)

Default pack. Browsers and editors get more area than terminals. The layout fills the work area with mixed rectangles, not full-width single-app bars.

### Center mode (`Super+Alt+O`)

The **focused** window moves to a square in the middle of the workspace and is **locked** (same pin as `Super+Shift+K`, magenta border). Remaining windows become squares around that hub. Super+Shift+arrows reorders the satellites; the hub stays put. Press `Super+Alt+O` again to leave Omansory on that workspace. Pins survive toggle in `~/.local/state/omansory/locks/<workspace-id>.jsonl`.

### CLI

```sh
omansory toggle          # fit on/off
omansory center          # center mode on/off
omansory on
omansory off
omansory status
omansory mode fit|center|columns
omansory cols 3          # 1–6, or + / -
omansory lock            # Super+Shift+K
omansory swap left       # or right / up / down
omansory resize h -100
omansory resize v 100
```

Floating / pinned windows (including Omarchy `Super+O` pop-out) are left alone.

## Uninstall

```sh
omansory uninstall
```

Removes the marked config blocks and symlinks. The git clone stays.

## Requirements

Omarchy 4, Hyprland ≥ 0.55 (Lua config), `hyprctl`, `jq`, `python3`, `omarchy-notification-send`.

## License

MIT. See [CHANGELOG](CHANGELOG.md).
