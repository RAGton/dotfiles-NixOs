# =============================================================================
# Autor: rag
#
# O que é:
# - Módulo Home Manager para habilitar e configurar o `fastfetch`.
#
# Por quê:
# - Exibe um "banner" consistente com informações do sistema/desktop.
# - Útil para diagnóstico rápido e estética no startup do shell.
#
# Como:
# - Define `programs.fastfetch.settings` com layout, separador e módulos exibidos.
# - O logo Kryonix é injetado via `pkgs.writeText`, sem depender de arquivo
#   externo. Pode ser desativado por `kryonix.programs.fastfetch.logo.enable`.
#
# Riscos:
# - Alguns ícones dependem de fontes Nerd Font configuradas.
# - Módulos como `publicip` dependem de rede e podem atrasar a execução.
# =============================================================================
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.kryonix.programs.fastfetch;

  # Logo ASCII compacto (~10 colunas, 6 linhas). Cores 1/2 são resolvidas
  # pelo fastfetch a partir dos campos `logo.color.1` / `logo.color.2`.
  kryonixLogo = pkgs.writeText "kryonixos-logo" ''
    $1██╗  $2██╗
    $1██║ $2██╔╝
    $1█████╔╝
    $1██╔═$2██╗
    $1██║  $2██╗
    $1╚═╝  $2╚═╝
  '';
in
{
  options.kryonix.programs.fastfetch = {
    logo.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Mostra o logo KryonixOS (ASCII colorido) à esquerda do fastfetch.
        Desative se preferir o layout sem logo (`logo.type = "none"`).
      '';
    };
  };

  config = {
    # Instala e configura o fastfetch via módulo do Home Manager
    programs.fastfetch = {
      enable = true;
      settings = {
        logo =
          if cfg.logo.enable then
            {
              source = "${kryonixLogo}";
              type = "file";
              padding.right = 2;
              color = {
                "1" = "cyan";
                "2" = "magenta";
              };
            }
          else
            {
              type = "none";
            };
        display = {
          separator = "->   ";
        };
        modules = [
          {
            type = "title";
            format = "{6}{7}{8}";
          }
          "break"
          {
            type = "custom";
            format = "┌───────────────────────────── System Information ─────────────────────────────┐";
          }
          "break"
          {
            key = "     OS           ";
            keyColor = "red";
            type = "os";
          }
          {
            key = "    󰌢 Machine      ";
            keyColor = "green";
            type = "host";
          }
          {
            key = "     Kernel       ";
            keyColor = "magenta";
            type = "kernel";
          }
          {
            key = "    󰏖 Packages     ";
            type = "packages";
          }
          {
            key = "    󰅐 Uptime       ";
            keyColor = "red";
            type = "uptime";
          }
          {
            key = "    󰍹 Resolution   ";
            keyColor = "yellow";
            type = "display";
            compactType = "original-with-refresh-rate";
          }
          {
            key = "     WM           ";
            keyColor = "blue";
            type = "wm";
          }
          {
            key = "     DE           ";
            keyColor = "green";
            type = "de";
          }
          {
            key = "     Shell        ";
            keyColor = "cyan";
            type = "shell";
          }
          {
            key = "     Terminal     ";
            keyColor = "red";
            type = "terminal";
          }
          {
            key = "    󰻠 CPU          ";
            keyColor = "yellow";
            type = "cpu";
          }
          {
            key = "    󰍛 GPU          ";
            keyColor = "blue";
            type = "gpu";
          }
          {
            key = "    󰑭 Memory       ";
            keyColor = "magenta";
            type = "memory";
          }
          {
            key = "    󰩟 Local IP     ";
            keyColor = "red";
            type = "localip";
          }
          {
            key = "    󰩠 Public IP    ";
            keyColor = "cyan";
            type = "publicip";
          }
          "break"
          {
            type = "custom";
            format = "└──────────────────────────────────────────────────────────────────────────────┘";
          }
          "break"
          {
            paddingLeft = 34;
            symbol = "circle";
            type = "colors";
          }
        ];
      };
    };
  };
}
