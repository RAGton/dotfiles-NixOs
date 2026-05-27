# =============================================================================
# Módulo NixOS: Branding do sistema (Kryonix)
# Autor: rag
#
# O que é
# - Um módulo *reutilizável* para “caracterizar” o NixOS como Kryonix.
# - Ajusta identidade do sistema em lugares padrão do Linux desktop:
#   - /etc/os-release (PRETTY_NAME, NAME, ID, VERSION_ID)
#   - /etc/issue (texto do console/login)
#
# Por quê
# - Mantém o rebranding *declarativo* e centralizado, sem “gambiarras” por host.
# - Evita espalhar strings (nome/versão) em vários arquivos.
#
# Como usar
# - Importe este módulo em um host (ex.: `hosts/inspiron/default.nix`) ou em um módulo comum.
# - Depois habilite:
#     kryonix.branding.enable = true;
#     kryonix.branding.versionId = "25.11"; # (se quiser espelhar o stateVersion)
#
# Nota importante sobre versões
# - `system.stateVersion` NÃO deve ser mudado só por branding.
# - `kryonix.branding.versionId` é apenas o que aparece em /etc/os-release.
# =============================================================================
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.branding;
  displayName = lib.concatStringsSep " " (
    lib.filter (part: part != "") [
      cfg.prettyName
      cfg.edition
    ]
  );
  kryonixWallpaper = ../../../../files/wallpaper/01.png;
  kryonixGdmWallpaper = ../../../../files/wallpaper/01.png;
  kryonixAvatar = ../../../../files/avatar/ragton.jpeg;
  grubSplash =
    pkgs.runCommand "kryonix-grub-splash.png"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        magick "${kryonixWallpaper}" \
          -resize 1920x1080^ \
          -gravity center \
          -extent 1920x1080 \
          -strip PNG32:"$out"
      '';
  plymouthTheme =
    pkgs.runCommand "kryonix-plymouth-theme"
      {
        nativeBuildInputs = [
          pkgs.imagemagick
          pkgs.coreutils
        ];
      }
      ''
        themeDir="$out/share/plymouth/themes/kryonix"
        imageDir="$themeDir/images"
        mkdir -p "$imageDir"

        magick "${kryonixWallpaper}" \
          -resize 1920x1080^ \
          -gravity center \
          -extent 1920x1080 \
          -blur 0x18 \
          -modulate 60,75,100 \
          -fill '#081018aa' \
          -colorize 45 \
          PNG32:"$imageDir/background.png"

        magick "${kryonixAvatar}" \
          -background none \
          -resize 120x120 \
          -gravity center \
          -extent 120x120 \
          PNG32:"$imageDir/logo.png"

        for i in $(seq 0 47); do
          frame="$(printf '%04d' "$((i + 1))")"

          if [ "$i" -le 23 ]; then
            pulse="$i"
          else
            pulse="$((47 - i))"
          fi

          size="$((100 + pulse))"
          glow_size="$((128 + pulse * 2))"
          glow_alpha="0.$((30 + pulse))"

          magick -size 176x176 xc:none \
            \( "$imageDir/logo.png" -resize "''${glow_size}x''${glow_size}" -alpha set -channel A -evaluate multiply "''${glow_alpha}" +channel -fill '#f0c78b' -colorize 100 -blur 0x18 \) \
            -gravity center -compose over -composite \
            \( "$imageDir/logo.png" -resize "''${size}x''${size}" \) \
            -gravity center -compose over -composite \
            PNG32:"$imageDir/throbber-''${frame}.png"
        done

        cat > "$themeDir/kryonix.plymouth" <<EOF
        [Plymouth Theme]
        Name=Kryonix
        Description=Tema de boot do Kryonix
        ModuleName=two-step

        [two-step]
        Font=Cantarell 20
        ImageDir=$imageDir
        BackgroundStartColor=0x081018
        BackgroundEndColor=0x081018
        ProgressBarBackgroundColor=0x1b2a36
        ProgressBarForegroundColor=0xf0c78b
        DialogHorizontalAlignment=.5
        DialogVerticalAlignment=.82
        HorizontalAlignment=.5
        VerticalAlignment=.72
        Transition=fade-over
        TransitionDuration=0.45
        MessageBelowAnimation=true
        UseEndAnimation=false

        [boot-up]
        UseEndAnimation=false
        UseFirmwareBackground=false

        [shutdown]
        UseEndAnimation=false
        UseFirmwareBackground=false

        [reboot]
        UseEndAnimation=false
        UseFirmwareBackground=false
        EOF
      '';
  # Conteúdo do /etc/os-release.
  # Usamos um conjunto pequeno e compatível (muitas ferramentas só precisam disso).
  osReleaseText = ''
    NAME="NixOS (Kryonix)"
    PRETTY_NAME=${lib.escapeShellArg displayName}
    ID=nixos
    ID_LIKE=nixos
    VERSION_ID=${lib.escapeShellArg cfg.versionId}
    LOGO=nix-snowflake
    HOME_URL="https://nixos.org/"
  '';
