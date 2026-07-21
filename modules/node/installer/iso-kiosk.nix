{
  lib,
  normalizeText,
  nodeKioskFallbackPage,
  nodeOpenboxAutostart,
  ...
}:

let
  # URLBlocklist/URLAllowlist use Chromium's URL filter syntax, not shell-like
  # globs. The v12 regression came from allowing only `.../*`, which still
  # leaves the origin root (`http://127.0.0.1:8000`) blocked.
  kioskUrlAllowlist = [
    "http://127.0.0.1:8000"
    "http://localhost:8000"
    "file://${nodeKioskFallbackPage}"
  ];
in

{
  services.xserver.enable = true;
  services.xserver.autorun = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.windowManager.openbox.enable = true;
  services.xserver.desktopManager.xterm.enable = false;

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "node";
  services.displayManager.defaultSession = "none+openbox";

  services.xserver.displayManager.lightdm.greeters.gtk.enable = true;
  services.xserver.displayManager.lightdm.extraConfig = normalizeText ''
    [Seat:*]
    greeter-hide-users=true
  '';

  services.xserver.serverFlagsSection = ''
    Option "DontVTSwitch" "True"
    Option "DontZap" "True"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
  '';

  environment.etc."xdg/openbox/rc.xml".text = normalizeText ''
    <?xml version="1.0" encoding="UTF-8"?>
    <openbox_config xmlns="http://openbox.org/3.4/rc">
      <focus>
        <focusNew>yes</focusNew>
        <followMouse>no</followMouse>
        <focusLast>yes</focusLast>
        <underMouse>no</underMouse>
      </focus>
      <theme>
        <name>Clearlooks</name>
        <titleLayout></titleLayout>
        <keepBorder>no</keepBorder>
        <animateIconify>no</animateIconify>
      </theme>
      <desktops>
        <number>1</number>
        <firstdesk>1</firstdesk>
        <popupTime>0</popupTime>
        <names>
          <name>NODE Installer</name>
        </names>
      </desktops>
      <resize>
        <drawContents>no</drawContents>
        <popupShow>Never</popupShow>
      </resize>
      <dock>
        <position>TopLeft</position>
        <floatingX>0</floatingX>
        <floatingY>0</floatingY>
        <noStrut>yes</noStrut>
        <stacking>Above</stacking>
        <direction>Vertical</direction>
        <autoHide>yes</autoHide>
        <hideDelay>0</hideDelay>
        <showDelay>999999</showDelay>
        <moveButton>None</moveButton>
      </dock>
      <keyboard>
      </keyboard>
      <mouse>
        <dragThreshold>999</dragThreshold>
        <doubleClickTime>500</doubleClickTime>
        <screenEdgeWarpTime>0</screenEdgeWarpTime>
        <screenEdgeWarpMouse>false</screenEdgeWarpMouse>
      </mouse>
      <applications>
        <application class="Chromium-browser">
          <decor>no</decor>
          <focus>yes</focus>
          <fullscreen>yes</fullscreen>
          <maximized>yes</maximized>
          <layer>above</layer>
          <desktop>all</desktop>
          <skip_taskbar>yes</skip_taskbar>
          <skip_pager>yes</skip_pager>
        </application>
        <application name="chromium">
          <decor>no</decor>
          <focus>yes</focus>
          <fullscreen>yes</fullscreen>
          <maximized>yes</maximized>
          <layer>above</layer>
          <desktop>all</desktop>
          <skip_taskbar>yes</skip_taskbar>
          <skip_pager>yes</skip_pager>
        </application>
        <application class="Yad">
          <decor>no</decor>
          <focus>yes</focus>
          <fullscreen>yes</fullscreen>
          <maximized>yes</maximized>
          <layer>above</layer>
          <desktop>all</desktop>
          <skip_taskbar>yes</skip_taskbar>
          <skip_pager>yes</skip_pager>
        </application>
      </applications>
    </openbox_config>
  '';

  environment.etc."xdg/openbox/autostart".source =
    "${nodeOpenboxAutostart}/bin/node-openbox-autostart";

  environment.etc."chromium/policies/managed/node-kiosk.json".text = builtins.toJSON {
    BrowserAddPersonEnabled = false;
    BrowserGuestModeEnabled = false;
    DeveloperToolsAvailability = 2;
    URLBlocklist = [ "*" ];
    URLAllowlist = kioskUrlAllowlist;
  };

  assertions = [
    {
      assertion = builtins.all (url: builtins.elem url kioskUrlAllowlist) [
        "http://127.0.0.1:8000"
        "http://localhost:8000"
      ];
      message = "Chromium kiosk policy must explicitly allow the installer origin root; using only .../* leaves http://127.0.0.1:8000 blocked.";
    }
    {
      assertion = builtins.all (
        url: !(lib.hasPrefix "http://" url || lib.hasPrefix "https://" url) || !lib.hasSuffix "/*" url
      ) kioskUrlAllowlist;
      message = "Chromium URLAllowlist entries must use filter syntax; avoid appending /* to kiosk origins because it does not unblock the root URL.";
    }
  ];

  systemd.services.display-manager.wants = [ "node-live-paths.service" ];
  systemd.services.display-manager.after = [ "node-live-paths.service" ];
}
