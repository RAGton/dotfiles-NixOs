{
  pkgs,
  nodeServerIp,
  nodeHttpPort,
  nodeDefaultClientTarget ? "desktop-generic",
}:

let
  normalizeText = text: builtins.replaceStrings [ "\r\n" ] [ "\n" ] text;
  normalizeShellText = path: normalizeText (builtins.readFile path);
in
pkgs.writeShellApplication {
  name = "knyc";

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
      SERVER_IP="''${KNYC_SERVER_IP:-${nodeServerIp}}"
      HTTP_PORT="''${KNYC_HTTP_PORT:-${toString nodeHttpPort}}"
      DATA_ROOT="''${KNYC_DATA_ROOT:-/srv/data}"
      TFTP_ROOT="''${KNYC_TFTP_ROOT:-/srv/tftp}"
      HTTP_ROOT="''${KNYC_HTTP_ROOT:-/srv/http}"
      IMAGES_ROOT="''${KNYC_IMAGES_ROOT:-/srv/data/images}"
      KEEP_VERSIONS="''${KNYC_KEEP_VERSIONS:-5}"
      DEFAULT_CLIENT_TARGET="''${KNYC_DEFAULT_CLIENT_TARGET:-${nodeDefaultClientTarget}}"
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
