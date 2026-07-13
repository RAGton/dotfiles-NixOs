{ lib, ... }:

{
  boot.initrd.network.enable = true;
  boot.initrd.network.flushBeforeStage2 = false;

  boot.initrd.availableKernelModules = [
    "nfs"
    "nfsv4"
    "overlay"
  ];

  boot.initrd.supportedFilesystems = [
    "nfs"
    "nfsv4"
    "overlay"
  ];

  boot.kernelParams = [
    "rd.neednet=1"
    "rd.net.timeout.carrier=30"
    "rd.net.timeout.iflink=60"
    "rd.retry=15"
  ];

  boot.initrd.network.postCommands = lib.mkAfter ''
        mkdir -p /run/ragos
        log_file=/run/ragos/initrd-network.log

        {
          echo "[ragos-initrd] cmdline: $(cat /proc/cmdline 2>/dev/null || echo unavailable)"
          echo "[ragos-initrd] routes"
          ip route show || true
          echo "[ragos-initrd] addresses"
          ip -o addr show || true

          boot_if="$(ip route show default 2>/dev/null | awk 'NR==1 { print $5 }')"
          if [ -z "$boot_if" ] && [ -n "$ifaces" ]; then
            for candidate in $ifaces; do
              if ip -o addr show dev "$candidate" scope global 2>/dev/null | grep -q 'inet '; then
                boot_if="$candidate"
                break
              fi
            done
          fi

          if [ -n "$boot_if" ] && [ -r "/sys/class/net/$boot_if/address" ]; then
            boot_mac="$(tr '[:upper:]' '[:lower:]' < "/sys/class/net/$boot_if/address" 2>/dev/null || true)"
            boot_addr="$(ip -o -4 addr show dev "$boot_if" scope global 2>/dev/null | awk 'NR==1 { print $4 }')"
            boot_router="$(ip route show default dev "$boot_if" 2>/dev/null | awk 'NR==1 { print $3 }')"
          else
            boot_mac=""
            boot_addr=""
            boot_router=""
          fi

          if printf '%s\n' "$boot_mac" | grep -Eq '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'; then
            cat > /run/ragos/boot-network.env <<EOF
    BOOT_IFACE=$boot_if
    BOOT_MAC=$boot_mac
    BOOT_ADDR=$boot_addr
    BOOT_ROUTER=$boot_router
    EOF
            echo "[ragos-initrd] selected_boot_if=$boot_if selected_boot_mac=$boot_mac addr=$boot_addr router=$boot_router"
          else
            echo "[ragos-initrd] no valid boot MAC captured"
          fi
        } > "$log_file" 2>&1
  '';

  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir -p /mnt-root/nix/.rw-store/store
    mkdir -p /mnt-root/nix/.rw-store/work
    mkdir -p /mnt-root/nix/store
  '';

  boot.initrd.postMountCommands = lib.mkAfter ''
    mkdir -p /run/ragos
    {
      echo "[ragos-initrd] mounts after stage-1"
      findmnt -Rn /mnt-root || true
      echo "[ragos-initrd] ro-store"
      findmnt -Rn /mnt-root/nix/.ro-store || true
      echo "[ragos-initrd] merged-store"
      findmnt -Rn /mnt-root/nix/store || true
    } > /run/ragos/initrd-mounts.log 2>&1
  '';
}
