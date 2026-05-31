# =============================================================================
# Profiles Manager
# Autor: rag (via AI Maintainer)
#
# Importa todos os profiles disponíveis.
# Cada profile é ativado via opções `kryonix.profiles.*`.
#
# Nota:
# - Profiles não devem escolher desktop environment diretamente.
# - Desktop é escolhido via `kryonix.desktop.environment`.
# =============================================================================
{ ... }:
{
  imports = [
    ./desktop.nix
    ./laptop.nix
    ./vm.nix
    ./dev
    ./university
    ./ti
    ./server-ai.nix
    ./workstation-gamer.nix
    ./virtualization.nix
    ./tools.nix
    # Perfis específicos do Glacier (base/ai/gamer com separação limpa)
    ./glacier-base.nix
    ./glacier-ai.nix
    ./glacier-gamer.nix
  ];
}
