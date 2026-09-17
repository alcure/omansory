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

Per-workspace **masonry** for [Omarchy](https://omarchy.org/) / Hyprland. One shortcut packs tiled windows into shortest-column stacks on **the active workspace only**. Other workspaces keep dwindle, scrolling, or whatever they already use.

This is a Hyprland Lua layout (`lua:omansory`), not a Quickshell bar widget. It does **not** ride on top of scrolling: while it is on, that workspace *is* Omansory.

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
3. **Replaces Super+Shift+O** (stock Obsidian) with the Omansory toggle.
4. Remaps Obsidian to **Super+Shift+Alt+O**.
5. Copies the retrowave on/off stills used in notifications.

## Use

| Key | Action |
| --- | --- |
| `Super+Shift+O` | Toggle masonry on the **active** workspace |
| `Super+Shift+Alt+O` | Obsidian (after install) |
| `Super+L` | Still Omarchy's dwindle ↔ scrolling toggle (overwrites this workspace if you use it) |

```sh
omansory toggle
omansory on
omansory off
omansory status
omansory cols 3    # 1–6, or + / -
```

Turning it **on** shows the magenta-grid card (ON · ATIVO). Turning it **off** shows the night card (OFF · INATIVO). Copy is English or Portuguese from `$LANG`. The wordmark is **JetBrainsMono Nerd Font**, Omarchy's current UI typeface.

## What you get

Shortest-column packing: windows keep a remembered height when they can; a column that would overflow is scaled to the monitor; leftover space stays as wallpaper holes. One window still fills the workspace. `layoutmsg cols` changes how many columns that workspace uses.

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
