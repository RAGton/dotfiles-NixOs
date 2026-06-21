# ==============================================================================
# Módulo: Browser Automation (Chromium libs via nix-ld + playwright)
# Autor: rag (com auxílio de Aura)
#
# O que é:
# - Fornece as dependências nativas necessárias para binários Chromium/Playwright
#   baixados por fora do Nix (ex.: ms-playwright do Hermes agent, Puppeteer, npm
#   playwright-core).
# - Opcionalmente instala `playwright-driver` (playwright test) e os browsers
#   empacotados no nixpkgs para uso determinístico em testes/flakes do Kryonix.
#
# Por quê:
# - No NixOS, binários dinâmicos downloaded (Chromium via npm) não carregam por
#   falta de libs compartilhadas (libglib-2.0, libnss3, etc.). nix-ld resolve
#   isso interceptando o loader ELF e provendo as libs declaradas.
# - Sem este módulo, ferramentas tipo Hermes browser-automation falham com
#   "error while loading shared libraries: libglib-2.0.so.0".
#
# Como:
# - `programs.nix-ld.enable` já é ligado globalmente por modules/nixos/common,
#   este módulo apenas POPULA `programs.nix-ld.libraries` quando a feature é
#   habilitada. Hosts sem a feature ativada continuam com nix-ld vazio (comport.
#   atual, sem regressão).
# - `kryonix.features.browserAutomation.enable = true` no host ativa as libs e
#   seta PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 (evita download surpresa).
# - `installPlaywright = true` (default) adiciona playwright-driver +
#   PLAYWRIGHT_BROWSERS_PATH apontando pro store path.
#
# Riscos:
# - Adicionar ~19 libs ao nix-ld aumenta a imagem do sistema (~80–120 MB). Aceitável
#   em workstations dev; evitar em ISO/servidores.
# - `environment.sessionVariables` é global; PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
#   afeta qualquer invocação de `npx playwright install` no usuário — é o
#   comportamento desejado no NixOS.
# ==============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kryonix.features.browserAutomation;
in
{
  options.kryonix.features.browserAutomation = {
    enable = lib.mkEnableOption ''
      browser automation libraries. Populates programs.nix-ld.libraries with the
      shared libraries required by Chromium/Playwright binaries distributed
      outside nixpkgs (Hermes agent, Puppeteer, npm playwright-core).
    '';

    installPlaywright = lib.mkEnableOption "nixpkgs playwright-driver + browsers" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Sempre que a feature estiver ativa, populamos o nix-ld com libs do Chromium.
      {
        programs.nix-ld.libraries = with pkgs; [
          glib
          gtk3
          atk
          at-spi2-atk
          cups
          libdrm
          dbus
          expat
          cairo
          pango
          alsa-lib
          nspr
          nss
          libxkbcommon
          xorg.libX11
          xorg.libXcomposite
          xorg.libXdamage
          xorg.libXext
          xorg.libXfixes
          xorg.libXrandr
          xorg.libxcb
          libgbm
        ];

        environment.sessionVariables = {
          # Evita que `npx playwright install` (e similares) baixem browsers do nada.
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
        };
      }

      # Opcional: playwright-driver empacotado + browsers do store.
      (lib.mkIf cfg.installPlaywright {
        environment.systemPackages = with pkgs; [
          playwright-driver
        ];

        environment.sessionVariables = {
          # Aponta playwright pra pasta de browsers empacotados.
          # Só faz sentido com installPlaywright = true (default).
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
        };
      })
    ]
  );
}
