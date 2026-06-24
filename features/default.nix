# =============================================================================
# Features Manager: Auto-import de features baseado em opções
# Autor: rag (via AI Maintainer)
#
# O que é:
# - Auto-importa módulos de features quando habilitados via opções
# - Centraliza gerenciamento de features
#
# Por quê:
# - Features são opt-in via opções
# - Cada feature é auto-contida
# - Fácil adicionar novas features
#
# Como:
# 1. Features definem suas próprias opções (kryonix.features.*)
# 2. Este manager importa automaticamente quando enable = true
# 3. Hosts apenas habilitam: kryonix.features.gaming.enable = true
# =============================================================================
{ config, lib, ... }:

{
  # Importa todos os módulos de features
  # Cada um define suas próprias opções e só ativa quando enable = true
  imports = [
    ./workstation.nix
    ./cpu.nix
    ./gpu.nix
    ./gaming.nix
    ./openrgb.nix
    ./virtualization.nix
    ./development.nix
    ./ai.nix
    ./remote.nix
    ./remote-desktop.nix
    ./f5-tts-server
  ];

  # Configuração base comum a todas as features
  config = {
    # Assertions gerais (se necessário)
    assertions = [
      # Add global feature assertions here if needed
    ];
  };
}
