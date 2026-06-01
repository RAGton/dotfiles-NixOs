# =============================================================================
# Lib: Opções customizadas do Kryonix
# Autor: Gabriel Rocha (rag) + Codex
# Data: 2026-03-12
#
# O que é:
# - Define o namespace kryonix.* com opções para desktop, features, rice, etc
#
# Por quê:
# - Abstração de alto nível para configuração
# - Hosts escolhem via opções, não imports
# - Facilita troca de desktop/features
#
# Como:
# - Importado nos módulos do flake via mkNixosConfiguration
# - Opções ficam disponíveis em config.kryonix.*
#
# Riscos:
# - NENHUM nesta etapa (apenas define opções, não força uso)
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:

let
  desktopConfigured =
    (config.services.displayManager.gdm.enable or false)
    || (config.services.greetd.enable or false)
    || (config.programs.hyprland.enable or false)
    || (config.services.desktopManager.plasma6.enable or false);
in
{
  imports = [
    (lib.mkAliasOptionModule [ "rag" ] [ "kryonix" ])
  ];

  options.kryonix = {
    # =========================
    # Desktop Environment
    # =========================
    desktop = {
      environment = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "hyprland"
            "kde"
          ]
        );
        default = null;
        description = ''
          Ambiente de desktop a usar.

          Opções:
          - "hyprland": stack legado (Hyprland + Caelestia + SDDM). Mantido durante a
            migração para coexistência/rollback.
          - "kde": ambiente principal de longo prazo — KDE Plasma 6 Wayland + SDDM +
            KWin/Krohnkite + Albert (ver modules/nixos/desktop/kde e desktop/kde).
          - null: sem desktop (headless/servidor)

          A arquitetura é extensível: adicionar um novo ambiente = novo valor neste enum
          + novo branch em modules/nixos/desktop/default.nix + novo diretório desktop/<env>.
          O módulo compartilhado do desktop habilita o stack correspondente.
        '';
      };

      wayland = lib.mkOption {
        type = lib.types.bool;
        default = config.kryonix.desktop.environment != null;
        description = "Habilita suporte a Wayland (ativado automaticamente com desktop)";
      };

      directLogin = {
        enable = lib.mkEnableOption ''
          Inicia o desktop sem display manager (sem GDM/greetd), usando autologin em TTY
          e auto-start do compositor na sessão do usuário.

          AVISO: isso remove a tela de login e entra direto no usuário.
        '';

        tty = lib.mkOption {
          type = lib.types.int;
          default = 1;
          description = "TTY (VT) em que o auto-start do compositor deve acontecer (ex.: 1 para tty1).";
        };
      };
    };

    # =========================
    # Hardware / Drivers (host-toggles)
    # =========================
    hardware = {
      openrgb = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Compatibilidade legada. Use kryonix.features.openrgb.enable.";
        };
      };
    };

    # =========================
    # Services (host-toggles)
    # =========================
    services = {
      greetdDms = {
        enable = lib.mkEnableOption "Habilita o greetd configurado com o greeter DankMaterialShell";
      };
    };

    # =========================
    # Features (Opt-in)
    # =========================
    # NOTA: As opções de features são declaradas nos próprios módulos de features
    # (features/gaming.nix, features/virtualization.nix, etc)
    # Não declarar aqui para evitar duplicação!

    # =========================
    # Branding
    # =========================
    branding = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "Kryonix";
        description = "Nome do branding do sistema (exibido na tela de login, etc)";
      };

      logo = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Caminho para o logotipo do branding";
      };
    };
  };

  # =========================
  # Config (validation only)
  # =========================
  config = {
    # Assertions para validar configuração
    assertions = [
      {
        assertion = config.kryonix.desktop.environment == null || desktopConfigured;
        message = ''
          O ambiente de desktop requer Hyprland e GDM habilitados.
          Se estiver usando kryonix.desktop.environment, verifique se o módulo compartilhado de desktop foi importado.
        '';
      }
    ];

    # Warnings para opções definidas mas sem efeito (transição v1→v2)
    warnings = lib.optional (config.kryonix.desktop.environment != null && !desktopConfigured) ''
      kryonix.desktop.environment está definido como "${config.kryonix.desktop.environment}", mas o desktop
      ainda não foi materializado em Hyprland + GDM.
      Verifique se hosts/common está importando modules/nixos/desktop corretamente.
    '';
  };
}
