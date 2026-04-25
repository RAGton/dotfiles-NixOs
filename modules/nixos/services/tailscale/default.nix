# Módulo NixOS: Tailscale (VPN mesh)
# Autor: rag
#
# O que é
# - Instala e habilita o serviço do Tailscale no sistema (system-wide).
# - Expõe opções simples pra firewall e recursos comuns (exit node / routing).
#
# Por quê
# - Acesso seguro remoto (SSH/serviços) sem abrir portas no roteador.
# - Conectividade entre máquinas com pouco atrito.
#
# Como
# - Usa `services.tailscale` do NixOS.
# - Opcionalmente, habilita forwarding/NAT quando atuar como exit node.
# - (Opcional) Autoconnect via systemd usando um auth key vindo de um arquivo.
#
# Riscos
# - `autoconnect` com auth key: se o arquivo for mal protegido, pode permitir join indevido.
# - Exit node/subnet routing exige `net.ipv4.ip_forward` e pode expor rede se mal configurado.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.kryonix.tailscale;
  boolToFlag = b: if b then "true" else "false";
  tailscaleUpArgs = lib.concatStringsSep " " (
    [ "--accept-dns=${boolToFlag cfg.acceptDNS}" ]
    ++ lib.optionals cfg.ssh [ "--ssh" ]
    ++ lib.optionals cfg.advertiseExitNode [ "--advertise-exit-node" ]
    ++ lib.optionals (cfg.advertiseRoutes != [ ]) [
      "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
    ]
    ++ cfg.extraUpFlags
  );
  needsForwarding = cfg.advertiseExitNode || cfg.advertiseRoutes != [ ];
in
{
  options.services.kryonix.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN (system-wide)";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Abre firewall para o UDP do Tailscale (recomendado).";
    };

    acceptDNS = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Aceita configurações de DNS empurradas pelo Tailnet.";
    };

    ssh = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Habilita Tailscale SSH (tailscale.com/kb/ssh).";
    };

    autoconnect = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Faz `tailscale up` automaticamente no boot.

        Recomendação: use junto de `authKeyFile` (não commitar chave no Git).
        Se `authKeyFile` estiver vazio, o serviço não roda e você faz login manual.
      '';
    };

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Caminho para um arquivo contendo o auth key (TS_AUTHKEY=...).

        Dica: gerencie via agenix/sops-nix ou outro mecanismo de secrets.
      '';
    };

    advertiseExitNode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Anuncia este host como exit node.";
    };

    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "192.168.0.0/24"
        "10.0.0.0/24"
      ];
      description = "Lista de rotas (subnet routing) a anunciar.";
    };

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--hostname=glacier"
        "--operator=rocha"
      ];
      description = "Flags extras passadas para `tailscale up`.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tailscale ];

    services.tailscale = {
      enable = true;
      openFirewall = cfg.openFirewall;
      useRoutingFeatures = lib.mkDefault (if needsForwarding then "server" else "client");
    };

    # Necessário para exit node e subnet routing.
    # (No NixOS, o jeito mais portátil é via sysctl.)
    boot.kernel.sysctl = lib.mkIf needsForwarding {
      "net.ipv4.ip_forward" = lib.mkDefault 1;
      # Habilite se você for rotear IPv6 via tailscale/subnet routing.
      "net.ipv6.conf.all.forwarding" = lib.mkDefault 1;
    };

    # Autoconnect (opcional). Não tenta adivinhar login; exige auth key via arquivo.
    systemd.services.tailscale-autoconnect = lib.mkIf cfg.autoconnect {
      description = "Tailscale automatic bring-up";
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      wants = [
        "network-online.target"
        "tailscaled.service"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        # Só roda se ainda não está conectado.
        if ${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -e '.Self.Online == true' >/dev/null; then
          exit 0
        fi

        if [ -z "${lib.optionalString (cfg.authKeyFile != null) (toString cfg.authKeyFile)}" ]; then
          echo "tailscale-autoconnect: authKeyFile não configurado; faça login manual com 'sudo tailscale up'." >&2
          exit 0
        fi

        if [ ! -f ${lib.escapeShellArg (toString cfg.authKeyFile)} ]; then
          echo "tailscale-autoconnect: authKeyFile não encontrado; pulando autoconnect." >&2
          exit 0
        fi

        authkey="$(cat ${lib.escapeShellArg (toString cfg.authKeyFile)})"
        if [ -z "$authkey" ]; then
          echo "tailscale-autoconnect: authKeyFile vazio; abortando." >&2
          exit 1
        fi

        exec ${pkgs.tailscale}/bin/tailscale up --authkey "$authkey" ${tailscaleUpArgs}
      '';
    };
  };
}
