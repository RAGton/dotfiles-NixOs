# =============================================================================
# Módulo Home Manager: Multi-Monitor Hyprland
# Autor: Gabriel Rocha (rag)
#
# O que é:
# - Define opções declarativas kryonix.desktop.monitors e
#   kryonix.desktop.workspaceMonitorMap para configuração de monitores no Hyprland.
# - Gera diretivas `monitor=` e `workspace=` para o Hyprland via extraConfig.
# - Garante sempre o fallback `monitor=,preferred,auto,1`.
#
# Como usar (por host):
#
#   # Notebook: zero config — auto-detect funciona via fallback
#   # Desktop glacier com monitores fixos:
#   kryonix.desktop.monitors = {
#     "DP-1" = { resolution = "2560x1440"; refreshRate = 144; position = "0x0"; primary = true; };
#     "HDMI-A-1" = { resolution = "1920x1080"; position = "2560x0"; };
#   };
#   kryonix.desktop.workspaceMonitorMap = {
#     "DP-1"    = [ 1 2 3 4 5 ];
#     "HDMI-A-1" = [ 6 7 8 9 10 ];
#   };
#
# Riscos:
# - Nomes de output (DP-1, HDMI-A-1, eDP-1) são específicos do hardware.
#   Monitores não declarados aqui recebem o fallback automático.
# =============================================================================
{
  lib,
  config,
  ...
}:

let
  cfg = config.kryonix.desktop;

  # Gera a string de diretiva monitor= para um output declarado.
  # Formato Hyprland: monitor=<name>,<resolution>[@<Hz>],<position>,<scale>[,mirror,<source>]
  mkMonitorLine =
    name: m:
    let
      res =
        if m.resolution == "preferred" then
          "preferred"
        else if m.refreshRate != 0 then
          "${m.resolution}@${toString m.refreshRate}"
        else
          m.resolution;
      pos = m.position;
      scale = toString m.scale;
    in
    if !m.enabled then "monitor=${name},disabled" else "monitor=${name},${res},${pos},${scale}";

  # Gera diretivas workspace= a partir do mapa workspaceMonitorMap.
  mkWorkspaceLines =
    map:
    lib.concatStringsSep "\n" (
      lib.flatten (
        lib.mapAttrsToList (
          monitor: workspaces:
          lib.imap1 (
            i: ws: "workspace=${toString ws},monitor:${monitor}${if i == 1 then ",default:true" else ""}"
          ) workspaces
        ) map
      )
    );

  monitorLines = lib.mapAttrsToList mkMonitorLine cfg.monitors.outputs;
  workspaceLines = mkWorkspaceLines cfg.workspaceMonitorMap;

  generatedConfig = ''
    # Fallback universal — SEMPRE presente para outputs não declarados
    monitor=,${cfg.monitors.fallbackRule}

  ''
  + lib.optionalString (monitorLines != [ ]) (
    "# Monitores declarados via kryonix.desktop.monitors\n"
    + lib.concatStringsSep "\n" monitorLines
    + "\n"
  )
  + lib.optionalString (workspaceLines != "") (
    "\n# Workspaces por monitor via kryonix.desktop.workspaceMonitorMap\n" + workspaceLines + "\n"
  );

  monitorSubmodule = lib.types.submodule {
    options = {
      resolution = lib.mkOption {
        type = lib.types.str;
        default = "preferred";
        description = "Resolução do monitor (ex: '1920x1080', '2560x1440', 'preferred').";
      };
      position = lib.mkOption {
        type = lib.types.str;
        default = "auto";
        description = "Posição do monitor (ex: '0x0', '1920x0', 'auto', 'auto-right').";
      };
      scale = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Fator de escala do monitor (ex: 1.0, 1.25, 1.5, 2.0).";
      };
      refreshRate = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Taxa de atualização em Hz (0 = automático, usa o padrão do monitor).";
      };
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Se false, o monitor é desabilitado (gera 'monitor=<name>,disabled').";
      };
      primary = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Marca este como monitor primário (informativo para scripts de runtime).";
      };
    };
  };

in
{
  options.kryonix.desktop = {
    monitors = {
      outputs = lib.mkOption {
        type = lib.types.attrsOf monitorSubmodule;
        default = { };
        description = ''
          Configuração declarativa de monitores para o Hyprland.
          Chaves são nomes de output do Wayland (ex: "eDP-1", "HDMI-A-1", "DP-1").
          Monitores não declarados recebem o fallback automático.
        '';
        example = lib.literalExpression ''
          {
            "DP-1"    = { resolution = "2560x1440"; refreshRate = 144; position = "0x0"; primary = true; };
            "HDMI-A-1" = { resolution = "1920x1080"; position = "2560x0"; };
          }
        '';
      };

      fallbackRule = lib.mkOption {
        type = lib.types.str;
        default = "preferred,auto,1";
        description = ''
          Regra fallback aplicada a todos os outputs não declarados.
          Formato: <resolution>,<position>,<scale>
          Padrão: "preferred,auto,1" — usa resolução preferida, posição automática, escala 1x.
        '';
      };
    };

    workspaceMonitorMap = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.int);
      default = { };
      description = ''
        Mapeamento de workspaces para monitores.
        Chaves são nomes de output; valores são listas de números de workspace.
        O primeiro workspace de cada monitor é marcado como default.
      '';
      example = lib.literalExpression ''
        {
          "DP-1"    = [ 1 2 3 4 5 ];
          "HDMI-A-1" = [ 6 7 8 9 10 ];
        }
      '';
    };
  };

  config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {
    wayland.windowManager.hyprland.extraConfig = lib.mkBefore generatedConfig;
  };
}
