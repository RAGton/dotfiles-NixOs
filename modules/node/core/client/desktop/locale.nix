{
  lib,
  nodeServerIp,
  nodeLocale,
  nodeTimeZone,
  nodeKeyMap,
  ...
}:

let
  localeTag = builtins.elemAt (builtins.split "\\." nodeLocale) 0;
  keyMapParts = lib.splitString "-" nodeKeyMap;
  inferredXkbLayout =
    if nodeKeyMap == "br-abnt2" || nodeKeyMap == "br-abnt" then "br" else builtins.head keyMapParts;
  inferredXkbVariant =
    if builtins.length keyMapParts > 1 then
      lib.concatStringsSep "-" (builtins.tail keyMapParts)
    else
      "";
in
{
  i18n.defaultLocale = nodeLocale;

  i18n.extraLocaleSettings = {
    LC_ADDRESS = nodeLocale;
    LC_IDENTIFICATION = nodeLocale;
    LC_MEASUREMENT = nodeLocale;
    LC_MONETARY = nodeLocale;
    LC_NAME = nodeLocale;
    LC_NUMERIC = nodeLocale;
    LC_PAPER = nodeLocale;
    LC_TELEPHONE = nodeLocale;
    LC_TIME = nodeLocale;
  };

  environment.variables = {
    LANG = nodeLocale;
    LC_ALL = nodeLocale;
  };

  environment.etc."xdg/kdeglobals".text = ''
    [Locale]
    Language=${localeTag}
  '';

  services.timesyncd.servers = [ nodeServerIp ];
  services.timesyncd.fallbackServers = [ ];
  time.timeZone = nodeTimeZone;
  systemd.services.save-hwclock.enable = false;
  console.keyMap = nodeKeyMap;

  # O SDDM/Plasma precisa de XKB coerente com o keymap operacional; sem isso o
  # teclado do login diverge do console e a senha pode falhar silenciosamente.
  services.xserver.xkb = {
    layout = inferredXkbLayout;
    variant = inferredXkbVariant;
  };
}
