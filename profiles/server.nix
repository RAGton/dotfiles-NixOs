# =============================================================================
# profiles/server.nix
# Autor: Gabriel Aguiar Rocha (RAGton)
#
# O que é:
# - Profile "server" do Kryonix: workstation dev, headless ops, infra.
# - DEFAULT theme: kryonix-carbon (âmbar Kryonix, server-grade).
#
# Por quê:
# - O Carbon é o "safe default" server-grade: âmbar sobre preto profundo,
#   sem translucência, sem animações decorativas, radius 4 (cantos vivos).
# - Eclipse (azul, Apple-like) fica para profile desktop (futuro).
#
# Como usar:
#   # Forma simples (assume theme default 'kryonix-carbon'):
#   { kryonix.profiles.server.enable = true; }
#
#   # Forma completa (resolver themePackage externamente via flake input):
#   { kryonix.profiles.server = {
#       enable = true;
#       theme = "kryonix-carbon";
#       themePackage = inputs.kryonix.packages.x86_64-linux.kryonix-carbon;
#     }; }
#
# IMPORTANTE — Resolução do themePackage:
# - O motor não tem flake input próprio (por design — ver AGENTS.md do kryonixos:
#   "todo inputs.<x> referenciado por módulos do motor deve ter .follows").
# - Por isso o `themePackage` é resolvido EXTERNAMENTE (no host que consome).
# - Quando o user não fornece `themePackage`, o módulo cai num fallback
#   warning + pacote vazio (sem quebrar eval).
#
# Risco:
# - Esta opção NÃO instala Plasma; ela apenas injeta o pacote do theme
#   em environment.packages e configura Plasma via plasma-manager (HM)
#   quando `kryonix.desktop.environment = "kde"` está ativo.
# - Se Plasma não estiver ativo, o pacote fica disponível mas inerte.
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.kryonix.profiles.server;

  # Themes disponíveis — apenas nomes. O pacote é resolvido externamente.
  availableThemes = [
    "kryonix-carbon"
  ];

  # Valida nome do theme
  isValidTheme = builtins.elem cfg.theme availableThemes;

  # selectedTheme: usa o package fornecido externamente, OU um warning placeholder.
  # O placeholder existe pra não quebrar eval quando themePackage não é setado
  # (cenário comum: módulo importado mas option não totalmente configurada).
  selectedTheme =
    if cfg.themePackage != null then
      cfg.themePackage
    else if !isValidTheme then
      throw ''
        kryonix.profiles.server: theme "${cfg.theme}" não disponível.
        Themes válidos: ${toString availableThemes}
        E themePackage precisa ser setado externamente (não é resolvido pelo motor).
      ''
    else
      # Placeholder que satisfaz o type system mas é inerte.
      # Log warning pra debug.
      let
        _ = builtins.trace ''
          [kryonix.profiles.server] AVISO: themePackage não foi setado.
          O theme "${cfg.theme}" NÃO será instalado em environment.packages.
          Pra ativar, passe themePackage via inputs.kryonix.packages.<system>.${cfg.theme}.
        '' null;
      in
      # Derivação vazia: package trivial que satisfaz o tipo `package`.
      # Não vai fazer nada útil, mas permite eval sem crash.
      pkgs.runCommand "kryonix-${cfg.theme}-placeholder" { } "mkdir -p $out";
in
{
  options.kryonix.profiles.server = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Ativa o profile "server" do Kryonix.

        Inclui o theme default (kryonix-carbon) em environment.packages
        e configura Plasma para usá-lo (quando kryonix.desktop.environment
        = "kde").
      '';
    };

    theme = mkOption {
      type = types.str;
      default = "kryonix-carbon";
      description = ''
        Nome do theme a aplicar neste profile.

        Valores válidos hoje:
          - "kryonix-carbon"  (default, server-grade, âmbar)
      '';
    };

    themePackage = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Derivação do theme a instalar.

        Quando null, o módulo tenta ativar o theme mas não instala o pacote
        (útil pra hosts que gerenciam o pacote externamente).

        Pra resolução via flake input:
          kryonix.profiles.server.themePackage =
            inputs.kryonix.packages.x86_64-linux.kryonix-carbon;
      '';
    };
  };

  config = mkIf cfg.enable {
    # Tema sempre instalado quando profile ativo E themePackage foi setado.
    # Se themePackage é null, não instala nada (eval não quebra).
    # environment.systemPackages é a option canônica NixOS pra instalar
    # pacotes visíveis no PATH do sistema (substituiu environment.packages).
    environment.systemPackages = mkIf (cfg.themePackage != null) [ selectedTheme ];

    # IMPORTANTE — Configuração Plasma/Qt NÃO vai aqui.
    # A parte Plasma via plasma-manager vive em
    # modules/home-manager/profiles/server.nix (Home Manager namespace).
    # Aqui só temos options NixOS-side válidas.
  };
}
