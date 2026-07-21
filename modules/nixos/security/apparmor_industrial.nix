{ config, lib, pkgs, ... }:

let
  cfg = config.kryonix.security.hardening;
in
{
  options.kryonix.security.hardening.enable = lib.mkEnableOption "Harden system via AppArmor (Industrial)";

  config = lib.mkIf cfg.enable {
    security.apparmor = {
      enable = true;
      # Modo complain ativo para auditoria de falhas antes da restrição fatal
      killUnconfinedConfinables = false;
      policies = {
        kryonix-incus-container = {
          profile = ''
            profile kryonix-incus-container flags=(attach_disconnected,mediate_deleted) {
              # Permite rede e operações genéricas do container
              network,
              capability,
              file,
              
              # Nega leitura a credenciais e parâmetros globais do host
              deny /etc/shadow rwk,
              deny /etc/gshadow rwk,
              deny /proc/sys/** rwk,
              deny /sys/** rwk,
            }
          '';
        };
        kryonix-core-backend = {
          profile = ''
            profile kryonix-core-backend {
              file,
              network,
              # Restringindo acesso livre
              audit deny /etc/shadow rwk,
              # Garante que ele opera no /var/lib/kryonix/
              /var/lib/kryonix/** rwk,
            }
          '';
        };
      };
    };
  };
}
