{
  pkgs,
  ragosInstallerUi,
  ragosInstallRunner,
  ...
}:

{
  networking.hostName = "ragos-installer";
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    8000
  ];
  systemd.services."NetworkManager-wait-online".enable = false;

  services.openssh.enable = true;
  services.openssh.openFirewall = true;
  services.openssh.settings = {
    PasswordAuthentication = true;
    PermitRootLogin = "yes";
  };

  systemd.services.ragos-installer-ui = {
    description = "RAGOS Installer UI (Axum)";
    wantedBy = [
      "multi-user.target"
      "graphical.target"
    ];
    wants = [ "ragos-live-paths.service" ];
    after = [ "ragos-live-paths.service" ];
    path = with pkgs; [
      coreutils
      util-linux
      iproute2
      systemd
      whois
      tzdata
    ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${ragosInstallerUi}/bin/ragos-installer-ui";
      Restart = "on-failure";
      Environment = [
        "RAGOS_INSTALLER_LISTEN=0.0.0.0:8000"
        "RAGOS_INSTALLER_STATIC=${ragosInstallerUi}/share/ragos-installer-ui/static"
        "RAGOS_INSTALLER_IMGS=${ragosInstallerUi}/share/ragos-installer-ui/static/imgs"
        "RAGOS_INSTALLER_RUNTIME=/run/ragos-installer"
        "RAGOS_INSTALLER_RUNNER=${ragosInstallRunner}/bin/ragos-install-runner"
        "RAGOS_INSTALLER_ZONEINFO_DIR=${pkgs.tzdata}/share/zoneinfo"
        "RUST_LOG=info"
      ];
    };
  };
}
