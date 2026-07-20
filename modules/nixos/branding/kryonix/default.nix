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
  options,
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
  kryonixWallpaper = ../../../../assets/wallpaper/01.png;
  kryonixGdmWallpaper = ../../../../assets/wallpaper/01.png;
  kryonixAvatar = ../../../../assets/avatar/ragton.jpeg;
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
        mkdir -p "$themeDir"

        magick "${kryonixWallpaper}" \
          -resize 1920x1080^ \
          -gravity center \
          -extent 1920x1080 \
          -blur 0x18 \
          -modulate 60,75,100 \
          -fill '#081018aa' \
          -colorize 45 \
          PNG32:"$themeDir/background.png"

        magick "${kryonixAvatar}" \
          -background none \
          -resize 120x120 \
          -gravity center \
          -extent 120x120 \
          PNG32:"$themeDir/logo.png"

        cat > "$themeDir/kryonix.plymouth" <<EOF
        [Plymouth Theme]
        Name=Kryonix
        Description=Tema animado de splash do Kryonix (Script Engine)
        ModuleName=script

        [script]
        ImageDir=$themeDir
        ScriptFile=$themeDir/kryonix.script
        EOF

        cat > "$themeDir/kryonix.script" <<'EOF'
        # ====== Configuracoes Base ======
        screen_width = Window.GetWidth();
        screen_height = Window.GetHeight();

        # ====== Assets ======
        bg_image = Image("background.png");
        logo_image = Image("logo.png");

        # ====== Background (Preserva aspecto e Fill) ======
        window_ratio = screen_width / screen_height;
        bg_ratio = bg_image.GetWidth() / bg_image.GetHeight();

        if (window_ratio > bg_ratio) {
            bg_scale = screen_width / bg_image.GetWidth();
        } else {
            bg_scale = screen_height / bg_image.GetHeight();
        }

        scaled_bg = bg_image.Scale(bg_image.GetWidth() * bg_scale, bg_image.GetHeight() * bg_scale);
        bg_sprite = Sprite(scaled_bg);
        bg_sprite.SetX(screen_width / 2 - bg_sprite.GetImage().GetWidth() / 2);
        bg_sprite.SetY(screen_height / 2 - bg_sprite.GetImage().GetHeight() / 2);
        bg_sprite.SetZ(-10);

        # ====== Logo ======
        logo_sprite = Sprite(logo_image);
        logo_sprite.SetX(screen_width / 2 - logo_image.GetWidth() / 2);
        logo_sprite.SetY(screen_height / 2 - logo_image.GetHeight() / 2);
        logo_sprite.SetZ(10);

        # ====== Animacao ======
        progress = 0;

        fun refresh_callback () {
            progress++;
            mod = progress % 100;
            
            # Pulso linear de fade in e fade out
            if (mod < 50) {
               op = (50 + mod) / 100.0;
            } else {
               op = (150 - mod) / 100.0;
            }
            logo_sprite.SetOpacity(op);
        }
        Plymouth.SetRefreshFunction(refresh_callback);

        # ====== Handlers de Sistema (LUKS, Quit) ======
        status = "normal";

        fun display_password_callback(prompt, bullets) {
            status = "password";
            logo_sprite.SetOpacity(0);
        }
        Plymouth.SetDisplayPasswordFunction(display_password_callback);

        fun display_normal_callback() {
            status = "normal";
        }
        Plymouth.SetDisplayNormalFunction(display_normal_callback);
        EOF
      '';
  grubTheme = pkgs.runCommand "kryonix-grub-theme" { } ''
    themeDir="$out/kryonix"
    mkdir -p "$themeDir"
    cp ${./../../../../assets/grub-theme/theme.txt} "$themeDir/theme.txt"
  '';

  blackPixel = pkgs.runCommand "black-pixel.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick -size 1x1 xc:"#081018" PNG32:$out
  '';

  # Conteúdo do /etc/os-release.
  # Usamos um conjunto pequeno e compatível (muitas ferramentas só precisam disso).
  # ID=nixos é mantido propositalmente: ferramentas de desktop e Nix tooling
  # detectam a distro por este campo. O branding visível vai em NAME/PRETTY_NAME.
  osReleaseText = ''
    NAME="KryonixOS"
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
    (lib.mkAliasOptionModule [ "node" ] [ "kryonix" "branding" ])
  ];

  options.kryonix.branding = {
    enable = lib.mkEnableOption "Ativa branding do sistema como Kryonix";

    prettyName = lib.mkOption {
      type = lib.types.str;
      default = "KryonixOS";
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

    motd = lib.mkOption {
      type = lib.types.nullOr lib.types.lines;
      default = null;
      description = ''
        Texto para /etc/motd (message of the day, exibido pós-login).

        Quando `null` e `enable = true`, é gerado automaticamente um motd
        curto no formato "Welcome to <displayName>" + dica do comando
        `kryonix --help`.

        Defina como string vazia (`""`) para suprimir o motd sem precisar
        desabilitar todo o módulo branding.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Substitui o /etc/os-release padrão do NixOS.
      # Se não for mkForce, pode acontecer de ficar duplicado/mesclado.
      environment.etc."os-release".text = lib.mkForce osReleaseText;

      # Texto exibido em TTY/getty.
      environment.etc."issue".text =
        if cfg.issueText != null then
          cfg.issueText
        else
          ''
            Welcome to ${displayName}
            Kernel: \r \m
            Host: \n
          '';

      # Mensagem do dia pós-login. Pequeno, sem dependência de rede.
      environment.etc."motd".text =
        if cfg.motd != null then
          cfg.motd
        else
          ''
            Welcome to ${displayName}.
            Run `kryonix --help` for system commands.
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
          splashImage = lib.mkForce null;
          theme = lib.mkForce "${grubTheme}/kryonix";
          splashMode = lib.mkDefault "stretch";
          backgroundColor = lib.mkDefault "#081018";
          gfxmodeEfi = lib.mkDefault "auto";
          gfxmodeBios = lib.mkDefault "auto";
          extraConfig = lib.mkAfter ''
            set color_normal=light-cyan/black
            set color_highlight=black/light-cyan
            set menu_color_normal=white/black
            set menu_color_highlight=black/cyan
          '';
        };
      };
    })
    (lib.mkIf cfg.enable (
      lib.optionalAttrs (options ? isoImage) {
        isoImage = {
          # grubTheme = lib.mkForce "${grubTheme}/kryonix"; # Quebra no Ventoy por falta de fontes
          splashImage = lib.mkForce blackPixel;
          efiSplashImage = lib.mkForce blackPixel;
        };
      }
    ))
  ];
}
