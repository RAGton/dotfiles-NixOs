# =============================================================================
# modules/nixos/desktop/kde/default.nix — Fundação de sistema do KDE Plasma 6
#
# O que é:
# - Stack de sistema do ambiente "kde": SDDM (Wayland) + Plasma 6 + pacotes base
#   (Krohnkite para tiling, Nordzy cursor para o greeter/sistema).
#
# Por quê:
# - KDE é o ambiente principal de longo prazo do Kryonix. Toda a lógica de DE fica
#   no engine; hosts apenas selecionam `kryonix.desktop.environment = "kde"`.
#
# Como:
# - Ativa apenas quando env == "kde" (coexistência com o stack Hyprland legado).
# - O Krohnkite é instalado no nível do sistema para que o KWin enxergue o
#   KWin/Script em $XDG_DATA_DIRS; a ativação declarativa é feita no Home Manager
#   (desktop/kde/tiling.nix) via kwinrc.
#
# Riscos:
# - Não habilitar GDM/greetd/gnome aqui (o branch kde em ../default.nix já os força off).
# =============================================================================
{
  config,
  inputs,
  lib,
  pkgs,
  userConfig,
  ...
}:
let
  isKde = config.kryonix.desktop.environment == "kde";
  cfg = config.kryonix.desktop.kde;
in
{
  options.kryonix.desktop.kde = {
    autoLoginUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Usuário para autologin no SDDM diretamente numa sessão Plasma Wayland.

        Destinado a hosts headless/remotos (ex.: glacier acessado via KRDP), onde
        é preciso ter uma sessão Plasma em execução sem interação local. Em
        laptops com login normal, mantenha `null`.
      '';
    };

    theme.colorScheme = lib.mkOption {
      type = lib.types.enum [
        "bonafides"
        "kryonix-dark"
      ];
      default = "bonafides";
      description = ''
        Esquema de cores aplicado ao KDE Plasma na camada Home Manager.

        - "bonafides": esquema azul BonaFides (default histórico do host, base do
          Global Theme / Kvantum). Comportamento atual inalterado.
        - "kryonix-dark": esquema oficial Kryonix com os tokens próprios
          (background #0B0F14, accent #38BDF8 — ver desktop/kde/scheme.nix e
          docs/desktop/PLASMA_THEME_KRYONIX_DARK.md). Opt-in; não remove BonaFides
          (lookAndFeel/Kvantum continuam), apenas troca o color-scheme + accent.

        Consumido por desktop/kde/scheme.nix via `osConfig`.
      '';
    };

    theme.preset = lib.mkOption {
      type = lib.types.enum [
        "bonafides"
        "kryonix-blue-glass-dark"
        "kryonix-blue-glass-light"
      ];
      default = "bonafides";
      description = ''
        Preset visual principal do KDE Plasma.

        - "bonafides": mantém o tema histórico do host como default efetivo.
        - "kryonix-blue-glass-dark": preset opt-in Blue Glass escuro.
        - "kryonix-blue-glass-light": preset opt-in Blue Glass claro.

        O preset Blue Glass altera apenas assets e seleção visual declarativa.
        O layout do painel continua controlado em desktop/kde/theme.nix via
        plasma-manager, sem editar plasma-org.kde.plasma.desktop-appletsrc.
      '';
    };

    sddm.theme = lib.mkOption {
      type = lib.types.enum [
        "breeze"
        "kryonix-aurora"
      ];
      default = "breeze";
      description = ''
        Tema do greeter SDDM (login gráfico).

        - "breeze": default seguro — preserva o greeter Breeze padrão do Plasma 6.
        - "kryonix-aurora": caminho legado compatível para o tema próprio Kryonix.

        O novo caminho canônico para presets SDDM fica em
        `kryonix.desktop.sddm.theme.preset`. Use
        `"kryonix-clean"` ali para ativar o novo preset Clean sem alterar o
        default global.

        Risco (login gráfico): um tema quebrado pode impedir o login pela tela.
        Validar com sddm-greeter --test-mode e build do host ANTES do switch.
        Rollback: voltar para "breeze" e rebuild. Ver docs/desktop/SDDM.md.
      '';
    };
  };

  config = lib.mkIf isKde {
    # Display manager: SDDM em modo Wayland.
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      autoNumlock = true;
    };

    # Autologin opcional para hosts headless/remotos (KRDP).
    services.displayManager.autoLogin = lib.mkIf (cfg.autoLoginUser != null) {
      enable = true;
      user = cfg.autoLoginUser;
    };
    services.displayManager.defaultSession = lib.mkIf (cfg.autoLoginUser != null) (
      lib.mkDefault "plasma"
    );

    # Desktop: Plasma 6 (Wayland por padrão no SDDM/Plasma 6).
    services.desktopManager.plasma6.enable = true;

    # Bypass do drkonqi: kdePackages.drkonqi (6.6.5) quebra o build por patch
    # inválido no upstream do nixpkgs ("snippet não encontrado"). O Plasma 6 o
    # puxa por padrão — excluímos do closure para o sistema compilar (perde-se
    # apenas o handler de relatório de crash do KDE).
    environment.plasma6.excludePackages = with pkgs.kdePackages; [ drkonqi ];

    # dconf é necessário para configurações GTK/portais consistentes.
    programs.dconf.enable = true;

    # Portais: o Plasma fornece xdg-desktop-portal-kde; mantemos o GTK como
    # fallback para apps GTK.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # Pacotes de sistema do ambiente KDE.
    environment.systemPackages = with pkgs; [
      # Krohnkite (KWin/Script de tiling) — instalado a nível de sistema para
      # ficar visível ao KWin; habilitado declarativamente no HM (kwinrc).
      kdePackages.krohnkite

      # Cursor Nordzy (usado pelo SDDM/greeter e disponível ao sistema).
      nordzy-cursor-theme

      # Utilitários Wayland úteis e ferramentas KDE de linha de comando usadas
      # pelos atalhos/declarações do Home Manager.
      wl-clipboard
      kdePackages.qttools # qdbus6 (usado pelos atalhos "mover e seguir"/scratchpad)
      playerctl # controle de mídia (atalhos Meta+,/. e XF86AudioPlay)
      kdePackages.plasma-nm
      kdePackages.plasma-pa
      kdePackages.plasma-systemmonitor
      kryonix-plasma-theme

      # Módulo de configuração do SDDM no KDE System Settings
      # ("Tela de Login" → escolher tema/cursor/usuário sem editor externo).
      kdePackages.sddm-kcm
    ];

    # Plasma Manager é Home Manager; quando o host seleciona KDE, o módulo de
    # sistema injeta também a camada HM do Plasma para o usuário do host.
    home-manager.users.${userConfig.name}.imports = [
      inputs.plasma-manager.homeModules.plasma-manager
      ../../../../desktop/kde/user.nix
    ];
  };
}
