<p align="center">
  <img src="share/omansory/on.jpg" alt="Omansory — masonry retrowave para Omarchy" width="100%">
</p>

<p align="center">
  <a href="README.md">English</a>
  ·
  <a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-aab3bc?labelColor=0b0f14"></a>
  <img alt="Omarchy 4" src="https://img.shields.io/badge/Omarchy-4-fda52b?labelColor=0b0f14">
  <img alt="Hyprland 0.55+" src="https://img.shields.io/badge/Hyprland-0.55%2B-05d9e8?labelColor=0b0f14">
</p>

# Omansory

**Masonry por workspace** para [Omarchy](https://omarchy.org/) / Hyprland. Um atalho empilha as janelas tiled em colunas (a mais baixa primeiro) **só no workspace ativo**. Os outros continuam em dwindle, scrolling ou o que já estiverem usando.

É um layout Lua do Hyprland (`lua:omansory`), não um widget da barra. Ele **não** se encaixa em cima do scrolling: enquanto está ligado, aquele workspace *é* Omansory.

## Instalar

```sh
git clone https://github.com/alcure/omansory.git
cd omansory
chmod +x install.sh bin/omansory
./install.sh
```

O instalador:

1. Cria o symlink do layout em `~/.config/hypr/omansory.lua` e do CLI em `~/.local/bin/omansory`.
2. Insere blocos marcados em `hyprland.lua` e `bindings.lua` (com backup datado).
3. **Substitui Super+Shift+O** (Obsidian padrão) pelo toggle do Omansory.
4. Remapeia o Obsidian para **Super+Shift+Alt+O**.
5. Copia os stills retrowave de ligar/desligar usados nas notificações.

## Uso

| Tecla | Ação |
| --- | --- |
| `Super+Shift+O` | Liga/desliga masonry no workspace **ativo** |
| Ícone `󰕰` na barra | Ao lado dos workspaces; clique alterna. Magenta + ids quando ligado. |
| `Super+Shift+Alt+O` | Obsidian (depois da instalação) |
| `Super+-` / `Super++` | Alarga / estreita a coluna focada (iguais ao Omarchy) |
| `Super+Shift+-` / `Super+Shift++` | Encolhe / cresce a janela focada na vertical |
| `Super+L` | Continua o toggle dwindle ↔ scrolling do Omarchy (se usar, sobrescreve este workspace) |

```sh
omansory toggle
omansory on
omansory off
omansory status
omansory cols 3    # 1–6, ou + / -
omansory resize h -100
omansory resize v 100
```

Ao **ligar**, aparece o cartão da grade magenta (ON · ATIVO). Ao **desligar**, o cartão noturno (OFF · INATIVO). O texto segue `$LANG`. A wordmark usa **JetBrainsMono Nerd Font**, a fonte atual da interface do Omarchy.

## O que o layout faz

O padrão **fit** divide a área de trabalho inteira: todas as janelas tiled ficam na tela e não sobra furo de wallpaper. Navegadores, editores e documentos ganham mais área que terminais; Super± ainda ajusta a fatia da janela focada. `omansory mode columns` volta às colunas iguais.

Janelas flutuantes / pinadas (incluindo o pop-out `Super+O` do Omarchy) ficam de fora.

Sair do scrolling deixava “fantasmas” de popin e tiles sobrepostos, porque a fita reporta o tamanho errado. O Omansory agora empacota a partir de um split limpo, com as animações de janela pausadas na troca.

## Desinstalar

```sh
omansory uninstall
```

Remove os blocos de config e os symlinks. O clone git permanece.

## Requisitos

Omarchy 4, Hyprland ≥ 0.55 (config Lua), `hyprctl`, `jq`, `python3`, `omarchy-notification-send`.

## Licença

MIT. Ver [CHANGELOG](CHANGELOG.md).
