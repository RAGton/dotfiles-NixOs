{ pkgs, ... }:

let
  debugScript = pkgs.writeShellApplication {
    name = "node-client-debug";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gawk
      gnugrep
      iproute2
      systemd
      util-linux
    ];
    text = ''
      set -euo pipefail

      echo "== profile =="
      cat /etc/issue 2>/dev/null || true
      echo

      echo "== boot network env =="
      cat /run/node/boot-network.env 2>/dev/null || echo "absent"
      echo

      echo "== links =="
      ip -brief link show || true
      echo

      echo "== addresses =="
      ip -brief address show || true
      echo

      echo "== routes =="
      ip route show || true
      echo

      echo "== mounts =="
      findmnt -Rn / /nix/.ro-store /nix/store 2>/dev/null || true
      echo

      echo "== networkctl =="
      networkctl --no-pager --no-legend list 2>/dev/null || true
    '';
  };
in
{
  environment.systemPackages = [ debugScript ];

  systemd.services.node-boot-report = {
    description = "Registra resumo do boot diskless do cliente NODE";
    after = [
      "systemd-networkd.service"
      "remote-fs.target"
    ];
    wantedBy = [
      "multi-user.target"
      "graphical.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${debugScript}/bin/node-client-debug";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };
}
