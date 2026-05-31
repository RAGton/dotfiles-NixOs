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
{ inputs, userConfig, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../../lib/options.nix
    ../../modules/nixos/base
    ../../modules/nixos/hardware
    ../../modules/nixos/input
    ../../modules/nixos/audio
    ../../modules/nixos/network
    ../../modules/nixos/programs/kryonix
    ../../modules/nixos/programs/jupyter
    ../../modules/nixos/theming
    ../../modules/nixos/services
    ../../modules/nixos/meta
    ../../modules/nixos/desktop
    ../../features
    ../../profiles
  ];

  # Configuração padrão para o Home Manager integrado ao NixOS
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs userConfig; };
    users.${userConfig.name} = {
      imports = [ ../../modules/home-manager/common ];
    };
  };
}
