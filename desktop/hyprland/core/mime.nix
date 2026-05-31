# =============================================================================
# core/mime.nix — Associações MIME padrão do desktop
# =============================================================================
{ lib, config, pkgs, ... }:
{
  config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        # Diretórios e imagens
        "inode/directory"    = [ "org.kde.dolphin.desktop" ];
        "image/jpeg"         = [ "org.kde.gwenview.desktop" ];
        "image/jpg"          = [ "org.kde.gwenview.desktop" ];
        "image/png"          = [ "org.kde.gwenview.desktop" ];
        "image/x-png"        = [ "org.kde.gwenview.desktop" ];
        "image/gif"          = [ "org.kde.gwenview.desktop" ];
        "image/webp"         = [ "org.kde.gwenview.desktop" ];
        "image/bmp"          = [ "org.kde.gwenview.desktop" ];
        "image/tiff"         = [ "org.kde.gwenview.desktop" ];
        "image/heic"         = [ "org.kde.gwenview.desktop" ];
        "image/avif"         = [ "org.kde.gwenview.desktop" ];
        "image/svg+xml"      = [ "org.gimp.GIMP.desktop" "org.kde.gwenview.desktop" ];

        # Vídeo
        "video/mp4"          = [ "mpv.desktop" ];
        "video/x-matroska"   = [ "mpv.desktop" ];
        "video/webm"         = [ "mpv.desktop" ];
        "video/avi"          = [ "mpv.desktop" ];
        "video/quicktime"    = [ "mpv.desktop" ];
        "video/x-msvideo"    = [ "mpv.desktop" ];
        "video/mpeg"         = [ "mpv.desktop" ];
        "video/ogg"          = [ "mpv.desktop" ];
        "video/flv"          = [ "mpv.desktop" ];
        "video/x-flv"        = [ "mpv.desktop" ];
        "video/mp2t"         = [ "mpv.desktop" ];
        "video/3gpp"         = [ "mpv.desktop" ];
        "video/3gpp2"        = [ "mpv.desktop" ];

        # Áudio
        "audio/mpeg"         = [ "mpv.desktop" ];
        "audio/mp3"          = [ "mpv.desktop" ];
        "audio/flac"         = [ "mpv.desktop" ];
        "audio/ogg"          = [ "mpv.desktop" ];
        "audio/x-vorbis+ogg" = [ "mpv.desktop" ];
        "audio/wav"          = [ "mpv.desktop" ];
        "audio/x-wav"        = [ "mpv.desktop" ];
        "audio/aac"          = [ "mpv.desktop" ];
        "audio/opus"         = [ "mpv.desktop" ];
        "audio/mp4"          = [ "mpv.desktop" ];
        "audio/x-m4a"        = [ "mpv.desktop" ];
        "audio/webm"         = [ "mpv.desktop" ];

        # PDF e documentos
        "application/pdf"            = [ "org.kde.okular.desktop" ];
        "application/epub+zip"       = [ "org.kde.okular.desktop" ];
        "application/postscript"     = [ "org.kde.okular.desktop" ];
        "image/x-eps"                = [ "org.kde.okular.desktop" ];

        # Texto e código
        "text/plain"                 = [ "org.kde.kate.desktop" ];
        "text/markdown"              = [ "org.kde.kate.desktop" ];
        "text/x-python"              = [ "org.kde.kate.desktop" ];
        "text/x-shellscript"         = [ "org.kde.kate.desktop" ];
        "text/x-script.python"       = [ "org.kde.kate.desktop" ];
        "text/css"                   = [ "org.kde.kate.desktop" ];
        "text/html"                  = [ "app.zen_browser.zen.desktop" ];
        "text/xml"                   = [ "org.kde.kate.desktop" ];
        "text/x-lua"                 = [ "org.kde.kate.desktop" ];
        "application/json"           = [ "org.kde.kate.desktop" ];
        "application/xml"            = [ "org.kde.kate.desktop" ];
        "application/javascript"     = [ "org.kde.kate.desktop" ];

        # Web
        "x-scheme-handler/http"           = [ "app.zen_browser.zen.desktop" ];
        "x-scheme-handler/https"          = [ "app.zen_browser.zen.desktop" ];
        "x-scheme-handler/ftp"            = [ "app.zen_browser.zen.desktop" ];
        "x-scheme-handler/chrome"         = [ "app.zen_browser.zen.desktop" ];
        "x-scheme-handler/mailto"         = [ "app.zen_browser.zen.desktop" ];
        "application/xhtml+xml"           = [ "app.zen_browser.zen.desktop" ];
        "application/x-extension-htm"     = [ "app.zen_browser.zen.desktop" ];
        "application/x-extension-html"    = [ "app.zen_browser.zen.desktop" ];
        "application/x-extension-xhtml"   = [ "app.zen_browser.zen.desktop" ];
        "application/x-extension-xht"     = [ "app.zen_browser.zen.desktop" ];

        # Compactados
        "application/zip"                       = [ "org.kde.ark.desktop" ];
        "application/x-tar"                     = [ "org.kde.ark.desktop" ];
        "application/gzip"                      = [ "org.kde.ark.desktop" ];
        "application/x-gzip"                    = [ "org.kde.ark.desktop" ];
        "application/x-bzip2"                   = [ "org.kde.ark.desktop" ];
        "application/x-xz"                      = [ "org.kde.ark.desktop" ];
        "application/x-7z-compressed"           = [ "org.kde.ark.desktop" ];
        "application/x-rar"                     = [ "org.kde.ark.desktop" ];
        "application/x-rar-compressed"          = [ "org.kde.ark.desktop" ];
        "application/vnd.rar"                   = [ "org.kde.ark.desktop" ];
        "application/zstd"                      = [ "org.kde.ark.desktop" ];
        "application/x-compressed-tar"          = [ "org.kde.ark.desktop" ];
        "application/x-bzip-compressed-tar"     = [ "org.kde.ark.desktop" ];
        "application/x-xz-compressed-tar"       = [ "org.kde.ark.desktop" ];
        "application/x-zstd-compressed-tar"     = [ "org.kde.ark.desktop" ];

        # Office
        "application/vnd.oasis.opendocument.text"         = [ "writer.desktop" ];
        "application/vnd.oasis.opendocument.spreadsheet"  = [ "calc.desktop" ];
        "application/vnd.oasis.opendocument.presentation" = [ "impress.desktop" ];
        "application/msword"                              = [ "writer.desktop" ];
        "application/vnd.ms-excel"                        = [ "calc.desktop" ];
        "application/vnd.ms-powerpoint"                   = [ "impress.desktop" ];
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"   = [ "writer.desktop" ];
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"         = [ "calc.desktop" ];
        "application/vnd.openxmlformats-officedocument.presentationml.presentation" = [ "impress.desktop" ];
      };
    };

    # Problema: kate.desktop do nixpkgs declara apenas MimeType=text/plain;inode/directory;
    # Dolphin não encontra nenhum app para text/markdown e exibe o diálogo vazio.
    # Solução: override local que adiciona text/markdown ao MimeType de kate, rebuild do índice
    # e garante que ~/.local/share/applications/mimeapps.list (preferido pelo KDE) tenha a entrada.
    home.activation.fixMarkdownMimeKde = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      LOCAL_APPS="${config.xdg.dataHome}/applications"
      mkdir -p "$LOCAL_APPS"

      SYSTEM_KATE="/run/current-system/sw/share/applications/org.kde.kate.desktop"
      LOCAL_KATE="$LOCAL_APPS/org.kde.kate.desktop"

      # Patch kate.desktop: adiciona text/markdown;text/x-markdown; no MimeType
      if [ -f "$SYSTEM_KATE" ]; then
        ${pkgs.gnused}/bin/sed \
          's|^MimeType=text/plain;|MimeType=text/plain;text/markdown;text/x-markdown;|' \
          "$SYSTEM_KATE" > "$LOCAL_KATE"
      fi

      # Garante as entradas no mimeapps.list da localização KDE (precedência sobre ~/.config/)
      LOCAL_MIME="$LOCAL_APPS/mimeapps.list"
      # Remove entradas markdown antigas para evitar duplicatas
      ${pkgs.gnused}/bin/sed -i '/^text\/.*markdown/Id' "$LOCAL_MIME" 2>/dev/null || true
      # Cria [Default Applications] se não existir
      if ! ${pkgs.gnugrep}/bin/grep -q '^\[Default Applications\]' "$LOCAL_MIME" 2>/dev/null; then
        printf '[Default Applications]\n' >> "$LOCAL_MIME"
      fi
      # Insere as associações logo após [Default Applications]
      ${pkgs.gnused}/bin/sed -i \
        '/^\[Default Applications\]/a text\/markdown=org.kde.kate.desktop\ntext\/x-markdown=org.kde.kate.desktop' \
        "$LOCAL_MIME"

      # Reconstrói o índice de apps da pasta do usuário
      ${pkgs.desktop-file-utils}/bin/update-desktop-database "$LOCAL_APPS" 2>/dev/null || true
    '';
  };
}
