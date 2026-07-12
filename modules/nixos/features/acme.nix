{
  config,
  lib,
  ...
}:

let
  cfg = config.kryonix.features.acme;
in
{
  options.kryonix.features.acme = {
    enable = lib.mkEnableOption "ACME (Let's Encrypt) client for automated SSL certificates";

    email = lib.mkOption {
      type = lib.types.str;
      default = "aguiarrocha36@gmail.com";
      description = "Email used for ACME registration.";
    };

    dnsProvider = lib.mkOption {
      type = lib.types.str;
      default = "cloudflare";
      description = "DNS provider used for DNS-01 challenge.";
    };

    certs = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          domain = lib.mkOption {
            type = lib.types.str;
            description = "The primary domain name for the certificate.";
          };
          group = lib.mkOption {
            type = lib.types.str;
            default = "nginx";
            description = "Group that owns the certificate.";
          };
          credentialFiles = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Credential files for the DNS provider.";
          };
        };
      });
      default = { };
      description = "Declarative ACME certificates configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    security.acme = {
      acceptTerms = true;
      defaults = {
        email = cfg.email;
        dnsProvider = cfg.dnsProvider;
      };

      certs = lib.mapAttrs (name: certCfg: {
        domain = certCfg.domain;
        group = certCfg.group;
        dnsProvider = cfg.dnsProvider;
        credentialFiles = certCfg.credentialFiles;
      }) cfg.certs;
    };
  };
}
