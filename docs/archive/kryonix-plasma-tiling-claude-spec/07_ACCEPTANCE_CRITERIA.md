# 07 — Critérios de Aceite

A entrega só pode ser considerada pronta se todos os critérios aplicáveis forem atendidos.

## Funcional

- [ ] Plasma é opt-in.
- [ ] Hyprland/Caelestia não foram removidos.
- [ ] Módulo NixOS avalia.
- [ ] Módulo Home Manager avalia.
- [ ] KWin recebe configuração declarativa.
- [ ] Tiling tem fallback.
- [ ] Tema Kryonix Dark está documentado.
- [ ] Barra/painel tem especificação e implementação mínima ou limitação documentada.
- [ ] Configs Windows são opcionais e não afetam NixOS.

## Segurança

- [ ] Nenhum secret no diff.
- [ ] Nenhum caminho sensível hardcoded sem motivo.
- [ ] Nenhum comando destrutivo executado.
- [ ] Não houve `git add .`.
- [ ] Não mudou `flake.lock` sem justificativa.

## Validação

- [ ] `git diff --check` passou.
- [ ] `nix fmt` passou.
- [ ] `nix flake show --all-systems` passou ou falha foi classificada.
- [ ] `nix flake check --keep-going` passou ou falha foi classificada.
- [ ] build do host afetado passou ou falha foi classificada.
- [ ] docs atualizadas.

## Relatório final

Obrigatório entregar:

```txt
Status:
Arquivos alterados:
O que mudou:
Validação executada:
Resultado dos testes:
Riscos:
Rollback:
Pendências:
```
