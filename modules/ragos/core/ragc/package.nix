{
  pkgs,
  ragosServerIp,
  ragosHttpPort,
  ragosDefaultClientTarget ? "desktop-generic",
}:

let
  normalizeText = text: builtins.replaceStrings [ "\r\n" ] [ "\n" ] text;
  normalizeShellText = path: normalizeText (builtins.readFile path);
in
pkgs.writeShellApplication {
  name = "ragc";

  runtimeInputs = with pkgs; [
    nix
    coreutils
    gnugrep
    gawk
    findutils
    iproute2
    curl
    systemd
    gnused
    util-linux
  ];

  text =
    normalizeText ''
      SERVER_IP="''${RAGC_SERVER_IP:-${ragosServerIp}}"
      HTTP_PORT="''${RAGC_HTTP_PORT:-${toString ragosHttpPort}}"
      DATA_ROOT="''${RAGC_DATA_ROOT:-/srv/data}"
      TFTP_ROOT="''${RAGC_TFTP_ROOT:-/srv/tftp}"
      HTTP_ROOT="''${RAGC_HTTP_ROOT:-/srv/http}"
      IMAGES_ROOT="''${RAGC_IMAGES_ROOT:-/srv/data/images}"
      KEEP_VERSIONS="''${RAGC_KEEP_VERSIONS:-5}"
      DEFAULT_CLIENT_TARGET="''${RAGC_DEFAULT_CLIENT_TARGET:-${ragosDefaultClientTarget}}"
      VERSION="4.1.0"

    ''
    + normalizeShellText ./lib/common.sh
    + "\n"
    + normalizeShellText ./lib/lock.sh
    + "\n"
    + normalizeShellText ./lib/manifest.sh
    + "\n"
    + normalizeShellText ./lib/boot.sh
    + "\n"
    + normalizeShellText ./lib/publish.sh
    + "\n"
    + normalizeShellText ./commands/switch.sh
    + "\n"
    + normalizeShellText ./commands/rollback.sh
    + "\n"
    + normalizeShellText ./commands/list.sh
    + "\n"
    + normalizeShellText ./commands/status.sh
    + "\n"
    + normalizeShellText ./commands/gc.sh
    + "\n"
    + normalizeShellText ./commands/help.sh
    + "\n"
    + normalizeShellText ./commands/doctor.sh
    + "\n"
    + normalizeShellText ./commands/router.sh;
}
