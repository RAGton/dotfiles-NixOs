{
  config,
  lib,
  pkgs,
  ...
}:

let
  bootVerbose = lib.attrByPath [ "ragos" "profile" "bootVerbose" ] false config;
  ragosPlymouthTheme = pkgs.callPackage ./ragos { };
  quietKernelParams = [
    "quiet"
    "splash"
    # Mantem o splash grafico mesmo quando o servidor tambem expoe console serial
    # para debug/automacao em KVM/libvirt.
    "plymouth.ignore-serial-consoles"
    "vt.global_cursor_default=0"
    "loglevel=3"
    "rd.systemd.show_status=auto"
    "systemd.show_status=auto"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];
  verboseKernelParams = [
    "loglevel=6"
    "rd.systemd.show_status=yes"
    "systemd.show_status=yes"
    "rd.udev.log_level=info"
    "udev.log_priority=info"
  ];
in
{
  boot = {
    consoleLogLevel = if bootVerbose then 6 else 3;
    initrd.verbose = bootVerbose;
    kernelParams = if bootVerbose then verboseKernelParams else quietKernelParams;

    plymouth = lib.mkIf (!bootVerbose) {
      enable = true;
      theme = "ragos";
      themePackages = [ ragosPlymouthTheme ];
    };
  };
}
