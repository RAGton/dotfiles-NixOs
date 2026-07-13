{
  pkgs,
  ragosBrandingAssets ? import ../../flake/branding-assets.nix,
}:
let
  version = "1.0.0";
  wallpaperSlideSources = map (path: "${path}") ragosBrandingAssets.plasma.slides;
  featuredWallpaperSource = "${ragosBrandingAssets.plasma.featuredSlide}";
  logoTerminalSource = "${ragosBrandingAssets.logoTerminal}";

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

  ragosPlasmaBranding =
    pkgs.runCommandLocal "ragos-plasma-branding-${version}"
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

        ${installTree ./look-and-feel/org.ragos.desktop.dark "$out/share/plasma/look-and-feel/org.ragos.desktop.dark"}
        ${installTree ./look-and-feel/org.ragos.desktop.light "$out/share/plasma/look-and-feel/org.ragos.desktop.light"}
        ${installTree ./plasma-style/ragos-dark "$out/share/plasma/desktoptheme/ragos-dark"}
        ${installTree ./plasma-style/ragos-light "$out/share/plasma/desktoptheme/ragos-light"}
        install -Dm0644 ${./colors/RAGOSDark.colors} "$out/share/color-schemes/RAGOSDark.colors"
        install -Dm0644 ${./colors/RAGOSLight.colors} "$out/share/color-schemes/RAGOSLight.colors"
        ${pkgs.imagemagick}/bin/magick \
          "${logoTerminalSource}" \
          -gravity north \
          -crop 620x620+0+120 \
          +repage \
          -resize 256x256 \
          "$out/share/icons/hicolor/256x256/apps/ragos-control.png"
        install -Dm0644 "$out/share/icons/hicolor/256x256/apps/ragos-control.png" "$out/share/pixmaps/ragos-control.png"

        ${renderWallpaperCollection {
          id = "org.ragos.wallpaper.dark";
          meta = ./wallpapers/org.ragos.wallpaper.dark/metadata.json;
          slides = wallpaperSlideSources;
          featuredSrc = featuredWallpaperSource;
        }}
        ${renderWallpaperCollection {
          id = "org.ragos.wallpaper.light";
          meta = ./wallpapers/org.ragos.wallpaper.light/metadata.json;
          slides = wallpaperSlideSources;
          featuredSrc = featuredWallpaperSource;
        }}

        ${renderLookAndFeelPreview {
          id = "org.ragos.desktop.dark";
          src = featuredWallpaperSource;
        }}
        ${renderLookAndFeelPreview {
          id = "org.ragos.desktop.light";
          src = featuredWallpaperSource;
        }}
      '';

  makeBundle =
    {
      relativePath,
      outputName,
    }:
    ''
      bundle_src="${ragosPlasmaBranding}/share/${relativePath}"
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

  ragosPlasmaKdeStoreBundles =
    pkgs.runCommandLocal "ragos-plasma-kde-store-bundles-${version}"
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
          relativePath = "plasma/look-and-feel/org.ragos.desktop.dark";
          outputName = "org.ragos.desktop.dark";
        }}
        ${makeBundle {
          relativePath = "plasma/look-and-feel/org.ragos.desktop.light";
          outputName = "org.ragos.desktop.light";
        }}
        ${makeBundle {
          relativePath = "plasma/desktoptheme/ragos-dark";
          outputName = "ragos-dark";
        }}
        ${makeBundle {
          relativePath = "plasma/desktoptheme/ragos-light";
          outputName = "ragos-light";
        }}
        ${makeBundle {
          relativePath = "wallpapers/org.ragos.wallpaper.dark";
          outputName = "org.ragos.wallpaper.dark";
        }}
        ${makeBundle {
          relativePath = "wallpapers/org.ragos.wallpaper.light";
          outputName = "org.ragos.wallpaper.light";
        }}
        install -Dm0644 ${./colors/RAGOSDark.colors} "$out/RAGOSDark.colors"
        install -Dm0644 ${./colors/RAGOSLight.colors} "$out/RAGOSLight.colors"
        (
          tmp_dir="$(mktemp -d)"
          cp ${./colors/RAGOSDark.colors} "$tmp_dir/RAGOSDark.colors"
          cp ${./colors/RAGOSLight.colors} "$tmp_dir/RAGOSLight.colors"
          ${pkgs.zip}/bin/zip -j "$out/RAGOSDark.colors.zip" "$tmp_dir/RAGOSDark.colors" >/dev/null
          ${pkgs.zip}/bin/zip -j "$out/RAGOSLight.colors.zip" "$tmp_dir/RAGOSLight.colors" >/dev/null
          rm -rf "$tmp_dir"
        )
      '';
in
{
  inherit ragosPlasmaBranding ragosPlasmaKdeStoreBundles;
}
