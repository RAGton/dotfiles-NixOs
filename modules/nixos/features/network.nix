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
            echo "WARN: Libvirt network '$NETWORK' diverges from Kryonix desired XML." >&2

            ALLOW_DESTRUCTIVE="${lib.boolToString bridgeCfg.migration.allowDestructiveReconcile}"
            REQUIRE_NO_RUNNING="${lib.boolToString bridgeCfg.migration.requireNoRunningDomains}"
            BACKUP_DIR="${bridgeCfg.migration.backupDir}"

            if [ "$ALLOW_DESTRUCTIVE" != "true" ]; then
              echo "ERROR: Libvirt network '$NETWORK' already exists but differs from Kryonix desired XML." >&2
              echo "ERROR: migration.allowDestructiveReconcile is false." >&2
              echo "Manual migration is required or set allowDestructiveReconcile to true temporarily." >&2
              echo "Desired XML: $XML" >&2
              exit 1
            fi

            if [ "$REQUIRE_NO_RUNNING" = "true" ]; then
              RUNNING_DOMAINS=$(virsh -c qemu:///system list --name --state-running)
              for dom in $RUNNING_DOMAINS; do
                # Check if the domain's XML contains a network interface connected to this network
                if virsh -c qemu:///system dumpxml "$dom" | grep -E -q "<source network=['\"]$NETWORK['\"]"; then
                  echo "ERROR: Domain '$dom' is running and using network '$NETWORK'." >&2
                  echo "Migration aborted because migration.requireNoRunningDomains is true." >&2
                  exit 1
                fi
              done
            fi

            echo "INFO: Proceeding with destructive reconciliation for network '$NETWORK'."

            # Backup existing XML
            mkdir -p "$BACKUP_DIR"
            TIMESTAMP=$(date +%Y%m%d%H%M%S)
            BACKUP_FILE="$BACKUP_DIR/''${NETWORK}-backup-''${TIMESTAMP}.xml"
            if ! cp "$current" "$BACKUP_FILE"; then
              echo "ERROR: Failed to create backup at $BACKUP_FILE" >&2
              exit 1
            fi
            echo "INFO: Backup saved to: $BACKUP_FILE"

            # Destroy (if active) and undefine
            if virsh -c qemu:///system net-info "$NETWORK" | grep -q "Active:.*yes"; then
              virsh -c qemu:///system net-destroy "$NETWORK"
              echo "INFO: Network '$NETWORK' destroyed."
            fi
            virsh -c qemu:///system net-undefine "$NETWORK"
            echo "INFO: Network '$NETWORK' undefined."

            # Define new network
            virsh -c qemu:///system net-define "$XML"
            echo "INFO: Network '$NETWORK' redefined with desired XML."
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
