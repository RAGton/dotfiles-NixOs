# =============================================================================
# desktop/hyprland/kryonix-bar.nix — Ponto de entrada da Kryonix Bar (PR 7C)
#
# O que é:
# - Módulo Home Manager que ativa a Kryonix Bar quando
#   kryonix.shell.backend = "kryonix".
# - Importa o módulo Waybar premium de modules/home-manager/services/waybar/.
# - Define o backend como "kryonix" para que a lógica de guarda no Waybar
#   module funcione corretamente.
#
# Como usar (em home/<user>/hyprland/default.nix ou equivalente do downstream):
#   imports = [ .../desktop/hyprland/kryonix-bar.nix ];
#   kryonix.shell.backend = "kryonix";
#
# Rollback: remover o import ou mudar backend para "caelestia" / null.
# =============================================================================
{
  nhModules,
  lib,
  config,
  ...
}:
let
  isKryonixBar = (config.kryonix.shell.backend or null) == "kryonix";
in
{
  imports = [
    # Módulo Waybar premium (usa a paleta Kryonix Dark e CPU per-core)
    "${nhModules}/services/waybar"
  ];

  # Quando kryonix-bar está ativo, não há mais nada a configurar aqui no V1.
  # O daemon Rust (kryonix-shell-daemon) será integrado no PR 7D:
  #   services.kryonix-shell-daemon.enable = lib.mkIf isKryonixBar true;
  config = lib.mkIf isKryonixBar {
    # Placeholder: futuras integrações (daemon, keybinds específicos) entram aqui.
    # Por ora, o Waybar cuida de tudo declarativamente.
  };
}
