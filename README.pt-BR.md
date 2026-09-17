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
| `Super+Shift+O` | Liga/desliga masonry **fit** no workspace ativo |
| `Super+Alt+O` | Liga/desliga o **modo centro**: janela focada travada no meio, as outras em quadrados ao redor |
| `Super+Shift+K` | Trava / solta a janela focada (borda magenta). O modo centro trava o hub sozinho. |
| Ícone `󰕰` na barra | Ao lado dos workspaces; clique alterna o fit. Magenta + ids quando ligado. |
| `Super+Shift+Alt+O` | Obsidian (depois da instalação) |
| `Super+Shift+←↑↓→` | Troca a janela focada com a vizinha nessa direção |
| `Super+-` / `Super++` | Alarga / estreita a coluna focada (iguais ao Omarchy) |
| `Super+Shift+-` / `Super+Shift++` | Encolhe / cresce a janela focada na vertical |
| `Super+L` | Continua o toggle dwindle ↔ scrolling do Omarchy (se usar, sobrescreve este workspace) |

```sh
omansory toggle
omansory center        # Super+Alt+O — janela focada no centro
omansory on
omansory off
omansory status
omansory cols 3    # 1–6, ou + / -
omansory resize h -100
omansory resize v 100
omansory lock          # Super+Shift+K — trava a fatia desta janela neste workspace
```

Ao **ligar** ou **desligar**, um interruptor de parede retrowave (ON / OFF, em inglês) cai sob a barra e some depressa. Sem ATIVO/INATIVO.

## O que o layout faz

O padrão **fit** é um treemap squarified: retângulos e quadrados que preenchem o monitor, sem um app sozinho virar barra de largura inteira (e sem L — o Wayland não recorta isso). Navegadores e editores ainda ganham mais área que terminais; Super± ajusta a fatia focada.

**Trava (por workspace):** Super+Shift+K pinça a fatia atual da janela focada. A borda fica magenta. Ligar e desligar o Omansory devolve essa janela à mesma caixa relativa; as demais se encaixam em volta. O atalho de novo solta. As travas ficam em `~/.local/state/omansory/locks/<id-do-workspace>.jsonl`. `omansory mode columns` volta às colunas iguais.

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
