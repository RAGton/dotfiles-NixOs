{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.desktop.wallpaper.animated;
  env = config.kryonix.desktop.environment;
  isKde = env == "kde";
  isHyprland = env == "hyprland";
  supportsEnv = isKde || isHyprland;
in
{
  options.kryonix.desktop.wallpaper.animated = {
    enable = lib.mkEnableOption "wallpapers animados opt-in no Kryonix";

    backend = lib.mkOption {
      type = lib.types.enum [ "waywallen" ];
      default = "waywallen";
      description = "Backend declarativo de renderização de wallpaper animado.";
    };

    path = lib.mkOption {
      type = lib.types.path;
      default = ../../../../desktop/wallpapers/animated/kryonix-test-loop.mp4;
      description = "Caminho absoluto do arquivo MP4/WebM do wallpaper animado.";
    };

    fpsLimit = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Limite de FPS para poupar CPU/GPU (recomendado 30).";
    };

    muted = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Muta o áudio do vídeo para não atrapalhar o sistema.";
    };

    pauseOnBattery = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Pausa a animação automaticamente ao desconectar da tomada.";
    };

    fallback = lib.mkOption {
      type = lib.types.path;
      default = ../../../../desktop/branding/kryonix/assets/kryonix-clean-dark.svg;
      description = "Imagem estática de fallback caso o vídeo falhe ou engine caia.";
    };

    # Legacy steam integration if needed by backend (e.g., Wallpaper Engine)
    steam.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Instala o Steam de forma opt-in para assets de Wallpaper Engine.";
    };

    wallpaperEngine.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Adiciona suporte ao open-wallpaper-engine no backend.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = supportsEnv;
            message = "kryonix.desktop.wallpaper.animated.enable requer kryonix.desktop.environment = 'kde' ou 'hyprland'.";
          }
        ];

        environment.systemPackages = [
          pkgs.kryonix-waywallen
        ]
        ++ lib.optional isKde pkgs.kryonix-waywallen-display-kde
        ++ lib.optional cfg.wallpaperEngine.enable pkgs.kryonix-open-wallpaper-engine;
      }

      (lib.mkIf cfg.steam.enable {
        programs.steam.enable = lib.mkDefault true;
        hardware.graphics.enable = lib.mkDefault true;
        hardware.graphics.enable32Bit = lib.mkDefault true;
      })
    ]
  );
}
