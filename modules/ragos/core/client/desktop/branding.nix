{
  pkgs,
  ragosBrandingAssets ? import ../../flake/branding-assets.nix,
  ...
}:

let
  plasmaBrandingPackages = pkgs.callPackage ../../themes/plasma {
    inherit ragosBrandingAssets;
  };
  plasmaBranding = plasmaBrandingPackages.ragosPlasmaBranding;
  defaultVariant = "dark";
  desktopPolicyVersion = "2026-04-09.desktop-policy-v4";

  setPreferredVariant = pkgs.writeShellApplication {
    name = "ragos-plasma-set-preferred-variant";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      set -euo pipefail

      variant="''${1:-}"
      [[ -n "$variant" ]] || {
        printf 'uso: ragos-plasma-set-preferred-variant <dark|light>\n' >&2
        exit 2
      }

      case "$variant" in
        dark|light) ;;
        *)
          printf 'variante invalida: %s\n' "$variant" >&2
          exit 2
          ;;
      esac

      mkdir -p "$HOME/.config/ragos"
      printf '%s\n' "$variant" > "$HOME/.config/ragos/plasma-variant"
      rm -f \
        "$HOME/.config/ragos/plasma-applied-variant" \
        "$HOME/.config/ragos/plasma-applied-policy-version" \
        "$HOME/.config/ragos/plasma-proof.env"
      printf 'preferred_variant=%s\n' "$variant"
    '';
  };

  applyVariant = pkgs.writeShellApplication {
    name = "ragos-plasma-apply-variant";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      gnused
      systemd
      kdePackages.plasma-workspace
    ];
    text = ''
            set -euo pipefail

            read_kconfig_value() {
              local file="$1"
              local group="$2"
              local key="$3"
              [[ -f "$file" ]] || return 0
              awk -F= -v group="$group" -v key="$key" '
                $0 == "[" group "]" { in_group = 1; next }
                /^\[/ { in_group = 0 }
                in_group && $1 == key {
                  print substr($0, index($0, "=") + 1)
                  exit
                }
              ' "$file"
            }

            apply_wallpaper_slideshow() {
              local slide_dir="$1"
              local featured_wallpaper="$2"
              local slide_interval="$3"
              local script

              script="$(cat <<EOF
      var slideDir = "file://$slide_dir";
      var featured = "file://$featured_wallpaper";
      var desktopsArray = desktops();
      for (var i = 0; i < desktopsArray.length; i++) {
        var desktop = desktopsArray[i];
        desktop.wallpaperPlugin = "org.kde.slideshow";
        desktop.currentConfigGroup = ["Wallpaper", "org.kde.slideshow", "General"];
        desktop.writeConfig("Image", featured);
        desktop.writeConfig("SlidePaths", [slideDir]);
        desktop.writeConfig("SlideInterval", $slide_interval);
        desktop.writeConfig("SlideshowMode", 0);
        desktop.writeConfig("FillMode", 2);
        desktop.reloadConfig();
      }
      EOF
      )"

              for _ in $(seq 1 25); do
                if busctl --user list 2>/dev/null | grep -Fq org.kde.plasmashell; then
                  if busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "$script" >/dev/null 2>&1; then
                    return 0
                  fi
                fi
                sleep 1
              done

              ${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-wallpaperimage "$featured_wallpaper"
            }

            variant="''${1:-}"
            reset_layout="false"
            if [[ "''${2:-}" == "--reset-layout" ]]; then
              reset_layout="true"
            fi

            if [[ -z "$variant" && -f "$HOME/.config/ragos/plasma-variant" ]]; then
              variant="$(tr -d '[:space:]' < "$HOME/.config/ragos/plasma-variant")"
            fi
            if [[ -z "$variant" && -f /etc/xdg/ragos/plasma-default-variant ]]; then
              variant="$(tr -d '[:space:]' < /etc/xdg/ragos/plasma-default-variant)"
            fi

            variant="''${variant:-${defaultVariant}}"
            case "$variant" in
              dark)
                look_and_feel="org.ragos.desktop.dark"
                desktop_theme="ragos-dark"
                color_scheme="RAGOSDark"
                wallpaper="${plasmaBranding}/share/wallpapers/org.ragos.wallpaper.dark/contents/slides/01.png"
                wallpaper_slide_dir="${plasmaBranding}/share/wallpapers/org.ragos.wallpaper.dark/contents/slides"
                ;;
              light)
                look_and_feel="org.ragos.desktop.light"
                desktop_theme="ragos-light"
                color_scheme="RAGOSLight"
                wallpaper="${plasmaBranding}/share/wallpapers/org.ragos.wallpaper.light/contents/slides/01.png"
                wallpaper_slide_dir="${plasmaBranding}/share/wallpapers/org.ragos.wallpaper.light/contents/slides"
                ;;
              *)
                printf 'variante invalida: %s\n' "$variant" >&2
                exit 2
                ;;
            esac
            policy_version="${desktopPolicyVersion}"

            mkdir -p "$HOME/.config/ragos" "$HOME/.local/state/ragos"
            printf '%s\n' "$variant" > "$HOME/.config/ragos/plasma-variant"

            if [[ "$reset_layout" == "true" ]]; then
              ${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-lookandfeel --apply "$look_and_feel" --resetLayout
            else
              ${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-lookandfeel --apply "$look_and_feel"
            fi

            ${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-desktoptheme "$desktop_theme"
            ${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-colorscheme "$color_scheme"
            apply_wallpaper_slideshow "$wallpaper_slide_dir" "$wallpaper" 1200

            active_look_and_feel="$(read_kconfig_value "$HOME/.config/kdeglobals" "KDE" "LookAndFeelPackage")"
            active_color_scheme="$(read_kconfig_value "$HOME/.config/kdeglobals" "General" "ColorScheme")"
            active_desktop_theme="$(read_kconfig_value "$HOME/.config/plasmarc" "Theme" "name")"

            cat > "$HOME/.config/ragos/plasma-proof.env" <<EOF
      REQUESTED_VARIANT=$variant
      REQUESTED_LOOK_AND_FEEL=$look_and_feel
      REQUESTED_DESKTOP_THEME=$desktop_theme
      REQUESTED_COLOR_SCHEME=$color_scheme
      REQUESTED_WALLPAPER=$wallpaper
      REQUESTED_WALLPAPER_DIR=$wallpaper_slide_dir
      REQUESTED_WALLPAPER_MODE=slideshow
      REQUESTED_POLICY_VERSION=$policy_version
      ACTIVE_LOOK_AND_FEEL=''${active_look_and_feel:-$look_and_feel}
      ACTIVE_DESKTOP_THEME=''${active_desktop_theme:-$desktop_theme}
      ACTIVE_COLOR_SCHEME=''${active_color_scheme:-$color_scheme}
      APPLIED_POLICY_VERSION=$policy_version
      APPLIED_AT=$(date --iso-8601=seconds)
      EOF

            printf '%s\n' "$variant" > "$HOME/.config/ragos/plasma-applied-variant"
            printf '%s\n' "$policy_version" > "$HOME/.config/ragos/plasma-applied-policy-version"
            printf 'applied_variant=%s\n' "$variant"
    '';
  };

  reportVariant = pkgs.writeShellApplication {
    name = "ragos-plasma-report";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
    ];
    text = ''
      set -euo pipefail

      read_kconfig_value() {
        local file="$1"
        local group="$2"
        local key="$3"
        [[ -f "$file" ]] || return 0
        awk -F= -v group="$group" -v key="$key" '
          $0 == "[" group "]" { in_group = 1; next }
          /^\[/ { in_group = 0 }
          in_group && $1 == key {
            print substr($0, index($0, "=") + 1)
            exit
          }
        ' "$file"
      }

      desired_variant=""
      applied_variant=""
      desired_policy_version="unknown"
      applied_policy_version="unknown"
      active_look_and_feel=""
      active_color_scheme=""
      active_desktop_theme=""
      [[ -f "$HOME/.config/ragos/plasma-variant" ]] && desired_variant="$(tr -d '[:space:]' < "$HOME/.config/ragos/plasma-variant")"
      [[ -f "$HOME/.config/ragos/plasma-applied-variant" ]] && applied_variant="$(tr -d '[:space:]' < "$HOME/.config/ragos/plasma-applied-variant")"
      [[ -f /etc/xdg/ragos/plasma-policy-version ]] && desired_policy_version="$(tr -d '[:space:]' < /etc/xdg/ragos/plasma-policy-version)"
      [[ -f "$HOME/.config/ragos/plasma-applied-policy-version" ]] && applied_policy_version="$(tr -d '[:space:]' < "$HOME/.config/ragos/plasma-applied-policy-version")"
      active_look_and_feel="$(read_kconfig_value "$HOME/.config/kdeglobals" "KDE" "LookAndFeelPackage")"
      active_color_scheme="$(read_kconfig_value "$HOME/.config/kdeglobals" "General" "ColorScheme")"
      active_desktop_theme="$(read_kconfig_value "$HOME/.config/plasmarc" "Theme" "name")"

      printf 'desired_variant=%s\n' "''${desired_variant:-unknown}"
      printf 'applied_variant=%s\n' "''${applied_variant:-unknown}"
      printf 'desired_policy_version=%s\n' "''${desired_policy_version:-unknown}"
      printf 'applied_policy_version=%s\n' "''${applied_policy_version:-unknown}"
      printf 'active_look_and_feel=%s\n' "''${active_look_and_feel:-unknown}"
      printf 'active_color_scheme=%s\n' "''${active_color_scheme:-unknown}"
      printf 'active_desktop_theme=%s\n' "''${active_desktop_theme:-unknown}"

      if [[ -f "$HOME/.config/ragos/plasma-proof.env" ]]; then
        echo 'proof_file=present'
        cat "$HOME/.config/ragos/plasma-proof.env"
      else
        echo 'proof_file=missing'
      fi
    '';
  };

  brandingInit = pkgs.writeShellApplication {
    name = "ragos-plasma-branding-init";
    runtimeInputs = with pkgs; [
      coreutils
      applyVariant
    ];
    text = ''
      set -euo pipefail

      if [[ "''${XDG_CURRENT_DESKTOP:-}" != *KDE* && "''${DESKTOP_SESSION:-}" != *plasma* ]]; then
        exit 0
      fi

      mkdir -p "$HOME/.config/ragos"

      desired_variant="${defaultVariant}"
      desired_policy_version="${desktopPolicyVersion}"
      if [[ -f /etc/xdg/ragos/plasma-default-variant ]]; then
        desired_variant="$(tr -d '[:space:]' < /etc/xdg/ragos/plasma-default-variant)"
      fi
      if [[ -f /etc/xdg/ragos/plasma-policy-version ]]; then
        desired_policy_version="$(tr -d '[:space:]' < /etc/xdg/ragos/plasma-policy-version)"
      fi
      if [[ -f "$HOME/.config/ragos/plasma-variant" ]]; then
        desired_variant="$(tr -d '[:space:]' < "$HOME/.config/ragos/plasma-variant")"
      fi

      applied_variant=""
      applied_policy_version=""
      [[ -f "$HOME/.config/ragos/plasma-applied-variant" ]] && applied_variant="$(tr -d '[:space:]' < "$HOME/.config/ragos/plasma-applied-variant")"
      [[ -f "$HOME/.config/ragos/plasma-applied-policy-version" ]] && applied_policy_version="$(tr -d '[:space:]' < "$HOME/.config/ragos/plasma-applied-policy-version")"

      if [[ "$desired_variant" != "$applied_variant" \
         || "$desired_policy_version" != "$applied_policy_version" \
         || ! -f "$HOME/.config/ragos/plasma-proof.env" ]]; then
        sleep 3
        if [[ -z "$applied_variant" || "$desired_policy_version" != "$applied_policy_version" ]]; then
          ${applyVariant}/bin/ragos-plasma-apply-variant "$desired_variant" --reset-layout
        else
          ${applyVariant}/bin/ragos-plasma-apply-variant "$desired_variant"
        fi
      fi
    '';
  };
in
{
  environment.systemPackages = [
    plasmaBranding
    setPreferredVariant
    applyVariant
    reportVariant
    brandingInit
  ];

  environment.etc."xdg/ragos/plasma-default-variant".text = "${defaultVariant}\n";
  environment.etc."xdg/ragos/plasma-policy-version".text = "${desktopPolicyVersion}\n";

  environment.etc."xdg/autostart/ragos-branding.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=RAGOS Branding Init
    Exec=${brandingInit}/bin/ragos-plasma-branding-init
    X-KDE-autostart-phase=1
    OnlyShowIn=KDE;
    NoDisplay=true
  '';
}