in
{
  imports = [
    (lib.mkAliasOptionModule [ "ragos" ] [ "kryonix" "branding" ])
  ];

  options.kryonix.branding = {
    enable = lib.mkEnableOption "Ativa branding do sistema como Kryonix";

    prettyName = lib.mkOption {
      type = lib.types.str;
      default = "Kryonix";
      description = "Nome amigável (PRETTY_NAME) exibido por ferramentas/GUI.";
    };

    edition = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Sufixo opcional da edição do sistema.
        Exemplo: `VE` para exibir `Kryonix VE`.
      '';
    };

    versionId = lib.mkOption {
      type = lib.types.str;
      default = "25.11";
      description = "Versão exibida (VERSION_ID) em /etc/os-release.";
    };

    issueText = lib.mkOption {
      type = lib.types.nullOr lib.types.lines;
      default = null;
      description = ''
        Texto para /etc/issue (login/TTY).

        Dica: suporta escapes do getty, como:
        - \r: release do kernel
        - \m: arquitetura
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Substitui o /etc/os-release padrão do NixOS.
    # Se não for mkForce, pode acontecer de ficar duplicado/mesclado.
    environment.etc."os-release".text = lib.mkForce osReleaseText;

    # Texto exibido em TTY/getty.
    environment.etc."issue".text =
      if cfg.issueText != null then
        cfg.issueText
      else
        ''
          ${displayName}
          Kernel: \r \m
          Host: \n
        '';

    programs.dconf.profiles.gdm.databases = [
      {
        settings = {
          "org/gnome/desktop/background" = {
            picture-uri = "file://${kryonixGdmWallpaper}";
            picture-uri-dark = "file://${kryonixGdmWallpaper}";
            picture-options = "zoom";
            primary-color = "#05070c";
            secondary-color = "#05070c";
            color-shading-type = "solid";
          };
          "org/gnome/desktop/screensaver" = {
            picture-uri = "file://${kryonixGdmWallpaper}";
            picture-uri-dark = "file://${kryonixGdmWallpaper}";
            picture-options = "zoom";
            primary-color = "#05070c";
            secondary-color = "#05070c";
            color-shading-type = "solid";
          };
        };
      }
    ];

    boot = {
      plymouth = {
        enable = true;
        theme = "kryonix";
        themePackages = [ plymouthTheme ];
      };

      loader.grub = {
        gfxmodeEfi = lib.mkDefault "1920x1080";
        gfxmodeBios = lib.mkDefault "1920x1080";
        extraConfig = lib.mkAfter ''
          set menu_color_normal=light-gray/black
          set menu_color_highlight=white/dark-gray
          set color_normal=light-gray/black
          set color_highlight=white/dark-gray
        '';
      };
    };
  };
}
