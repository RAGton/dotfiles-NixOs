{
  pkgs,
  nodeInstallerUi,
  nodeInstallRunner,
  ...
}:

{
  networking.hostName = "node-installer";
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

  systemd.services.node-installer-ui = {
    description = "NODE Installer UI (Axum)";
    wantedBy = [
      "multi-user.target"
      "graphical.target"
    ];
    wants = [ "node-live-paths.service" ];
    after = [ "node-live-paths.service" ];
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
      ExecStart = "${nodeInstallerUi}/bin/node-installer-ui";
      Restart = "on-failure";
      Environment = [
        "NODE_INSTALLER_LISTEN=0.0.0.0:8000"
        "NODE_INSTALLER_STATIC=${nodeInstallerUi}/share/node-installer-ui/static"
        "NODE_INSTALLER_IMGS=${nodeInstallerUi}/share/node-installer-ui/static/imgs"
        "NODE_INSTALLER_RUNTIME=/run/node-installer"
        "NODE_INSTALLER_RUNNER=${nodeInstallRunner}/bin/node-install-runner"
        "NODE_INSTALLER_ZONEINFO_DIR=${pkgs.tzdata}/share/zoneinfo"
        "RUST_LOG=info"
      ];
    };
  };
}
