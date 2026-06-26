# =============================================================================
# Module: Feature Network Backend
# =============================================================================
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.kryonix.features.network;
  enabledVirtualBridges = lib.filterAttrs (_: bridgeCfg: bridgeCfg.enable) cfg.virtualBridges;
in
lib.mkIf (enabledVirtualBridges != { }) {
  virtualisation.libvirtd.enable = true;

  systemd.services = lib.mapAttrs' (
    name: bridgeCfg:
    let
      xmlContent = ''
        <network>
          <name>${bridgeCfg.networkName}</name>
          <bridge name='${bridgeCfg.bridgeName}' stp='on' delay='0'/>
          ${lib.optionalString bridgeCfg.nat "<forward mode='nat'/>"}
          <ip address='${bridgeCfg.address}' netmask='${bridgeCfg.netmask}'>
            ${lib.optionalString bridgeCfg.dhcp.enable ''
              <dhcp>
                <range start='${bridgeCfg.dhcp.start}' end='${bridgeCfg.dhcp.end}'/>
              </dhcp>
            ''}
          </ip>
        </network>
      '';

      xmlFile = pkgs.writeText "${bridgeCfg.networkName}.xml" xmlContent;
    in
    lib.nameValuePair "kryonix-libvirt-network-${name}" {
      description = "Kryonix Libvirt network ${bridgeCfg.networkName}";
      wantedBy = [ "multi-user.target" ];
      after = [ "libvirtd.service" ];
      wants = [ "libvirtd.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      path = [
        pkgs.libvirt
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.diffutils
      ];

      script = ''
        set -eu

        NETWORK="${bridgeCfg.networkName}"
        XML="${xmlFile}"

        normalize_xml() {
          sed \
            -e "/<uuid>.*<\/uuid>/d" \
            -e "/<mac address=.*\/>/d" \
            -e "s/[[:space:]]\+$//"
        }

        # Define the network if it does not exist
        if ! virsh -c qemu:///system net-info "$NETWORK" >/dev/null 2>&1; then
          virsh -c qemu:///system net-define "$XML"
        else
          current="$(mktemp)"
          desired="$(mktemp)"
          current_norm="$(mktemp)"
          desired_norm="$(mktemp)"

          trap 'rm -f "$current" "$desired" "$current_norm" "$desired_norm"' EXIT

          virsh -c qemu:///system net-dumpxml "$NETWORK" > "$current"
          cp "$XML" "$desired"

          normalize_xml < "$current" > "$current_norm"
          normalize_xml < "$desired" > "$desired_norm"

          if ! diff -u "$current_norm" "$desired_norm"; then
            echo "ERROR: Libvirt network '$NETWORK' already exists but differs from Kryonix desired XML." >&2
            echo "This service will not destroy or undefine existing networks automatically." >&2
            echo "Manual migration is required." >&2
            echo "Desired XML: $XML" >&2
            exit 1
          fi
        fi

        # Start the network if it is not active
        if ! virsh -c qemu:///system net-info "$NETWORK" | grep -q "Active:.*yes"; then
          virsh -c qemu:///system net-start "$NETWORK"
        fi

        # Ensure autostart is enabled
        virsh -c qemu:///system net-autostart "$NETWORK"
      '';
    }
  ) enabledVirtualBridges;
}
