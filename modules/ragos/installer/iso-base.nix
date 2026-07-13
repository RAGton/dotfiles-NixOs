{
  config,
  lib,
  pkgs,
  ragosSrc,
  ragosInstallerUi,
  ragosInstall,
  ragosCli,
  ragosTerminalLauncher,
  ragcPkg ? null,
  normalizeText,
  ...
}:

{
  image.baseName = lib.mkForce "ragos-installer";
  image.fileName = lib.mkForce "ragos-installer.iso";
  isoImage.volumeID = lib.mkForce "RAGOS_INSTALLER";

  system.nixos.distroName = lib.mkOverride 90 "Install RAGOS (Graphical)";
  system.nixos.label = lib.mkOverride 90 "";
  isoImage.prependToMenuLabel = lib.mkOverride 90 "";
  isoImage.appendToMenuLabel = lib.mkOverride 90 "";
  systemd.defaultUnit = lib.mkDefault "graphical.target";

  specialisation.install-terminal.configuration = {
    system.nixos.distroName = lib.mkOverride 80 "Install RAGOS (Terminal)";
    system.nixos.label = lib.mkOverride 80 "";
    isoImage.prependToMenuLabel = lib.mkOverride 80 "";
    isoImage.appendToMenuLabel = lib.mkOverride 80 "";
    systemd.defaultUnit = lib.mkForce "multi-user.target";
    services.xserver.autorun = lib.mkForce false;
    services.xserver.displayManager.lightdm.enable = lib.mkForce false;
    services.displayManager.autoLogin.enable = lib.mkForce false;
    systemd.services.ragos-terminal-installer.enable = lib.mkForce true;
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
    systemd.services.ragos-terminal-installer.enable = lib.mkForce false;
  };

  boot.loader.grub.memtest86.enable = lib.mkForce false;

  isoImage.contents = [
    {
      source = ragosSrc;
      target = "/opt/ragos-src";
    }
  ];

  environment.systemPackages =
    with pkgs;
    [
      ragosInstallerUi
      ragosInstall
      ragosCli
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
    ++ lib.optionals (ragcPkg != null) [ ragcPkg ];

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
      message = "RAGOS ISO kiosk requires fonts.fontconfig.enable so Chromium can resolve /etc/fonts/fonts.conf.";
    }
  ];

  systemd.tmpfiles.rules = [
    "d /run/ragos 0755 ragos users -"
    "d /run/ragos-installer 0755 root root -"
    "d /opt 0755 root root -"
    "L+ /opt/ragos-src - - - - /iso/opt/ragos-src"
    "d /home/ragos/.config 0755 ragos users -"
    "d /home/ragos/.config/openbox 0755 ragos users -"
    "d /home/ragos/.cache 0755 ragos users -"
    "L+ /home/ragos/.config/openbox/autostart - - - - /etc/xdg/openbox/autostart"
    "L+ /home/ragos/.config/openbox/rc.xml - - - - /etc/xdg/openbox/rc.xml"
  ];

  systemd.services.ragos-live-paths = {
    description = "RAGOS live filesystem bridge";
    wantedBy = [
      "multi-user.target"
      "graphical.target"
    ];
    before = [
      "ragos-installer-ui.service"
      "display-manager.service"
      "ragos-terminal-installer.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = normalizeText ''
      mkdir -p /opt /run/ragos /run/ragos/kiosk-profile /run/ragos-installer /home/ragos/.config/openbox /home/ragos/.cache
      if [[ -d /iso/opt/ragos-src ]]; then
        ln -sfn /iso/opt/ragos-src /opt/ragos-src
      fi
      chown -R ragos:users /run/ragos /home/ragos/.config /home/ragos/.cache
      chmod 700 /run/ragos/kiosk-profile
      ln -sfn /etc/xdg/openbox/autostart /home/ragos/.config/openbox/autostart
      ln -sfn /etc/xdg/openbox/rc.xml /home/ragos/.config/openbox/rc.xml
    '';
  };

  services.getty.autologinUser = lib.mkForce null;
  systemd.services."getty@tty1".enable = lib.mkForce false;
  systemd.services."autovt@tty1".enable = lib.mkForce false;

  systemd.services.ragos-terminal-installer = {
    description = "RAGOS terminal installer on tty1";
    enable = false;
    wantedBy = [ "multi-user.target" ];
    wants = [
      "ragos-live-paths.service"
      "ragos-installer-ui.service"
    ];
    after = [
      "systemd-user-sessions.service"
      "ragos-live-paths.service"
      "ragos-installer-ui.service"
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
      ExecStart = "${ragosTerminalLauncher}/bin/ragos-terminal-launcher";
    };
  };
}
