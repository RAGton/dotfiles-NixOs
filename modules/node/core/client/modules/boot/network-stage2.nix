{
  config,
  pkgs,
  lib,
  ...
}:

let
  preferredConfigMac = lib.toLower config.node.boot.primaryNicMac;
  networkdProfileScript = pkgs.writeShellScript "node-networkd-profile" ''
        set -eu

        runtime_dir=/run/systemd/network
        primary_file="$runtime_dir/10-node-primary.network"
        fallback_file="$runtime_dir/90-node-fallback-dhcp.network"
        mkdir -p "$runtime_dir"

        preferred="${preferredConfigMac}"

        if [[ -z "$preferred" && -r /run/node/boot-network.env ]]; then
          # shellcheck disable=SC1091
          . /run/node/boot-network.env
          preferred="''${BOOT_MAC:-}"
        fi

        if [[ -z "$preferred" ]]; then
          for token in $(cat /proc/cmdline 2>/dev/null); do
            case "$token" in
              node.primaryNicMac=*)
                preferred="''${token#node.primaryNicMac=}"
                break
                ;;
            esac
          done
        fi

        preferred="$(printf '%s' "$preferred" | tr '[:upper:]' '[:lower:]')"

        if [[ "$preferred" =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]]; then
          cat > "$primary_file" <<EOF
    [Match]
    PermanentMACAddress=$preferred

    [Network]
    DHCP=ipv4
    IPv6AcceptRA=false

    [DHCPv4]
    UseHostname=true
    RouteMetric=50
    EOF
          rm -f "$fallback_file"
          echo "node-networkd-prestart: DHCP preso a MAC de boot $preferred"
        else
          rm -f "$primary_file"
          cat > "$fallback_file" <<'EOF'
    [Match]
    Type=ether

    [Network]
    DHCP=ipv4
    IPv6AcceptRA=false

    [DHCPv4]
    UseHostname=true
    RouteMetric=200
    EOF
          echo "node-networkd-prestart: sem MAC de boot valida; fallback DHCP em todas as interfaces cabeadas"
        fi
  '';
in
{
  networking.useDHCP = lib.mkForce false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.wait-online.enable = false;
  networking.hostName = "";
  boot.loader.grub.enable = false;

  systemd.services.node-networkd-profile = {
    description = "Gera os perfis DHCP do networkd para o cliente NODE";
    before = [ "systemd-networkd.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = networkdProfileScript;
      RemainAfterExit = true;
    };
  };

  systemd.services.systemd-networkd = {
    wants = [ "node-networkd-profile.service" ];
    after = [ "node-networkd-profile.service" ];
  };

  systemd.network.networks."99-ethernet-default-dhcp".enable = false;
  systemd.network.networks."99-wireless-client-dhcp".enable = false;
}
