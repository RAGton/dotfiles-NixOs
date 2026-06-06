# Atalhos Globais (Hyprland / Caelestia)

Os atalhos do sistema estão centralizados em `desktop/hyprland/core/keybinds.nix`.
O modificador primário (`$mainMod`) é a tecla **SUPER/WIN**.

## Principais Operações de Janela
- `SUPER + Q`: Fechar janela atual.
- `SUPER + F`: Tela Cheia (Fullscreen).
- `SUPER + V`: Trocar modo floating/tiling.
- `SUPER + Mouse Esquerdo (arrastar)`: Mover janela flutuante.
- `SUPER + Mouse Direito (arrastar)`: Redimensionar janela flutuante.

## Launchers e Ferramentas
- `SUPER + Espaço`: Abrir o Caelestia Launcher (Substitui ROFI/Wofi).
- `SUPER + Enter`: Abrir terminal padrão (Kitty).
- `SUPER + E`: Abrir gerenciador de arquivos (Dolphin).

## Gestão de Workspaces
- `SUPER + [1-9]`: Mudar para o workspace 1 a 9.
- `SUPER + SHIFT + [1-9]`: Mover janela atual para o workspace 1 a 9.
- `SUPER + Scroll`: Navegar entre workspaces.

## Mídia e Volume
Teclas multimídia padrão (XF86Audio*) funcionam globalmente (Volume Up, Down, Mute, Play/Pause).

## Integração IA
- *(Roadmap)* `SUPER + A`: Invoca o Kryonix Brain (Antigo atalho do Kora/Aura).

---

# Atalhos Globais (KDE Plasma)

Ambiente principal. Atalhos centralizados em `desktop/kde/keybinds.nix`
(aplicados via plasma-manager: `kglobalshortcutsrc` + `hotkeys.commands`).
O modificador primário é a tecla **Meta/SUPER/WIN**. Tiling via **Krohnkite**.

## Janelas
- `Meta + Q`: Fechar janela.
- `Meta + F`: Fullscreen.
- `Meta + Tab` / `Alt + Tab`: Alternar entre janelas.
- `Meta + W`: Overview · `Meta + G`: Grid View.

## Tiling (Krohnkite)
- `Meta + H/J/K/L`: Mover **foco** (esquerda/baixo/cima/direita).
- `Meta + Shift + H/J/K/L`: **Mover** a janela.
- `Meta + Ctrl + H/J/K/L`: **Redimensionar** a janela.
- `Meta + Space`: Próximo layout · `Meta + Shift + F`: Toggle float.
- Layouts: `Meta + D` (spiral), `Meta + B` (b-tree), `Meta + M` (monocle), `Meta + C` (columns).

## Desktops virtuais (10, o 10º = Scratchpad)
- `Meta + 1..0`: Ir para o desktop N.
- `Meta + Shift + 1..0`: Mover janela para o desktop N.
- `Meta + Ctrl + 1..0`: Mover janela **e seguir** para o desktop N.
- `Meta + S` / `Meta + Shift + S`: Scratchpad (desktop 10).

## Launchers e Apps
- `Meta + A`: Wofi (launcher de aplicativos).
- `Meta + T` / `Meta + Return`: Terminal (Warp via wrapper Kryonix).
- `Meta + Shift + T`: Terminal flutuante.
- `Meta + O`: Dolphin · `Meta + N`: Zen Browser · `Meta + R`: VSCode.
- `Meta + /` ou `Meta + F1`: Kryonix Keybind Helper (lista de atalhos).

## Sessão e mídia
- `Meta + Escape`: Bloquear sessão · `Shift + Escape`: Logout.
- `Meta + Ctrl + Escape`: Reiniciar (com confirmação).
- `Meta + ,` / `Meta + .`: Faixa anterior/próxima · `XF86AudioPlay`: Play/Pause.
- `Print` / `Shift + Print`: Spectacle (tela inteira / região).

> Limitação documentada: `Meta + Scroll` para trocar de desktop não é
> expressável declarativamente nesta rev do plasma-manager (ver nota em
> `desktop/kde/keybinds.nix`).
