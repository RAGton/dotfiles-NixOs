# =============================================================================
# core/rules.nix — Window rules (Hyprland)
#
# Transparência por app: leve para leitura, mais forte em terminais/IDE.
# Mantido separado de keybinds para facilitar override por host.
# =============================================================================
{ lib, config, ... }:
{
  config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {
    wayland.windowManager.hyprland.extraConfig = lib.mkOrder 400 ''
      # Zen Browser (Flatpak) — transparência leve
      windowrule = match:class ^(app\.zen_browser\.zen|zen|Zen)$, opacity 0.93 0.86

      # Dolphin — gerenciador de arquivos
      windowrule = match:class ^(org\.kde\.dolphin)$, opacity 0.93 0.85

      # Filelight — análise de disco
      windowrule = match:class ^(org\.kde\.filelight)$, opacity 0.95 0.90

      # Editores e IDEs
      windowrule = match:class ^(code-insiders|code|Cursor)$, opacity 0.93 0.90

      # Antigravity (AI) e terminais
      windowrule = match:class ^(antigravity|Antigravity)$, opacity 0.92 0.88
      windowrule = match:class ^(Alacritty|kitty|tilix|foot)$, opacity 0.90 0.85
    '';
  };
}
