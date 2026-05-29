{ config, lib, pkgs, ... }:

let
  cfg = config.kryonix.installer.kiosk;
in
{
  options.kryonix.installer.kiosk = {
    enable = lib.mkEnableOption "Kiosk web do instalador (Cage + Chromium)";
    port   = lib.mkOption { type = lib.types.port; default = 8080; };
    url    = lib.mkOption {
      type    = lib.types.str;
      default = "http://localhost:${toString cfg.port}";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      startKiosk = (pkgs.writeShellScriptBin "start-kiosk" ''
        # Aguarda o backend subir (máx 30s)
        for i in $(seq 1 30); do
          if curl -sf http://localhost:${toString cfg.port}/health >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done

        exec ${pkgs.cage}/bin/cage -- \
          ${pkgs.chromium}/bin/chromium \
            --kiosk \
            --no-sandbox \
            --disable-dev-shm-usage \
            --disable-gpu-sandbox \
            --no-first-run \
            --disable-translate \
            --disable-extensions \
            --disable-background-networking \
            --disable-sync \
            "${cfg.url}"
      '').overrideAttrs (_: { passthru.shellPath = "/bin/start-kiosk"; });
    in
    {

    users.users.installer = {
      isNormalUser = true;
      extraGroups  = [ "wheel" "disk" "video" "input" "drm" ];
      password     = "";
      shell        = startKiosk;
    };

    environment.shells = [ startKiosk ];

    # Autologin direto no TTY1 — não briga com getty
    services.getty.autologinUser = lib.mkForce "installer";

    # Backend do instalador como serviço
    systemd.services.kryonix-installer-backend = {
      description = "Kryonix Installer Backend";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "network.target" ];
      before      = [ "getty@tty1.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.kryonix-installer}/bin/kryonix-installer --port ${toString cfg.port}";
        Restart   = "on-failure";
        User      = "root";
      };
    };

    # Sudo sem senha para operações de disco/instalação
    security.sudo.extraRules = [
      {
        users = [ "installer" ];
        commands = [
          { command = "${pkgs.gptfdisk}/bin/sgdisk";                    options = [ "NOPASSWD" ]; }
          { command = "${pkgs.parted}/bin/partprobe";                   options = [ "NOPASSWD" ]; }
          { command = "${pkgs.dosfstools}/bin/mkfs.fat";                options = [ "NOPASSWD" ]; }
          { command = "${pkgs.btrfs-progs}/bin/mkfs.btrfs";            options = [ "NOPASSWD" ]; }
          { command = "${pkgs.btrfs-progs}/bin/btrfs";                  options = [ "NOPASSWD" ]; }
          { command = "${pkgs.util-linux}/bin/mount";                   options = [ "NOPASSWD" ]; }
          { command = "${pkgs.util-linux}/bin/umount";                  options = [ "NOPASSWD" ]; }
          { command = "${pkgs.nixos-install-tools}/bin/nixos-install";  options = [ "NOPASSWD" ]; }
        ];
      }
    ];

    environment.systemPackages = with pkgs; [ cage chromium curl ];

    hardware.opengl.enable = lib.mkDefault true;
  });
}
