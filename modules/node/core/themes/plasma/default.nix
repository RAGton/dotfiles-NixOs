{
  pkgs,
  nodeBrandingAssets ? import ../../flake/branding-assets.nix,
}:
let
  version = "1.0.0";
  wallpaperSlideSources = map (path: "${path}") nodeBrandingAssets.plasma.slides;
  featuredWallpaperSource = "${nodeBrandingAssets.plasma.featuredSlide}";
  logoTerminalSource = "${nodeBrandingAssets.logoTerminal}";

  installTree = src: dest: ''
    mkdir -p "${dest}"
    cp -r --no-preserve=mode,ownership ${src}/. "${dest}/"
    find "${dest}" -type l -print -quit | grep -q . && {
      echo "symlink encontrado em ${dest}" >&2
      exit 1
    } || true
  '';

  renderWallpaperCollection =
    {
      id,
      meta,
      slides,
      featuredSrc,
    }:
    ''
          mkdir -p "$out/share/wallpapers/${id}/contents/images"
          mkdir -p "$out/share/wallpapers/${id}/contents/slides"
          install -Dm0644 "${featuredSrc}" "$out/share/wallpapers/${id}/contents/images/5120x2880.png"
          install -Dm0644 "${featuredSrc}" "$out/share/wallpapers/${id}/contents/screenshot.png"
          slide_index=0
          while IFS= read -r slide; do
            [[ -n "$slide" ]] || continue
            slide_index=$((slide_index + 1))
            padded_index="$(printf '%02d' "$slide_index")"
            install -Dm0644 "$slide" "$out/share/wallpapers/${id}/contents/slides/''${padded_index}.png"
          done <<'EOF'
      ${pkgs.lib.concatStringsSep "\n" slides}
      EOF
          install -Dm0644 ${meta} "$out/share/wallpapers/${id}/metadata.json"
    '';

  renderLookAndFeelPreview =
    {
      id,
      src,
    }:
    ''
      mkdir -p "$out/share/plasma/look-and-feel/${id}/contents/previews"
      ${pkgs.imagemagick}/bin/magick "${src}" \
        -resize 1920x1080^ \
        -gravity center \
        -extent 1920x1080 \
        "$out/share/plasma/look-and-feel/${id}/contents/previews/preview.png"
      ${pkgs.imagemagick}/bin/magick "$out/share/plasma/look-and-feel/${id}/contents/previews/preview.png" \
        -resize 1600x900 \
        -quality 92 \
        "$out/share/plasma/look-and-feel/${id}/contents/previews/fullscreenpreview.jpg"
    '';

  nodePlasmaBranding =
    pkgs.runCommandLocal "node-plasma-branding-${version}"
      {
        nativeBuildInputs = with pkgs; [
          coreutils
          findutils
          gnugrep
          imagemagick
        ];
      }
      ''
        mkdir -p "$out/share/plasma/look-and-feel"
        mkdir -p "$out/share/plasma/desktoptheme"
        mkdir -p "$out/share/color-schemes"
        mkdir -p "$out/share/wallpapers"
        mkdir -p "$out/share/icons/hicolor/256x256/apps"
        mkdir -p "$out/share/pixmaps"

        ${installTree ./look-and-feel/org.node.desktop.dark "$out/share/plasma/look-and-feel/org.node.desktop.dark"}
        ${installTree ./look-and-feel/org.node.desktop.light "$out/share/plasma/look-and-feel/org.node.desktop.light"}
        ${installTree ./plasma-style/node-dark "$out/share/plasma/desktoptheme/node-dark"}
        ${installTree ./plasma-style/node-light "$out/share/plasma/desktoptheme/node-light"}
        install -Dm0644 ${./colors/NODEDark.colors} "$out/share/color-schemes/NODEDark.colors"
        install -Dm0644 ${./colors/NODELight.colors} "$out/share/color-schemes/NODELight.colors"
        ${pkgs.imagemagick}/bin/magick \
          "${logoTerminalSource}" \
          -gravity north \
          -crop 620x620+0+120 \
          +repage \
          -resize 256x256 \
          "$out/share/icons/hicolor/256x256/apps/node-control.png"
        install -Dm0644 "$out/share/icons/hicolor/256x256/apps/node-control.png" "$out/share/pixmaps/node-control.png"

        ${renderWallpaperCollection {
          id = "org.node.wallpaper.dark";
          meta = ./wallpapers/org.node.wallpaper.dark/metadata.json;
          slides = wallpaperSlideSources;
          featuredSrc = featuredWallpaperSource;
        }}
        ${renderWallpaperCollection {
          id = "org.node.wallpaper.light";
          meta = ./wallpapers/org.node.wallpaper.light/metadata.json;
          slides = wallpaperSlideSources;
          featuredSrc = featuredWallpaperSource;
        }}

        ${renderLookAndFeelPreview {
          id = "org.node.desktop.dark";
          src = featuredWallpaperSource;
        }}
        ${renderLookAndFeelPreview {
          id = "org.node.desktop.light";
          src = featuredWallpaperSource;
        }}
      '';

  makeBundle =
    {
      relativePath,
      outputName,
    }:
    ''
      bundle_src="${nodePlasmaBranding}/share/${relativePath}"
      [[ -d "$bundle_src" ]] || {
        echo "bundle ausente: $bundle_src" >&2
        exit 1
      }
      tmp_dir="$(mktemp -d)"
      cp -r "$bundle_src" "$tmp_dir/${outputName}"
      chmod -R u+w "$tmp_dir/${outputName}"
      find "$tmp_dir/${outputName}" -type l -print -quit | grep -q . && {
        echo "symlink encontrado no bundle ${outputName}" >&2
        exit 1
      } || true
      (
        cd "$tmp_dir"
        ${pkgs.zip}/bin/zip -r "$out/${outputName}.zip" "${outputName}" >/dev/null
      )
      rm -rf "$tmp_dir"
    '';

  nodePlasmaKdeStoreBundles =
    pkgs.runCommandLocal "node-plasma-kde-store-bundles-${version}"
      {
        nativeBuildInputs = with pkgs; [
          coreutils
          findutils
          gnugrep
          zip
        ];
      }
      ''
        mkdir -p "$out"
        ${makeBundle {
          relativePath = "plasma/look-and-feel/org.node.desktop.dark";
          outputName = "org.node.desktop.dark";
        }}
        ${makeBundle {
          relativePath = "plasma/look-and-feel/org.node.desktop.light";
          outputName = "org.node.desktop.light";
        }}
        ${makeBundle {
          relativePath = "plasma/desktoptheme/node-dark";
          outputName = "node-dark";
        }}
        ${makeBundle {
          relativePath = "plasma/desktoptheme/node-light";
          outputName = "node-light";
        }}
        ${makeBundle {
          relativePath = "wallpapers/org.node.wallpaper.dark";
          outputName = "org.node.wallpaper.dark";
        }}
        ${makeBundle {
          relativePath = "wallpapers/org.node.wallpaper.light";
          outputName = "org.node.wallpaper.light";
        }}
        install -Dm0644 ${./colors/NODEDark.colors} "$out/NODEDark.colors"
        install -Dm0644 ${./colors/NODELight.colors} "$out/NODELight.colors"
        (
          tmp_dir="$(mktemp -d)"
          cp ${./colors/NODEDark.colors} "$tmp_dir/NODEDark.colors"
          cp ${./colors/NODELight.colors} "$tmp_dir/NODELight.colors"
          ${pkgs.zip}/bin/zip -j "$out/NODEDark.colors.zip" "$tmp_dir/NODEDark.colors" >/dev/null
          ${pkgs.zip}/bin/zip -j "$out/NODELight.colors.zip" "$tmp_dir/NODELight.colors" >/dev/null
          rm -rf "$tmp_dir"
        )
      '';
in
{
  inherit nodePlasmaBranding nodePlasmaKdeStoreBundles;
}
