# ==============================================================================
# Módulo: hosts/common (agregador de composição NixOS)
# Autor: Gabriel Aguiar Rocha (RAGton) + Codex
# Data: 2026-03-12
#
# O que é:
# - Ponto único de importação para tudo que é compartilhado entre hosts NixOS.
# - Mantém os hosts (inspiron, glacier, iso) focados em hardware/partições/boot.
#
# Por quê:
# - Reduz duplicação de imports entre hosts.
# - Facilita troubleshooting porque a arquitetura fica previsível por camadas.
#
# Como:
# - Encadeia opções, módulos de base/sistema, features e profiles.
# - Expõe a seleção de desktop via `kryonix.desktop.environment`.
# ==============================================================================
{
  inputs,
  userConfig,
  outputs,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../../lib/options.nix
    ../../modules/nixos/common
    ../../modules/nixos/hardware
    ../../modules/nixos/input
    ../../modules/nixos/audio
    ../../modules/nixos/network
    ../../modules/nixos/programs/kryonix
    ../../modules/nixos/programs/jupyter
    ../../modules/nixos/branding/kryonix
    ../../modules/nixos/services
    ../../modules/nixos/meta
    ../../modules/nixos/desktop
    ../../modules/kernel/zen.nix
    ../../modules/nixos/features
    ../../modules/nixos/security
    ../../profiles
  ];

  # Aplica overlays do repositório no nixpkgs do host
  nixpkgs.overlays = [
    outputs.overlays.stable-packages
    outputs.overlays.xeus-cling-no-checks
    outputs.overlays.codex-overlay
    outputs.overlays.kryonix-installer-tools
  ];

  nixpkgs.config.allowUnfree = true;

  boot.supportedFilesystems = [ "zfs" ];

  # Configuração padrão para o Home Manager integrado ao NixOS
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    extraSpecialArgs = {
      inherit inputs userConfig;
      nhModules = "${inputs.self}/modules/home-manager";
    };
    users.${userConfig.name} = {
      imports = [ ../../modules/home-manager/common ];
    };
  };
}
