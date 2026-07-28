# =============================================================================
# Module: kryonix.services.aiServer — entrypoint
#
# O que é:
# - Compõe `options.nix` e `assertions.nix`. Nenhuma configuração (`config = { }`
#   produzindo efeitos colaterais) é declarada aqui neste PR: o módulo nasce
#   puramente declarativo e inerte quando `enable = false`.
#
# Por quê:
# - Forçar entrypoint fininho mantém o esqueleto auditável e reversível.
#   Toda ativação real (systemd, users, sudo whitelist, firewall) virá em
#   PRs numerados (PR 2 = integração, PR 3 = identity, PR 4 = helper,
#   PR 5 = kryx-cli, PR 6 = profile, PR 7 = Glacier, PR 8 = Ollama→llama-cpp).
#
# Caminho canônico de incorporação:
#   modules/nixos/services/default.nix  →  imports = [ ./ai-server ];
# =============================================================================
{
  imports = [
    ./options.nix
    ./assertions.nix
  ];
}
