# =============================================================================
# user-vars/theme.nix — Camada de tema e ambiente de desktop
#
# Consolida toda a infraestrutura de UI (nhModules, tema, WM, ferramentas)
# que pertence à "aparência e setup do desktop" de um usuário.
#
# Para personalizar: override de options de cursor/gtk/fonte no host config.
# Para adicionar host-specific visual tweaks, use lib.mkAfter no extraConfig
# do host (ex.: glacier usa isso para ajustes NVIDIA).
# =============================================================================
{ nhModules, ... }:
{
  imports = [
    # Framework Home Manager (GTK, Qt, wallpaper, XDG, Swappy)
    "${nhModules}/misc/gtk"
    "${nhModules}/misc/qt"
    "${nhModules}/misc/wallpaper"
    "${nhModules}/misc/xdg"
    "${nhModules}/programs/swappy"

    # Monitor management (kryonix-monitors wrapper)
    ../monitors.nix

    # Tema visual (hyprlock, hypridle, GTK theme, fontes, wallpaper)
    ../theme

    # WM core: enable + configType + extraConfig base
    ../core/hyprland.nix

    # Ferramentas de sessão (hyprpicker, wf-recorder, etc.)
    ../core/packages.nix

    # Cursor (herda de gtk.cursorTheme)
    ../core/cursor.nix
  ];
}
