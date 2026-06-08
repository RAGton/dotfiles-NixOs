# 01 — Contexto do Projeto Kryonix

## Mandato

Você está trabalhando no repositório `/etc/kryonix`.

Kryonix é uma plataforma NixOS declarativa com flakes, hosts, perfis Home Manager, módulos, overlays, pacotes e CLI própria `kryonix`.

## Estado arquitetural conhecido

- `inspiron`: workstation/cliente.
- `glacier`: servidor IA/Brain/Ollama/LightRAG/Neo4j/MCP e workstation/gaming.
- Desktop atual: Hyprland + Caelestia.
- CLI oficial: `kryonix`.
- Repositório operacional: `/etc/kryonix`.

## Regras absolutas

1. Código real vence documentação.
2. Leia o repositório antes de alterar.
3. Não invente arquivos existentes.
4. Não rode `switch`, `boot`, `disko`, `mkfs`, `format-*`, `install-system`, `reboot` ou `shutdown` sem aprovação explícita.
5. Não use `git add .`.
6. Não altere `flake.lock` sem necessidade real.
7. Não exponha secrets.
8. Não remova Hyprland/Caelestia para corrigir Plasma.
9. Não faça mudança global se puder ser opção opt-in.
10. Só declare pronto com validação.

## Prioridade técnica

A implementação deve ser declarativa em NixOS/Home Manager.

Evite scripts soltos. Se precisar de script, ele deve ser empacotado ou gerado por Nix/Home Manager, com escopo claro.

## Diretórios esperados a investigar

```txt
flake.nix
hosts/
hosts/common/
modules/nixos/
profiles/
features/
home/
desktop/
desktop/hyprland/
packages/
docs/
docs/ai/
context/
scripts/
```

## Comandos obrigatórios de auditoria inicial

```bash
cd /etc/kryonix

git status --short
git diff --stat
git submodule status --recursive

find . -maxdepth 3 -type f \( -name '*.nix' -o -name '*.md' \) | sort | sed 's#^./##' | head -300

rg -n "plasma|kde|kwin|sddm|displayManager|desktopManager|hyprland|caelestia|theme|bar|panel|waybar|astal|ags" \
  flake.nix hosts modules profiles features home desktop packages docs context 2>/dev/null || true
```
