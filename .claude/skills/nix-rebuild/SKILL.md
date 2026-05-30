---
name: nix-rebuild
description: Valida e testa a configuração NixOS do Kryonix de forma segura. Use quando o usuário pedir para validar, testar, fazer flake check ou rebuild dos hosts glacier/inspiron. Roda check + build + test, nunca switch sem confirmação.
allowed-tools: Bash(nix flake check:*), Bash(nix build:*), Bash(nix flake show:*), Bash(kryonix test:*), Read, Grep
disable-model-invocation: true
argument-hint: "[host: inspiron|glacier]"
---

# Rebuild seguro

## Estado atual
- Flake check: !`nix flake check --keep-going --impure 2>&1 | tail -15`
- Git status: !`git status --short`

## Passos
1. Se o flake check acima falhou, PARE e reporte os erros com causa-raiz. Não prossiga.
2. Build do toplevel do host informado (default inspiron):
   `nix build .#nixosConfigurations.$ARGUMENTS.config.system.build.toplevel --no-link -L`
3. Se o host for `inspiron`, confirme que NÃO há no closure: rusty-v8, deno, yt-dlp,
   mpv-with-scripts, kalarm (esses devem ficar só no glacier/perfil opcional).
4. Rode `kryonix test` se disponível. Reporte avisos/erros.
5. NUNCA rode `switch` ou `nixos-rebuild switch` — isso exige confirmação humana explícita.
