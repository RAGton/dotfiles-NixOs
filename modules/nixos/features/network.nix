# =============================================================================
# Module: Network features (kryonix.features.network.*)
# Autor: Gabriel Rocha (ragton) + Aura
# Data: 2026-06-23
#
# O que é:
# - Features de rede: Tailscale, bridge, VLAN, firewall, etc.
# - Cada feature é opt-in (default = false).
#
# Por quê:
# - Rede é uma preocupação de segurança; nada deve ser ativado sem consentimento.
# - Compatibilidade com services.kryonix.tailscale existente.
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.features.network;
in
{
  options.kryonix.features.network = {
    tailscale = {
      enable = lib.mkEnableOption ''
        Tailscale mesh VPN. Habilita services.tailscale no sistema.

        Caminho preferencial em relação a services.kryonix.tailscale.enable
        (que continua funcionando como compat).
      '';
    };
  };

  config = lib.mkMerge [
    # Tailscale
    (lib.mkIf cfg.tailscale.enable {
      services.tailscale.enable = true;

      environment.systemPackages = [ pkgs.tailscale ];
    })
  ];
}
