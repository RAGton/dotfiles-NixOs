{ lib, ... }:
{
  options.kryonix.shell.backend = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "caelestia" # Caelestia Shell (Quickshell/QML) — default
        "kryonix" # Kryonix Bar (Waybar premium — PR 7C)
      ]
    );
    default = null;
    description = ''
      Backend de shell/rice ativo neste perfil Home Manager.

      - "caelestia": Caelestia Shell provê barra e launcher via Quickshell.
      - "kryonix":   Kryonix Bar (Waybar premium) com paleta Kryonix Dark.
      - null:        Sem shell gerenciado; Waybar ativo por default.

      Esta opção controla qual barra é ativada e quais atalhos são publicados.
      A ativação do compositor (Hyprland) é responsabilidade do NixOS module.
    '';
  };
}
