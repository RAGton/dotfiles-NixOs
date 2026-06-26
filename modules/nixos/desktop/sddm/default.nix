{
  config,
  lib,
  pkgs,
  ...
}:
let
  env = config.kryonix.desktop.environment;
  isKde = env == "kde";
  cfg = config.kryonix.desktop.sddm;
  legacyKdeTheme = config.kryonix.desktop.kde.sddm.theme;

  selectedTheme =
    if cfg.theme.preset == "kryonix-clean" then
      "kryonix-clean"
    else if isKde && legacyKdeTheme == "kryonix-aurora" then
      "kryonix-aurora"
    else
      null;

  packagedTheme =
    selectedTheme != null
    && lib.elem selectedTheme [
      "kryonix-aurora"
      "kryonix-clean"
    ];
in
{
  options.kryonix.desktop.sddm = {
    enable = (lib.mkEnableOption "camada declarativa de temas SDDM do Kryonix") // {
      default = true;
    };

    theme.preset = lib.mkOption {
      type = lib.types.enum [
        "default"
        "kryonix-clean"
      ];
      default = "default";
      description = ''
        Preset visual do SDDM no caminho canônico do Kryonix.

        - "default": preserva o comportamento atual do ambiente selecionado.
          No KDE, mantém Breeze por default e continua respeitando o caminho
          legado `kryonix.desktop.kde.sddm.theme = "kryonix-aurora"`.
        - "kryonix-clean": ativa o novo tema SDDM Clean de forma opt-in.

        Este módulo não troca automaticamente o display manager. Ele só atua
        quando o host já usa SDDM.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.theme.preset == "kryonix-clean" && !isKde);
        message = ''
          kryonix.desktop.sddm.theme.preset = "kryonix-clean" ainda está
          integrado apenas ao fluxo KDE. Em Hyprland, o default atual continua
          sendo o tema astronaut.
        '';
      }
    ];

    environment.systemPackages = lib.mkIf packagedTheme [ pkgs.kryonix-sddm-theme ];

    services.displayManager.sddm = lib.mkIf (isKde && packagedTheme) {
      theme = selectedTheme;
      extraPackages = [
        pkgs.kdePackages.qtsvg
      ]
      ++ lib.optional (selectedTheme == "kryonix-aurora") pkgs.kdePackages.qt5compat;
    };
  };
}
