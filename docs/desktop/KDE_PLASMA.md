# Desktop: KDE Plasma

O Kryonix suporta KDE Plasma como a alternativa secundária de ambiente gráfico em relação ao tiling nativo (Caelestia / Hyprland).

## Implementação Base
A configuração se encontra em `desktop/kde/default.nix`.
O módulo principal `modules/nixos/desktop/kde.nix` encapsula o gerenciador SDDM (Display Manager) e o backend Wayland.

## Arquitetura de Módulos
As partes do KDE são altamente separadas:
- `keybinds.nix` / `keymap.nix` para binds de teclado globais.
- `launcher.nix` para Kickoff/Krunner custom.
- `tiling.nix` (Roadmap: Bismuth/Polonium scripts para similaridade com Hyprland).

## Estado Atual
- KDE Plasma 6 sobre Wayland: **Implementado**.
- Autologin / SDDM: **Implementado**.
- Customização Pesada (Rice idêntico ao Caelestia): **Parcial** (Diferenças inerentes entre gerenciadores imperativos vs declarativos mantêm a UI diferente).
