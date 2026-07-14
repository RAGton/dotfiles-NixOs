{ pkgs, ... }:

let
  normalizeText = text: builtins.replaceStrings [ "\r\n" ] [ "\n" ] text;

  nodeBootSplash =
    pkgs.runCommand "node-installer-boot-splash.png"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      (normalizeText ''
        magick \
          -size 800x600 gradient:'#040b16-#123550' \
          \( -size 800x600 xc:none -fill 'rgba(120,196,255,0.18)' -draw 'circle 640,110 860,110' \) \
          -compose screen -composite \
          \( -size 800x600 xc:none -fill 'rgba(255,255,255,0.06)' -draw 'circle 140,520 360,520' \) \
          -compose screen -composite \
          \( ${./installer-ui/imgs/ragton.png} -resize 180x180 \) \
          -gravity north -geometry +0+48 -composite \
          -depth 8 \
          PNG24:$out
      '');

  nodeGrubTheme =
    pkgs.runCommand "node-installer-grub-theme"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      (normalizeText ''
        mkdir -p $out
        cp -r ${pkgs.nixos-grub2-theme}/* $out/
        chmod -R u+w $out

        magick \
          -size 1920x1080 xc:'#000000' \
          -depth 8 \
          PNG24:$out/background.png

        magick ${./installer-ui/imgs/ragton.png} -resize 280x280 $out/logo.png

        cat > $out/theme.txt <<'EOF'
        title-text: ""
        title-font: "DejaVu Regular"
        title-color: "#f5fbff"

        + image {
          top = 7%
          height = 280
          width = 280
          left = 50%-140
          file = "logo.png"
        }

        desktop-image: "background.png"
        message-font: "DejaVu Regular"
        message-color: "#f5fbff"
        terminal-font: "Unifont Regular"
        terminal-box: "terminal_*.png"

        + progress_bar {
          id = "__timeout__"
          top = 95%-32
          left = 50%-25%
          height = 32
          width = 50%
          show_text = true
          text = "@TIMEOUT_NOTIFICATION_MIDDLE@"
          border_color = #123550
          bg_color = #78c4ff
          fg_color = #123550
        }

        + boot_menu {
          left = 50%-400
          width = 800
          top = 7%+280+4%
          height = 100%-7%-280-4%-4%-32-3%
          item_font = "DejaVu Regular"
          item_color = "#f5fbff"
          item_height = 40
          item_icon_space = 12
          item_spacing = 0
          item_padding = 0
          selected_item_font = "DejaVu Regular"
          selected_item_color = "#071a2f"
          selected_item_pixmap_style = "select_*.png"
          icon_height = 32
          icon_width = 42
          scrollbar = false
          menu_pixmap_style = "boot_menu_*.png"
        }
        EOF
      '');
in
{
  console = {
    earlySetup = true;
    colors = [
      "071a2f"
      "e06c75"
      "78c4ff"
      "e5c07b"
      "61afef"
      "c678dd"
      "56b6c2"
      "d8e6f3"
      "35516d"
      "ff8fa3"
      "9fd8ff"
      "f2d39b"
      "8cc8ff"
      "d7a9f2"
      "8ed7df"
      "f5fbff"
    ];
    font = "Lat2-Terminus16";
  };

  isoImage = {
    splashImage = nodeBootSplash;
    efiSplashImage = nodeBootSplash;
    grubTheme = nodeGrubTheme;
    syslinuxTheme = ''
      MENU TITLE NODE Installer
      MENU RESOLUTION 800 600
      MENU CLEAR
      MENU ROWS 6
      MENU CMDLINEROW -4
      MENU TIMEOUTROW -3
      MENU TABMSGROW -2
      MENU HELPMSGROW -1
      MENU HELPMSGENDROW -1
      MENU MARGIN 0

      MENU COLOR BORDER       30;44      #00000000    #00000000   none
      MENU COLOR SCREEN       37;40      #FFF5FBFF    #00000000   none
      MENU COLOR TABMSG       31;40      #80000000    #00000000   none
      MENU COLOR TIMEOUT      1;37;40    #FFF5FBFF    #00000000   none
      MENU COLOR TIMEOUT_MSG  37;40      #FFF5FBFF    #00000000   none
      MENU COLOR CMDMARK      1;36;40    #FFF5FBFF    #00000000   none
      MENU COLOR CMDLINE      37;40      #FFF5FBFF    #00000000   none
      MENU COLOR TITLE        1;37;40    #FFF5FBFF    #00000000   none
      MENU COLOR UNSEL        37;44      #FFF5FBFF    #00000000   none
      MENU COLOR SEL          7;37;40    #FF071A2F    #FF78C4FF   std
    '';
  };

  services.getty.greetingLine = "\\e[1;34mNODE Installer\\e[0m";
  services.getty.helpLine = "";

  environment.etc."issue".text = ''

    \033[1;34mNODE Installer Live Environment\033[0m
    Web UI: http://<ip-da-maquina>:8000
    SSH: node@<ip-da-maquina> (senha: node)

  '';

  environment.etc."issue.net".text = "NODE Installer Live Environment\n";
}
