{ pkgs, ... }:

let
  homeUnmountScript = pkgs.writeShellScript "ragos-home-unmount" ''
        set -eu

        log() {
          echo "ragos-shutdown: $*" >&2
        }

        mounts="$(${pkgs.util-linux}/bin/findmnt -rn -t nfs,nfs4 -o TARGET 2>/dev/null | ${pkgs.gawk}/bin/awk '$1 ~ "^/home/" { print $1 }' | ${pkgs.coreutils}/bin/sort -r || true)"

        if [[ -z "$mounts" ]]; then
          log "nenhum home NFS montado para desmontar"
          exit 0
        fi

        while IFS= read -r mountpoint; do
          [[ -n "$mountpoint" ]] || continue

          if ${pkgs.util-linux}/bin/umount "$mountpoint" 2>/dev/null; then
            log "home desmontado: $mountpoint"
            continue
          fi

          log "umount normal falhou em $mountpoint; aplicando lazy umount"
          ${pkgs.util-linux}/bin/umount -l "$mountpoint" || log "falha ao desmontar $mountpoint"
        done <<EOF
    $mounts
    EOF
  '';
in
{
  systemd.services.ragos-home-unmount = {
    description = "Desmonta homes NFS do RAGOS antes da parada da rede";
    wantedBy = [
      "halt.target"
      "reboot.target"
      "poweroff.target"
      "kexec.target"
    ];
    before = [
      "halt.target"
      "reboot.target"
      "poweroff.target"
      "kexec.target"
      "umount.target"
      "network.target"
      "network-online.target"
      "remote-fs.target"
      "systemd-networkd.service"
    ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = homeUnmountScript;
      TimeoutStartSec = "15s";
    };
  };

  systemd.services.systemd-networkd.serviceConfig.TimeoutStopSec = "15s";
}
