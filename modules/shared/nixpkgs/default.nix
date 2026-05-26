# Módulo compartilhado: nixpkgs (overlays + allowUnfree)
#
# Objetivo:
# - Centralizar a configuração de overlays e allowUnfree em um único lugar
# - Reusar no NixOS e no nix-darwin
# - Evitar duplicação (e surpresa) entre system modules e Home Manager
{
  outputs,
  lib,
  isDarwin ? false,
  ...
}:
{
  nixpkgs = {
    overlays = [
      outputs.overlays.stable-packages
      outputs.overlays.atlauncher-api-user-agent-workaround
      outputs.overlays.codex-overlay
    ]
    ++ lib.optionals (!isDarwin) [
      outputs.overlays.openrgb-git
      outputs.overlays.drkonqi-ignore-missing-buildid
      outputs.overlays.python312-docs-stub
      outputs.overlays.openldap-no-checks
      outputs.overlays.kryonix-installer-tools
    ];

    config = {
      allowUnfree = lib.mkDefault true;
    };
  };
}
