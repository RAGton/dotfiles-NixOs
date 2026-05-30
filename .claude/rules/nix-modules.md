---
paths:
  - "modules/**/*.nix"
  - "hosts/**/*.nix"
  - "profiles/**/*.nix"
  - "features/**/*.nix"
  - "lib/options.nix"
---
# Regras para módulos NixOS do Kryonix
- Toda opção nova: `lib.mkOption` com `type` explícito e `default` seguro (`enable = false`).
- Namespace público sempre `kryonix.*`; aliases legados são temporários.
- Condicionais via `lib.mkIf`, nunca `if/then` no nível de atributo.
- Sistema vs usuário separados: hardware/serviços no NixOS; config de usuário no Home Manager.
- Nada de secret literal. Nada que puxe build pesado para o closure do inspiron.
