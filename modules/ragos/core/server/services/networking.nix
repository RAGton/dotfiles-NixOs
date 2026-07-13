{
  config,
  lib,
  pkgs,
  ragosServerIp,
  ragosHttpPort,
  ragosMgmtInterface,
  ragosMgmtBondMode ? "",
  ragosMgmtBondMembers ? [ ],
  ragosMgmtPrefixLength,
  ragosMgmtGateway,
  ragosMgmtDns,
  ragosWanInterface ? "",
  ragosWanMode ? "dhcp",
  ragosWanAddress ? "",
  ragosWanPrefixLength ? 24,
  ragosWanGateway ? "",
  ragosWanDns ? [ ],
  ragosWanPppoeUser ? "",
  ...
}:

let
  haveWan = ragosWanInterface != "";
  haveMgmtBond = ragosMgmtBondMode != "" && builtins.length ragosMgmtBondMembers >= 2;
  wanStatic = ragosWanMode == "static";
  wanPppoe = ragosWanMode == "pppoe";
  natExternalInterface = if wanPppoe then "ppp0" else ragosWanInterface;
  pppoeStartScript = pkgs.writeShellScript "ragos-pppoe-start" ''
    set -euo pipefail
    source /etc/ragos/wan-pppoe.env
    exec ${pkgs.ppp}/bin/pppd \
      nodetach \
      noauth \
      plugin pppoe.so ${ragosWanInterface} \
      user "${ragosWanPppoeUser}" \
      password "$PPPOE_PASSWORD" \
      defaultroute \
      replacedefaultroute \
      usepeerdns \
      persist \
      maxfail 0 \
      hide-password \
      mtu 1492 \
      mru 1492 \
      linkname ragos-wan
  '';
in
{
  networking.useDHCP = false;
  systemd.network.enable = true;
  systemd.network.netdevs = lib.mkIf haveMgmtBond {
    "20-${ragosMgmtInterface}" = {
      netdevConfig = {
        Name = ragosMgmtInterface;
        Kind = "bond";
      };
      bondConfig = {
        Mode = ragosMgmtBondMode;
        MIIMonitorSec = "1s";
      };
    };
  };

  # -----------------------------------------------------------------------
  # Interface LAN — ajuste o nome conforme hardware (ip link)
  # -----------------------------------------------------------------------
  systemd.network.networks =
    lib.optionalAttrs haveMgmtBond (
      builtins.listToAttrs (
        map (member: {
          name = "lan-slave-${member}";
          value = {
            matchConfig.Name = member;
            networkConfig.Bond = ragosMgmtInterface;
          };
        }) ragosMgmtBondMembers
      )
    )
    // {
      lan = {
        matchConfig.Name = ragosMgmtInterface;
        networkConfig = {
          Address = "${ragosServerIp}/${builtins.toString ragosMgmtPrefixLength}";
          DNS = ragosMgmtDns;
        }
        // lib.optionalAttrs (!haveWan) {
          Gateway = ragosMgmtGateway;
        };
      };
    }
    // lib.optionalAttrs (haveWan && !wanPppoe) {
      wan = {
        matchConfig.Name = ragosWanInterface;
        networkConfig =
          if wanStatic then
            {
              Address = "${ragosWanAddress}/${builtins.toString ragosWanPrefixLength}";
              Gateway = ragosWanGateway;
              DNS = ragosWanDns;
            }
          else
            {
              DHCP = "ipv4";
            };
      };
    };

  networking.nat = lib.mkIf haveWan {
    enable = true;
    externalInterface = natExternalInterface;
    internalInterfaces = [ ragosMgmtInterface ];
  };

  systemd.services.ragos-pppoe = lib.mkIf (haveWan && wanPppoe) {
    description = "RAGOS WAN PPPoE session";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "systemd-networkd.service"
    ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "/etc/ragos/wan-pppoe.env";
    serviceConfig = {
      Type = "simple";
      ExecStart = pppoeStartScript;
      Restart = "always";
      RestartSec = 5;
    };
    path = with pkgs; [
      ppp
      coreutils
      iproute2
    ];
  };

  # -----------------------------------------------------------------------
  # Firewall — default deny, abre apenas o necessário
  # -----------------------------------------------------------------------
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
    ];

    interfaces."${ragosMgmtInterface}" = {
      allowedTCPPorts = [
        ragosHttpPort # HTTP — kernel/initrd/boot.ipxe
        2049 # NFS
        111 # RPC portmapper
        9090 # Prometheus
        9100 # Node Exporter
        3000 # Grafana
      ];

      allowedUDPPorts = [
        67 # DHCP
        69 # TFTP
        123 # NTP
        111 # RPC portmapper
      ];
    };
  };
}
