# =============================================================================
# core/mime.nix — Associações MIME padrão do desktop
#
# Padrão escalável: variáveis de app no let-block permitem trocar
# um app em um único lugar e propagar para todos os tipos MIME.
# =============================================================================
{ lib, config, pkgs, ... }:
let
  # ===========================================================================
  # Apps padrão — altere aqui para mudar a associação de toda uma categoria
  # ===========================================================================
  browser      = "app.zen_browser.zen.desktop";
  editor       = "org.kde.kate.desktop";
  imageViewer  = "org.kde.gwenview.desktop";
  videoPlayer  = "mpv.desktop";
  audioPlayer  = "mpv.desktop";
  pdfViewer    = "org.kde.okular.desktop";
  fileManager  = "org.kde.dolphin.desktop";
  archiver     = "org.kde.ark.desktop";
  imageEditor  = "org.gimp.GIMP.desktop";

  # Office (LibreOffice)
  docEditor    = "writer.desktop";
  spreadsheet  = "calc.desktop";
  presentation = "impress.desktop";

  # kate-markdown.desktop: exceção necessária porque kate.desktop do nixpkgs
  # não declara text/markdown no MimeType — a variável aponta para o entry
  # declarado em xdg.desktopEntries abaixo.
  markdownEditor = "kate-markdown.desktop";
in
{
  config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {

    # kservice fornece kbuildsycoca6 (rebuild do cache KDE após switch)
    home.packages = [ pkgs.kdePackages.kservice ];

    # Menu de aplicativos Plasma — extraído via runCommand para não puxar
    # o plasma-workspace inteiro (~800 MiB) como dependência do perfil HM.
    xdg.configFile."menus/applications.menu".source =
      pkgs.runCommand "plasma-menu" { } ''
        cp ${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu $out
      '';

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        # Diretórios
        "inode/directory"    = [ fileManager ];

        # Imagens raster
        "image/jpeg"         = [ imageViewer ];
        "image/jpg"          = [ imageViewer ];
        "image/png"          = [ imageViewer ];
        "image/x-png"        = [ imageViewer ];
        "image/gif"          = [ imageViewer ];
        "image/webp"         = [ imageViewer ];
        "image/bmp"          = [ imageViewer ];
        "image/tiff"         = [ imageViewer ];
        "image/heic"         = [ imageViewer ];
        "image/avif"         = [ imageViewer ];
        "image/svg+xml"      = [ imageEditor imageViewer ];

        # Vídeo
        "video/mp4"          = [ videoPlayer ];
        "video/x-matroska"   = [ videoPlayer ];
        "video/webm"         = [ videoPlayer ];
        "video/avi"          = [ videoPlayer ];
        "video/quicktime"    = [ videoPlayer ];
        "video/x-msvideo"    = [ videoPlayer ];
        "video/mpeg"         = [ videoPlayer ];
        "video/ogg"          = [ videoPlayer ];
        "video/flv"          = [ videoPlayer ];
        "video/x-flv"        = [ videoPlayer ];
        "video/mp2t"         = [ videoPlayer ];
        "video/3gpp"         = [ videoPlayer ];
        "video/3gpp2"        = [ videoPlayer ];

        # Áudio
        "audio/mpeg"         = [ audioPlayer ];
        "audio/mp3"          = [ audioPlayer ];
        "audio/flac"         = [ audioPlayer ];
        "audio/ogg"          = [ audioPlayer ];
        "audio/x-vorbis+ogg" = [ audioPlayer ];
        "audio/wav"          = [ audioPlayer ];
        "audio/x-wav"        = [ audioPlayer ];
        "audio/aac"          = [ audioPlayer ];
        "audio/opus"         = [ audioPlayer ];
        "audio/mp4"          = [ audioPlayer ];
        "audio/x-m4a"        = [ audioPlayer ];
        "audio/webm"         = [ audioPlayer ];

        # PDF e documentos
        "application/pdf"        = [ pdfViewer ];
        "application/epub+zip"   = [ pdfViewer ];
        "application/postscript" = [ pdfViewer ];
        "image/x-eps"            = [ pdfViewer ];

        # Texto e código
        "text/plain"             = [ editor ];
        "text/markdown"          = [ markdownEditor ];
        "text/x-markdown"        = [ markdownEditor ];
        "text/x-python"          = [ editor ];
        "text/x-shellscript"     = [ editor ];
        "text/x-script.python"   = [ editor ];
        "text/css"               = [ editor ];
        "text/html"              = [ browser ];
        "text/xml"               = [ editor ];
        "text/x-lua"             = [ editor ];
        "application/json"       = [ editor ];
        "application/xml"        = [ editor ];
        "application/javascript" = [ editor ];

        # Web e handlers de scheme
        "x-scheme-handler/http"           = [ browser ];
        "x-scheme-handler/https"          = [ browser ];
        "x-scheme-handler/ftp"            = [ browser ];
        "x-scheme-handler/chrome"         = [ browser ];
        "x-scheme-handler/mailto"         = [ browser ];
        "application/xhtml+xml"           = [ browser ];
        "application/x-extension-htm"     = [ browser ];
        "application/x-extension-html"    = [ browser ];
        "application/x-extension-xhtml"   = [ browser ];
        "application/x-extension-xht"     = [ browser ];

        # Compactados
        "application/zip"                    = [ archiver ];
        "application/x-tar"                  = [ archiver ];
        "application/gzip"                   = [ archiver ];
        "application/x-gzip"                 = [ archiver ];
        "application/x-bzip2"                = [ archiver ];
        "application/x-xz"                   = [ archiver ];
        "application/x-7z-compressed"        = [ archiver ];
        "application/x-rar"                  = [ archiver ];
        "application/x-rar-compressed"       = [ archiver ];
        "application/vnd.rar"                = [ archiver ];
        "application/zstd"                   = [ archiver ];
        "application/x-compressed-tar"       = [ archiver ];
        "application/x-bzip-compressed-tar"  = [ archiver ];
        "application/x-xz-compressed-tar"    = [ archiver ];
        "application/x-zstd-compressed-tar"  = [ archiver ];

        # Office
        "application/vnd.oasis.opendocument.text"         = [ docEditor ];
        "application/vnd.oasis.opendocument.spreadsheet"  = [ spreadsheet ];
        "application/vnd.oasis.opendocument.presentation" = [ presentation ];
        "application/msword"                              = [ docEditor ];
        "application/vnd.ms-excel"                        = [ spreadsheet ];
        "application/vnd.ms-powerpoint"                   = [ presentation ];
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"   = [ docEditor ];
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"         = [ spreadsheet ];
        "application/vnd.openxmlformats-officedocument.presentationml.presentation" = [ presentation ];
      };
    };

    # Exceção necessária: kate.desktop do nixpkgs não declara text/markdown.
    # Este entry é colocado no nix-profile pelo HM (não em ~/.local/share/applications/).
    xdg.desktopEntries.kate-markdown = {
      name = "Kate Kryonix";
      exec = "kate %U";
      mimeType = [ "text/markdown" "text/x-markdown" ];
      noDisplay = true;
    };

    # Reconstrói o cache do KDE após cada switch.
    # Dolphin usa ksycoca6 para resolver apps — sem rebuild, as entradas
    # novas do nix-profile não são visíveis para todos os tipos de arquivo.
    home.activation.rebuildKdeMimeCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental 2>/dev/null || true
    '';
  };
}
