{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kryonix.security.hardening;
in
{
  options.kryonix.security.hardening.enable = lib.mkEnableOption "Harden system via AppArmor";

  config = lib.mkIf cfg.enable {
    security.apparmor = {
      enable = true;
      # Deixamos como false inicialmente para o modo 'complain'.
      # Criaremos um flag kryonix.security.hardening.enforce para ativar o modo 'kill' futuramente.
      killUnconfinedConfinables = false;
    };
  };
}
