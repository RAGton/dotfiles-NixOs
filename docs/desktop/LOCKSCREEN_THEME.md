# Lockscreen e Temas

O projeto unifica temas visuais na camada `modules/nixos/theming/` e `desktop/hyprland/theme/`.

## Hyprlock (Wayland)
A tela de bloqueio padrão no Caelestia/Hyprland utiliza o `hyprlock`.
A configuração vive em `desktop/hyprland/theme/hyprlock.nix`.
- Utiliza integração profunda com variáveis do Caelestia para cores (Catppuccin ou base dinâmicas).
- Autenticação injetada via PAM (NixOS Security).

## SDDM (Display Manager)
Seja ao inicializar o Hyprland ou o KDE, o **SDDM** é o gerenciador de login padrão.
- Tema: `assets/sddm/` fornece o pacote ou theme assets injetados pelo Nix.
- Comportamento visual mapeado em `modules/nixos/desktop/sddm.nix`.

## Assets Globais
Avatares de usuário e Wallpapers padrão vivem na pasta `/etc/kryonix/assets/`. O script do Hyprpaper ou do plasma-manager garante que as imagens de fundo e locks apliquem o mesmo PNG para coesão.
