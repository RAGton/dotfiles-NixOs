{
  config,
  pkgs,
  lib,
  ...
}:

{
  options.node.desktop.allowXWayland = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Permite XWayland no Plasma para compatibilidade com apps X11 legados.";
  };

  config = {
    ####################################################################
    # DISPLAY MANAGER — SDDM
    # O greeter Wayland com KWin estava falhando no KVM/libvirt com erros
    # de DRM/atomic modeset e causando flicker/retorno ao login. Mantemos a
    # sessao do usuario em Plasma (Wayland), mas estabilizamos o greeter em X11.
    ####################################################################
    services.xserver.enable = true;

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = false;
    };

    services.displayManager.defaultSession = lib.mkDefault "plasma";

    ####################################################################
    # DESKTOP — KDE PLASMA 6
    ####################################################################
    services.desktopManager.plasma6.enable = true;

    ####################################################################
    # WAYLAND PARA APPS DE USUARIO
    # Evitamos exportar XDG_SESSION_TYPE/QT_QPA_PLATFORM globalmente, porque
    # isso rotulava TTYs como "wayland" e vazava para o SDDM/greeter.
    ####################################################################
    environment.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
    };

    ####################################################################
    # SUPERFICIE OPERACIONAL MINIMA
    # O cliente publicado nao deve expor onboarding nem fluxo de app store
    # local. Tambem removemos XWayland quando ele nao for permitido.
    ####################################################################
    environment.plasma6.excludePackages =
      (with pkgs.kdePackages; [
        discover
        plasma-welcome
      ])
      ++ lib.optionals (!config.node.desktop.allowXWayland) [
        pkgs.xwayland
      ];
  };
}
