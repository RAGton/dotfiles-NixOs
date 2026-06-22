{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.features.security;
in
{
  options.kryonix.features.security = {
    firewall.enable = lib.mkEnableOption "Strict firewall";
    fail2ban.enable = lib.mkEnableOption "Fail2ban intrusion prevention";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.firewall.enable {
      networking.firewall = {
        enable = true;
        allowPing = false;
      };
    })
    (lib.mkIf cfg.fail2ban.enable {
      services.fail2ban.enable = true;
    })
  ];
}
