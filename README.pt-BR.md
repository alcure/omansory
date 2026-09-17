<p align="center">
  <img src="share/omansory/on.jpg" alt="Omansory — masonry retrowave para Omarchy" width="100%">
</p>

<p align="center">
  <a href="README.md">English</a>
  ·
  <a href="https://plugins.omarchy.org/"><img alt="plugins Omarchy" src="https://img.shields.io/badge/plugins.omarchy.org-alcure.omansory-fda52b?labelColor=0b0f14"></a>
  ·
  <a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-aab3bc?labelColor=0b0f14"></a>
  <img alt="Omarchy 4" src="https://img.shields.io/badge/Omarchy-4-fda52b?labelColor=0b0f14">
  <img alt="Hyprland 0.55+" src="https://img.shields.io/badge/Hyprland-0.55%2B-05d9e8?labelColor=0b0f14">
</p>

# Omansory

**Masonry por workspace** para [Omarchy](https://omarchy.org/) / Hyprland. Os atalhos empacotam as janelas tiled **só no workspace ativo**. Os outros continuam em dwindle, scrolling ou o que já estiverem usando.

É um layout Lua do Hyprland (`lua:omansory`). Ele **não** se encaixa em cima do scrolling: enquanto está ligado, aquele workspace *é* Omansory. Só retângulos alinhados aos eixos (sem L). Nesse workspace o `gaps_in` interno vai a zero para as molduras se encostarem, sem filete de wallpaper.

## Demonstração

Masonry (`Super+Shift+O`) e Centro (`Super+Alt+O`) num workspace cheio — calculadora, LibreOffice Writer, navegador e X:

https://github.com/alcure/omansory/blob/main/docs/omansory-demo.mp4

## Instalar

Id do plugin: `alcure.omansory`. Repositório: https://github.com/alcure/omansory

### Marketplace (shell do Omarchy)

```sh
omarchy plugin add https://github.com/alcure/omansory.git --enable
```

Isso clona o repo em `~/.config/omarchy/plugins/alcure.omansory` e liga o ícone da barra. **Não** altera a config do Hyprland.

Depois instale o layout e os atalhos (passo explícito; faz backup de `hyprland.lua` / `bindings.lua`):

```sh
chmod +x ~/.config/omarchy/plugins/alcure.omansory/install.sh
~/.config/omarchy/plugins/alcure.omansory/install.sh
```

Se o ícone não ficar à direita do relógio: `omarchy plugin enable alcure.omansory --section center --after omarchy.clock`.

### A partir de um clone git

```sh
git clone https://github.com/alcure/omansory.git
cd omansory
chmod +x install.sh bin/omansory
./install.sh
```

O instalador:

1. Cria o symlink do layout em `~/.config/hypr/omansory.lua` e do CLI em `~/.local/bin/omansory`.
2. Insere blocos `-- BEGIN omansory` em `hyprland.lua` e `bindings.lua` (com backup datado).
3. **Substitui Super+Shift+O** (Obsidian padrão) pelo toggle do masonry fit.
4. Remapeia o Obsidian para **Super+Shift+Alt+O**.
5. Liga **Super+Alt+O** ao modo centro.
6. Coloca o widget `alcure.omansory` **à direita do relógio**.
7. Copia os stills retrowave das notificações.

O `install.sh` é opcional se você só quiser o ícone. Os atalhos de layout precisam desse passo. Se `omarchy refresh hyprland` apagar os blocos do Hyprland, rode o `install.sh` de novo. A pasta do plugin não contém symlinks internos; o `install.sh` local copia os arquivos para `~/.config/omarchy/plugins/alcure.omansory` em vez de ligar um symlink.

## Uso

| Tecla | Ação |
| --- | --- |
| `Super+Shift+O` | Liga/desliga o **Masonry** (fit) no workspace ativo |
| `Super+Alt+O` | Liga/desliga o **modo centro**. O segundo toque desliga o Omansory |
| `Super+Shift+K` | Trava / solta a janela focada (borda magenta). O centro trava o hub sozinho |
| `Super+Shift+←↑↓→` | Troca a janela focada com a vizinha (no centro, pula o hub) |
| `Super+-` / `Super++` | Alarga / estreita a fatia focada (iguais ao Omarchy) |
| `Super+Shift+-` / `Super+Shift++` | Encolhe / cresce a janela na vertical |
| Ícone na barra | À direita do relógio. **Quatro quadrados** = Masonry Mode; **quadrado interno + moldura** = Central Mode. Clique alterna o fit |
| `Super+Shift+Alt+O` | Obsidian (depois da instalação) |
| `Super+L` | Toggle dwindle ↔ scrolling do Omarchy (sobrescreve este workspace) |

Um interruptor retrowave aparece sob a barra: **MASONRY ON / OFF** ou **CENTER ON / CENTER OFF**.

### Modo fit (`Super+Shift+O`)

Treemap squarified que **preenche a área útil**. Toda janela tiled começa com a mesma fatia. Sem barras de largura inteira, sem sobreposição; buracos restantes são absorvidos pelo vizinho. Super+- continua crescendo ou encolhendo a janela focada.

### Modo centro (`Super+Alt+O`)

A janela **focada** vira o hub, no **mesmo tamanho de um único app no scrolling** (`layout.single_window_aspect_ratio` se o toggle quadrado do Omarchy estiver ligado; senão `scrolling.column_width`). Fica travada (borda magenta). As outras preenchem o anel. Super+Shift+setas reordenam os satélites; o hub não sai do lugar. O atalho de novo **desliga**. Super+Shift+O troca para fit sem sair do Omansory.

### CLI

```sh
omansory toggle
omansory center          # Super+Alt+O
omansory on
omansory off
omansory status [--json]
omansory mode fit|center|columns
omansory cols 3          # 1–6, ou + / -
omansory lock
omansory swap left
omansory resize h -100
omansory reset           # recalcula o packing
omansory refresh         # relê o plugin da barra; não reinicia o shell
omansory install
omansory uninstall
```

Janelas flutuantes / pinadas (incluindo o pop-out `Super+O` do Omarchy) ficam de fora.

Para recarregar a barra: `omansory refresh` ou `omarchy-shell shell rescanPlugins`. **Não** use `omarchy restart shell` nem force reload do renderer só para pegar ajuste de plugin — isso deixa tiras sem pintar.

## Desinstalar

```sh
omansory uninstall
omarchy plugin remove alcure.omansory
```

`omansory uninstall` remove os blocos do Hyprland, os links do CLI/layout e desativa o widget. `omarchy plugin remove` apaga a pasta clonada. Os gaps internos voltam ao padrão do Omarchy naquele workspace.

## Requisitos

Omarchy 4, Hyprland ≥ 0.55 (config Lua), `hyprctl`, `jq`, `python3`, `omarchy-notification-send`.

## Licença

MIT. Ver [CHANGELOG](CHANGELOG.md).
