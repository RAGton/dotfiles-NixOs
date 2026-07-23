{ self, inputs }:
{
  nixosModules = {
    # Opções do namespace kryonix.* (sem implementation)
    options =
      { ... }:
      {
        imports = [ ../lib/options.nix ];
      };

    # Módulo de boot (Silent Boot, Plymouth, etc)
    boot =
      { ... }:
      {
        imports = [ ../modules/nixos/boot ];
      };

    # Base comum compartilhada (nix settings, rede, locale, pacotes base)
    # Equivale ao que hosts/common provê — downstream importa como módulo
    common =
      { ... }:
      {
        imports = [ ../hosts/common ];
      };

    # Default: opções + base comum — ponto de entrada principal para downstream
    default =
      { ... }:
      {
        imports = [
          ../lib/options.nix
          ../hosts/common
        ];
      };

    # Features opt-in do Kryonix (desktop, gamer, ai, servidores, etc.)
    features =
      { ... }:
      {
        imports = [ ../modules/nixos/features ];
      };

    # Perfis isolados para patching dinâmico
    profile-gamer =
      { ... }:
      {
        imports = [ ../profiles/workstation-gamer.nix ];
      };
    profile-dev-rust =
      { ... }:
      {
        imports = [ ../profiles/dev/rust.nix ];
      };

    # Modulos para ISO modular
    installer-core =
      { ... }:
      {
        imports = [ ../modules/nixos/installer ];
      };

    full-profile =
      { ... }:
      {
        imports = [
          ../lib/options.nix
          ../hosts/common
          ../profiles/default.nix
        ];
      };

    # Ecossistema Node (PXE, Diskless, Think Server, Instalador)
    node-client =
      { ... }:
      {
        imports = [ ../modules/node/core/client ];
      };

    node-server =
      { ... }:
      {
        imports = [ ../modules/node/core/server ];
      };

    node-think =
      { ... }:
      {
        imports = [ ../modules/node/think/think-server.nix ];
      };

    node-installer =
      { ... }:
      {
        imports = [ ../modules/node/installer ];
      };

    # Kryonix Guard — bloqueia acesso direto a nixos-rebuild/nh/nix
    cli-lockdown =
      { ... }:
      {
        imports = [ ../modules/nixos/lib/cli-lockdown ];
      };

    # Service Providers (contratos de injeção em /etc)
    services-node =
      { ... }:
      {
        imports = [ ../modules/services/node/default.nix ];
      };
  };

  homeManagerModules = {
    # Features opt-in do Kryonix (shell, dev, editor, etc.)
    features =
      { ... }:
      {
        imports = [ ../modules/home-manager/features ];
      };

    # Base HM compartilhada (programas, serviços, aliases comuns)
    common =
      { nhModules, ... }:
      {
        imports = [ ../modules/home-manager/common ];
      };

    # Desktop Hyprland completo (user.nix como orquestrador)
    hyprland =
      { nhModules, ... }:
      {
        imports = [ ../desktop/hyprland/user.nix ];
      };

    # Integração Caelestia Shell (scheme, settings, activation)
    caelestia =
      { ... }:
      {
        imports = [ ../desktop/hyprland/rice/caelestia-config.nix ];
      };

    # Desktop KDE Plasma 6 completo (ambiente principal de longo prazo).
    # Traz o módulo HM do plasma-manager + o orquestrador desktop/kde/user.nix.
    kde =
      { ... }:
      {
        imports = [
          inputs.plasma-manager.homeModules.plasma-manager
          ../desktop/kde/user.nix
        ];
      };

    # Shell backend option (kryonix.shell.backend)
    shell-backend =
      { ... }:
      {
        imports = [ ../desktop/hyprland/shell-backend.nix ];
      };

    # Default: base HM comum
    default =
      { nhModules, ... }:
      {
        imports = [ ../modules/home-manager/common ];
      };
  };
}
