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
  networking.firewall.trustedInterfaces = lib.mapAttrsToList (_: v: v.bridgeName) enabledVirtualBridges;

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
            -e "s/[[:space:]]\+$//" || true
        }

        # Function to safely run virsh without breaking the script
        safe_virsh() {
          virsh -c qemu:///system "$@" || {
            echo "WARN: Failed to run virsh $1 for network '$NETWORK'." >&2
            return 1
          }
        }

        # Define the network if it does not exist
        if ! safe_virsh net-info "$NETWORK" >/dev/null 2>&1; then
          safe_virsh net-define "$XML" || true
        else
          current="$(mktemp)"
          desired="$(mktemp)"
          current_norm="$(mktemp)"
          desired_norm="$(mktemp)"

          trap 'rm -f "$current" "$desired" "$current_norm" "$desired_norm"' EXIT

          if safe_virsh net-dumpxml "$NETWORK" > "$current"; then
            cp "$XML" "$desired"

            normalize_xml < "$current" > "$current_norm"
            normalize_xml < "$desired" > "$desired_norm"

            if ! diff -u "$current_norm" "$desired_norm" >/dev/null; then
              echo "WARN: Libvirt network '$NETWORK' diverges from Kryonix desired XML." >&2

              ALLOW_DESTRUCTIVE="${lib.boolToString bridgeCfg.migration.allowDestructiveReconcile}"
              REQUIRE_NO_RUNNING="${lib.boolToString bridgeCfg.migration.requireNoRunningDomains}"
              BACKUP_DIR="${bridgeCfg.migration.backupDir}"

              if [ "$ALLOW_DESTRUCTIVE" != "true" ]; then
                echo "WARN: Libvirt network '$NETWORK' already exists but differs from Kryonix desired XML." >&2
                echo "WARN: migration.allowDestructiveReconcile is false. Skipping redefinition." >&2
              else
                if [ "$REQUIRE_NO_RUNNING" = "true" ]; then
                  RUNNING_DOMAINS=$(safe_virsh list --name --state-running || echo "")
                  for dom in $RUNNING_DOMAINS; do
                    if safe_virsh dumpxml "$dom" | grep -E -q "<source network=['\"]$NETWORK['\"]"; then
                      echo "ERROR: Domain '$dom' is running and using network '$NETWORK'." >&2
                      echo "WARN: Migration aborted because migration.requireNoRunningDomains is true." >&2
                      exit 0
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
                  exit 0
                fi
                echo "INFO: Backup saved to: $BACKUP_FILE"

                # Destroy (if active) and undefine
                if safe_virsh net-info "$NETWORK" | grep -q "Active:.*yes"; then
                  safe_virsh net-destroy "$NETWORK" || true
                  echo "INFO: Network '$NETWORK' destroyed."
                fi
                safe_virsh net-undefine "$NETWORK" || true
                echo "INFO: Network '$NETWORK' undefined."

                # Define new network
                safe_virsh net-define "$XML" || true
                echo "INFO: Network '$NETWORK' redefined with desired XML."
              fi
            fi
          fi
        fi

        # Start the network if it is not active
        if ! safe_virsh net-info "$NETWORK" | grep -q "Active:.*yes"; then
          safe_virsh net-start "$NETWORK" || true
        fi

        # Ensure autostart is enabled
        safe_virsh net-autostart "$NETWORK" || true
      '';
    }
  ) enabledVirtualBridges;
}
