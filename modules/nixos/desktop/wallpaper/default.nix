{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.desktop.wallpaper.dynamic;
  env = config.kryonix.desktop.environment;
  isKde = env == "kde";
  isHyprland = env == "hyprland";
  supportsEnv = isKde || isHyprland;
in
{
  options.kryonix.desktop.wallpaper.dynamic = {
    enable = lib.mkEnableOption "wallpapers dinamicos opt-in no Kryonix";

    engine = lib.mkOption {
      type = lib.types.enum [ "waywallen" ];
      default = "waywallen";
      description = ''
        Motor de wallpaper dinamico suportado declarativamente no momento.

        O pin atual do nixpkgs nao traz `waywallen`, entao o Kryonix empacota
        a release oficial binaria como pacote proprio opt-in.
      '';
    };

    steam.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Instala o Steam de forma opt-in para facilitar acesso a assets do
        Wallpaper Engine / Workshop. Nao altera o perfil gamer global.
      '';
    };

    wallpaperEngine.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Adiciona o plugin `open-wallpaper-engine` ao Waywallen.

        Isso habilita o caminho de scene/web wallpapers. Sem esse opt-in, o
        pacote base fica limitado aos plugins image/video/wallhaven.
      '';
    };

    defaultWallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Wallpaper local do Kryonix exposto ao usuario como fallback/importacao
        rapida no Waywallen. `null` usa o oficial `kryonix-clean-dark.svg`.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = supportsEnv;
            message = ''
              kryonix.desktop.wallpaper.dynamic.enable requer
              kryonix.desktop.environment = "kde" ou "hyprland".
            '';
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
