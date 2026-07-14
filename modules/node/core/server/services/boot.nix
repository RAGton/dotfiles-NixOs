{
  config,
  lib,
  pkgs,
  nodeWanInterface ? "",
  nodeRootRaid ? false,
  ...
}:

let
  nodeSerialConsole =
    if builtins.hasAttr "nodeSerialConsole" config._module.args then
      config._module.args.nodeSerialConsole
    else
      true;

  defaultSerialConsoles = [
    {
      device = "ttyS0";
      kernelParam = "console=ttyS0,115200n8";
    }
    {
      device = "hvc0";
      kernelParam = "console=hvc0";
    }
    {
      device = "ttyAMA0";
      kernelParam = "console=ttyAMA0,115200n8";
    }
  ];

  nodeSerialConsoles =
    if builtins.hasAttr "nodeSerialConsoles" config._module.args then
      config._module.args.nodeSerialConsoles
    else
      defaultSerialConsoles;

  # Criar tema GRUB NODE (mesmo da ISO) — bonito e consistente
  nodeGrubTheme =
    pkgs.runCommand "node-grub-theme"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        mkdir -p $out
        cp -r ${pkgs.nixos-grub2-theme}/* $out/
        chmod -R u+w $out

        # Usar background NODE da ISO
        install -Dm0644 ${../../themes/grub/node/background.png} $out/background.png

        # Se tiver um logo PNG, incluir
        if [[ -f ${../../themes/grub/node/background.png} ]]; then
          magick -density 96 ${../../themes/grub/node/background.png} -resize 184x184 -background transparent -gravity center -extent 184x184 $out/logo.png 2>/dev/null || true
        fi

        # Configuração tema GRUB NODE
        cat > $out/theme.txt <<'EOF'
        title-text: ""
        title-font: "DejaVu Regular"
        title-color: "#f5fbff"

        + image {
          top = 92
          left = 294
          height = 184
          width = 184
          file = "logo.png"
        }

        desktop-image: "background.png"
        message-font: "DejaVu Regular"
        message-color: "#ecf5ff"
        terminal-font: "Unifont Regular"
        terminal-box: "terminal_*.png"

        + progress_bar {
          id = "__timeout__"
          top = 842
          left = 286
          height = 18
          width = 760
          show_text = false
          text = "@TIMEOUT_NOTIFICATION_MIDDLE@"
          border_color = "#2a4761"
          bg_color = "#142636"
          fg_color = "#7cb9dd"
        }

        + boot_menu {
          left = 270
          width = 786
          top = 318
          height = 492
          item_font = "DejaVu Regular"
          item_color = "#eaf4ff"
          item_height = 46
          item_icon_space = 10
          item_spacing = 4
          item_padding = 4
          selected_item_font = "DejaVu Regular"
          selected_item_color = "#08131d"
          selected_item_pixmap_style = "select_*.png"
          icon_height = 24
          icon_width = 30
          scrollbar = false
          menu_pixmap_style = "boot_menu_*.png"
        }
        EOF
      '';
in
{
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    devices = [ "nodev" ];
    useOSProber = false;
    theme = nodeGrubTheme;
  };
  boot.swraid.enable = lib.mkDefault nodeRootRaid;

  boot.kernelParams =
    # Mantem acesso a consoles seriais comuns em lab/hipervisor e em hosts
    # que expoem fallback serial diferente do ttyS0 classico.
    lib.optionals nodeSerialConsole (
      map (serialConsole: serialConsole.kernelParam) nodeSerialConsoles
    )
    ++ [
      # tty1 continua como fallback local previsivel quando o host tem console
      # fisico/virtual direto.
      "console=tty1"
      "panic=10"
      "systemd.ssh_auto=no"
    ];

  systemd.services = lib.mkMerge (
    [
      {
        "getty@tty1".enable = lib.mkDefault true;
      }
    ]
    ++ map (serialConsole: {
      "serial-getty@${serialConsole.device}" = {
        enable = nodeSerialConsole;
        unitConfig.ConditionPathExists = "/dev/${serialConsole.device}";
      };
    }) nodeSerialConsoles
  );

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "fs.inotify.max_user_watches" = 1048576;
    "net.ipv4.ip_forward" = if nodeWanInterface != "" then 1 else 0;
  };
}
