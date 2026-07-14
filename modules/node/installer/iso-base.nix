{
  config,
  lib,
  pkgs,
  nodeSrc,
  nodeInstallerUi,
  nodeInstall,
  nodeCli,
  nodeTerminalLauncher,
  knycPkg ? null,
  normalizeText,
  ...
}:

{
  image.baseName = lib.mkForce "node-installer";
  image.fileName = lib.mkForce "node-installer.iso";
  isoImage.volumeID = lib.mkForce "NODE_INSTALLER";

  system.nixos.distroName = lib.mkOverride 90 "Install NODE (Graphical)";
  system.nixos.label = lib.mkOverride 90 "";
  isoImage.prependToMenuLabel = lib.mkOverride 90 "";
  isoImage.appendToMenuLabel = lib.mkOverride 90 "";
  systemd.defaultUnit = lib.mkDefault "graphical.target";

  specialisation.install-terminal.configuration = {
    system.nixos.distroName = lib.mkOverride 80 "Install NODE (Terminal)";
    system.nixos.label = lib.mkOverride 80 "";
    isoImage.prependToMenuLabel = lib.mkOverride 80 "";
    isoImage.appendToMenuLabel = lib.mkOverride 80 "";
    systemd.defaultUnit = lib.mkForce "multi-user.target";
    services.xserver.autorun = lib.mkForce false;
    services.xserver.displayManager.lightdm.enable = lib.mkForce false;
    services.displayManager.autoLogin.enable = lib.mkForce false;
    systemd.services.node-terminal-installer.enable = lib.mkForce true;
  };

  specialisation.rescue.configuration = {
    system.nixos.distroName = lib.mkOverride 80 "Rescue Mode";
    system.nixos.label = lib.mkOverride 80 "";
    isoImage.prependToMenuLabel = lib.mkOverride 80 "";
    isoImage.appendToMenuLabel = lib.mkOverride 80 "";
    systemd.defaultUnit = lib.mkForce "rescue.target";
    services.xserver.autorun = lib.mkForce false;
    services.xserver.displayManager.lightdm.enable = lib.mkForce false;
    services.displayManager.autoLogin.enable = lib.mkForce false;
    systemd.services.node-terminal-installer.enable = lib.mkForce false;
  };

  boot.loader.grub.memtest86.enable = lib.mkForce false;

  isoImage.contents = [
    {
      source = nodeSrc;
      target = "/opt/node-src";
    }
  ];

  environment.systemPackages =
    with pkgs;
    [
      nodeInstallerUi
      nodeInstall
      nodeCli
      parted
      btrfs-progs
      e2fsprogs
      xfsprogs
      mdadm
      cryptsetup
      nfs-utils
      dnsmasq
      nginx
      iproute2
      ppp
      htop
      vim
      git
      jq
      util-linux
      gptfdisk
      dosfstools
      newt
      dialog
      chromium
      whois
      yad
      fontconfig
      dejavu_fonts
      liberation_ttf
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ]
    ++ lib.optionals (knycPkg != null) [ knycPkg ];

  fonts.packages = with pkgs; [
    dejavu_fonts
    liberation_ttf
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];
  fonts.fontconfig.enable = true;
  fonts.fontDir.enable = true;

  assertions = [
    {
      assertion = config.fonts.fontconfig.enable;
      message = "NODE ISO kiosk requires fonts.fontconfig.enable so Chromium can resolve /etc/fonts/fonts.conf.";
    }
  ];

  systemd.tmpfiles.rules = [
    "d /run/node 0755 node users -"
    "d /run/node-installer 0755 root root -"
    "d /opt 0755 root root -"
    "L+ /opt/node-src - - - - /iso/opt/node-src"
    "d /home/node/.config 0755 node users -"
    "d /home/node/.config/openbox 0755 node users -"
    "d /home/node/.cache 0755 node users -"
    "L+ /home/node/.config/openbox/autostart - - - - /etc/xdg/openbox/autostart"
    "L+ /home/node/.config/openbox/rc.xml - - - - /etc/xdg/openbox/rc.xml"
  ];

  systemd.services.node-live-paths = {
    description = "NODE live filesystem bridge";
    wantedBy = [
      "multi-user.target"
      "graphical.target"
    ];
    before = [
      "node-installer-ui.service"
      "display-manager.service"
      "node-terminal-installer.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = normalizeText ''
      mkdir -p /opt /run/node /run/node/kiosk-profile /run/node-installer /home/node/.config/openbox /home/node/.cache
      if [[ -d /iso/opt/node-src ]]; then
        ln -sfn /iso/opt/node-src /opt/node-src
      fi
      chown -R node:users /run/node /home/node/.config /home/node/.cache
      chmod 700 /run/node/kiosk-profile
      ln -sfn /etc/xdg/openbox/autostart /home/node/.config/openbox/autostart
      ln -sfn /etc/xdg/openbox/rc.xml /home/node/.config/openbox/rc.xml
    '';
  };

  services.getty.autologinUser = lib.mkForce null;
  systemd.services."getty@tty1".enable = lib.mkForce false;
  systemd.services."autovt@tty1".enable = lib.mkForce false;

  systemd.services.node-terminal-installer = {
    description = "NODE terminal installer on tty1";
    enable = false;
    wantedBy = [ "multi-user.target" ];
    wants = [
      "node-live-paths.service"
      "node-installer-ui.service"
    ];
    after = [
      "systemd-user-sessions.service"
      "node-live-paths.service"
      "node-installer-ui.service"
    ];
    conflicts = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "simple";
      StandardInput = "tty-force";
      StandardOutput = "tty";
      StandardError = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
      Restart = "on-failure";
      RestartSec = 1;
      UtmpIdentifier = "tty1";
      UtmpMode = "user";
      ExecStart = "${nodeTerminalLauncher}/bin/node-terminal-launcher";
    };
  };
}
