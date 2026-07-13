# =============================================================================
# Lib: Helper functions para o Kryonix
# Autor: rag (via AI Maintainer)
#
# O que é:
# - Funções auxiliares reutilizáveis para o flake
#
# Por quê:
# - Centraliza lógica compartilhada
# - Facilita manutenção
#
# Como:
# - Importado via outputs.lib no flake
#
# Riscos:
# - Nenhum (apenas helpers)
# =============================================================================
{ lib, ... }:

{
  # Helper para criar módulos NixOS
  mkNixosModule =
    path:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ path ];
    };

  # Helper para criar módulos Home Manager
  mkHomeModule =
    path:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ path ];
    };

  # Helpers de Serviços (Fronteira e Segurança)
  inherit (import ./services.nix { inherit lib; }) mkKryonixService;

  # Pode adicionar mais helpers no futuro
}
