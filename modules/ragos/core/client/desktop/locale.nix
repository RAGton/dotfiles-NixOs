{
  lib,
  ragosServerIp,
  ragosLocale,
  ragosTimeZone,
  ragosKeyMap,
  ...
}:

let
  localeTag = builtins.elemAt (builtins.split "\\." ragosLocale) 0;
  keyMapParts = lib.splitString "-" ragosKeyMap;
  inferredXkbLayout =
    if ragosKeyMap == "br-abnt2" || ragosKeyMap == "br-abnt" then "br" else builtins.head keyMapParts;
  inferredXkbVariant =
    if builtins.length keyMapParts > 1 then
      lib.concatStringsSep "-" (builtins.tail keyMapParts)
    else
      "";
in
{
  i18n.defaultLocale = ragosLocale;

  i18n.extraLocaleSettings = {
    LC_ADDRESS = ragosLocale;
    LC_IDENTIFICATION = ragosLocale;
    LC_MEASUREMENT = ragosLocale;
    LC_MONETARY = ragosLocale;
    LC_NAME = ragosLocale;
    LC_NUMERIC = ragosLocale;
    LC_PAPER = ragosLocale;
    LC_TELEPHONE = ragosLocale;
    LC_TIME = ragosLocale;
  };

  environment.variables = {
    LANG = ragosLocale;
    LC_ALL = ragosLocale;
  };

  environment.etc."xdg/kdeglobals".text = ''
    [Locale]
    Language=${localeTag}
  '';

  services.timesyncd.servers = [ ragosServerIp ];
  services.timesyncd.fallbackServers = [ ];
  time.timeZone = ragosTimeZone;
  systemd.services.save-hwclock.enable = false;
  console.keyMap = ragosKeyMap;

  # O SDDM/Plasma precisa de XKB coerente com o keymap operacional; sem isso o
  # teclado do login diverge do console e a senha pode falhar silenciosamente.
  services.xserver.xkb = {
    layout = inferredXkbLayout;
    variant = inferredXkbVariant;
  };
}
