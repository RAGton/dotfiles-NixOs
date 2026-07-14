{
  config,
  lib,
  pkgs,
  nodeServerIp,
  nodeHttpPort,
  nodeMgmtInterface,
  nodeMgmtBondMode ? "",
  nodeMgmtBondMembers ? [ ],
  nodeMgmtPrefixLength,
  nodeMgmtGateway,
  nodeMgmtDns,
  nodeWanInterface ? "",
  nodeWanMode ? "dhcp",
  nodeWanAddress ? "",
  nodeWanPrefixLength ? 24,
  nodeWanGateway ? "",
  nodeWanDns ? [ ],
  nodeWanPppoeUser ? "",
  ...
}:

let
  haveWan = nodeWanInterface != "";
  haveMgmtBond = nodeMgmtBondMode != "" && builtins.length nodeMgmtBondMembers >= 2;
  wanStatic = nodeWanMode == "static";
  wanPppoe = nodeWanMode == "pppoe";
  natExternalInterface = if wanPppoe then "ppp0" else nodeWanInterface;
  pppoeStartScript = pkgs.writeShellScript "node-pppoe-start" ''
    set -euo pipefail
    source /etc/node/wan-pppoe.env
    exec ${pkgs.ppp}/bin/pppd \
      nodetach \
      noauth \
      plugin pppoe.so ${nodeWanInterface} \
      user "${nodeWanPppoeUser}" \
      password "$PPPOE_PASSWORD" \
      defaultroute \
      replacedefaultroute \
      usepeerdns \
      persist \
      maxfail 0 \
      hide-password \
      mtu 1492 \
      mru 1492 \
      linkname node-wan
  '';
in
{
  networking.useDHCP = false;
  systemd.network.enable = true;
  systemd.network.netdevs = lib.mkIf haveMgmtBond {
    "20-${nodeMgmtInterface}" = {
      netdevConfig = {
        Name = nodeMgmtInterface;
        Kind = "bond";
      };
      bondConfig = {
        Mode = nodeMgmtBondMode;
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
            networkConfig.Bond = nodeMgmtInterface;
          };
        }) nodeMgmtBondMembers
      )
    )
    // {
      lan = {
        matchConfig.Name = nodeMgmtInterface;
        networkConfig = {
          Address = "${nodeServerIp}/${builtins.toString nodeMgmtPrefixLength}";
          DNS = nodeMgmtDns;
        }
        // lib.optionalAttrs (!haveWan) {
          Gateway = nodeMgmtGateway;
        };
      };
    }
    // lib.optionalAttrs (haveWan && !wanPppoe) {
      wan = {
        matchConfig.Name = nodeWanInterface;
        networkConfig =
          if wanStatic then
            {
              Address = "${nodeWanAddress}/${builtins.toString nodeWanPrefixLength}";
              Gateway = nodeWanGateway;
              DNS = nodeWanDns;
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
    internalInterfaces = [ nodeMgmtInterface ];
  };

  systemd.services.node-pppoe = lib.mkIf (haveWan && wanPppoe) {
    description = "NODE WAN PPPoE session";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "systemd-networkd.service"
    ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "/etc/node/wan-pppoe.env";
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

    interfaces."${nodeMgmtInterface}" = {
      allowedTCPPorts = [
        nodeHttpPort # HTTP — kernel/initrd/boot.ipxe
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
