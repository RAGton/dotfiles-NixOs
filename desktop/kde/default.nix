# =============================================================================
# desktop/kde/default.nix — Base da sessão KDE Plasma 6 (Home Manager)
#
# O que é:
# - Habilita o plasma-manager (programs.plasma.enable) e instala os pacotes de
#   sessão usados pelos atalhos/declarações (kdePackages, playerctl, etc.).
#
# Por quê:
# - Ponto único de ativação do plasma-manager para o ambiente KDE; as demais
#   camadas (theme/tiling/launcher/keybinds) apenas preenchem programs.plasma.*.
#
# Como:
# - Importado por desktop/kde/user.nix, que por sua vez é exportado como
#   homeManagerModules.kde (junto do módulo HM do plasma-manager) em flake/modules.nix.
# =============================================================================
{ pkgs, ... }:
{
  # Habilita a geração declarativa de configuração do Plasma (kwinrc,
  # kglobalshortcutsrc, kdeglobals, etc.) a partir de programs.plasma.*.
  programs.plasma.enable = true;

  # Habilita o backend da Kryonix Bar (Rust/D-Bus).
  services.kryonix-bar.enable = true;

  # Pacotes de sessão no escopo do usuário (úteis para os atalhos e o dia a dia).
  home.packages = with pkgs; [
    kdePackages.dolphin
    kdePackages.konsole
    kdePackages.spectacle
    kdePackages.qttools # qdbus/qdbusviewer (uso manual; atalhos usam gdbus — ver keybinds.nix)
    playerctl # controle de mídia (Meta+,/. e XF86AudioPlay)
    kryonix-bar-backend
    warp-terminal
  ];

  # NOTA: QT_QPA_PLATFORMTHEME é definido em kvantum.nix ("kvantum"), parte da
  # estética Kryonix Glass. Não definir aqui para evitar definição dupla.
}
