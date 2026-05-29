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
        # Cage (Wayland) needs XDG_RUNTIME_DIR — getty autologin does not set it
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 0700 "$XDG_RUNTIME_DIR"

        # Required in QEMU/VM: virtio-gpu does not expose hardware cursors
        export WLR_NO_HARDWARE_CURSORS=1

        # Wait up to 30s for the backend (/health) before opening the browser.
        # Full store path avoids relying on PATH being set up during autologin.
        for i in $(seq 1 30); do
          if ${pkgs.curl}/bin/curl -sf "http://127.0.0.1:${toString cfg.port}/health" >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done

        # --app=URL forces app mode: no tab bar, no address bar, no browser chrome.
        # --kiosk alone is insufficient on many Chromium builds inside Cage.
        exec ${pkgs.cage}/bin/cage -- \
          ${pkgs.chromium}/bin/chromium \
            --app="${cfg.url}" \
            --no-sandbox \
            --disable-dev-shm-usage \
            --disable-gpu-sandbox \
            --no-first-run \
            --noerrdialogs \
            --disable-infobars \
            --disable-translate \
            --disable-extensions \
            --disable-pinch \
            --overscroll-history-navigation=0 \
            --disable-features=TranslateUI,OverscrollHistoryNavigation \
            --disable-background-networking \
            --disable-sync
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

    # Autologin direto no TTY1
    services.getty.autologinUser = lib.mkForce "installer";

    # Backend do instalador — roda como root para poder chamar disko/nixos-install
    systemd.services.kryonix-installer-backend = {
      description = "Kryonix Installer Backend";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "network.target" ];
      before      = [ "getty@tty1.service" ];
      serviceConfig = {
        # Binary hardcodes 127.0.0.1:8080 — does not accept --port flag
        ExecStart = "${pkgs.kryonix-installer}/bin/kryonix-installer";
        Restart   = "on-failure";
        User      = "root";
      };
    };

    # Sudo sem senha para o usuário installer (operações manuais via terminal)
    # O backend já roda como root e não precisa de sudo
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

    # Ignorar power/suspend/lid para não interromper o kiosk
    services.logind.settings.Login = {
      HandlePowerKey               = "ignore";
      HandleSuspendKey             = "ignore";
      HandleLidSwitch              = "ignore";
      HandleLidSwitchExternalPower = "ignore";
    };

    # Suprimir cursor piscante no TTY
    boot.kernelParams = [ "vt.global_cursor_default=0" ];

    # disko e nixos-install-tools: necessários para os safety checks do executor
    # (check_disko_available, check_nixos_install_available)
    environment.systemPackages = with pkgs; [
      cage chromium curl
      kryonix-hardware-probe kryonix-installer
      disko nixos-install-tools
    ];

    hardware.opengl.enable = lib.mkDefault true;
  });
}
