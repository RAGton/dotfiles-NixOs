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
  # Tema SDDM Kryonix Aurora é opt-in; "breeze" (default) preserva o greeter atual.
  useAuroraSddm = cfg.sddm.theme == "kryonix-aurora";
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

    sddm.theme = lib.mkOption {
      type = lib.types.enum [
        "breeze"
        "kryonix-aurora"
      ];
      default = "breeze";
      description = ''
        Tema do greeter SDDM (login gráfico).

        - "breeze": default seguro — NÃO sobrescreve o tema do SDDM, mantendo o
          greeter Breeze padrão do Plasma 6 (fallback sempre disponível).
        - "kryonix-aurora": tema próprio Kryonix (QML, dark navy, accent #38BDF8),
          empacotado em packages/kryonix-sddm-theme.nix. Opt-in: ativa o pacote,
          seta services.displayManager.sddm.theme e injeta qtsvg para o SVG.

        Risco (login gráfico): um tema quebrado pode impedir o login pela tela.
        Validar com sddm-greeter --test-mode e build do host ANTES do switch.
        Rollback: voltar para "breeze" e rebuild. Ver docs/desktop/KRYONIX_SDDM.md.
      '';
    };
  };

  config = lib.mkIf isKde {
    # Display manager: SDDM em modo Wayland.
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      autoNumlock = true;

      # Tema opt-in: só sobrescreve quando "kryonix-aurora". Em "breeze" (default)
      # NÃO definimos `theme`, preservando o greeter Breeze padrão (fallback).
      theme = lib.mkIf useAuroraSddm "kryonix-aurora";

      # O tema usa SVG (Image) → precisa do plugin qtsvg no ambiente do greeter.
      extraPackages = lib.mkIf useAuroraSddm [ pkgs.kdePackages.qtsvg ];
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
    environment.systemPackages =
      with pkgs;
      [
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
      ]
      # Tema SDDM Kryonix Aurora só entra no sistema quando opt-in (instala em
      # /run/current-system/sw/share/sddm/themes/kryonix-aurora).
      ++ lib.optional useAuroraSddm pkgs.kryonix-sddm-theme;

    # Plasma Manager é Home Manager; quando o host seleciona KDE, o módulo de
    # sistema injeta também a camada HM do Plasma para o usuário do host.
    home-manager.users.${userConfig.name}.imports = [
      inputs.plasma-manager.homeModules.plasma-manager
      ../../../../desktop/kde/user.nix
    ];
  };
}
