---
name: nixos-stability
description: >
  Padrões de qualidade e segurança para modificar configurações NixOS/flake.
  Use esta skill SEMPRE que for editar qualquer arquivo .nix, mudar Display Manager,
  mexer em opções de Wayland/Hyprland/UWSM, atualizar inputs do flake, ou criar
  módulos novos. Também use ao revisar diffs antes de commitar ou ao diagnosticar
  black screen / TTY inacessível após nixos-rebuild. Esta skill define o contrato
  mínimo de qualidade — nenhuma mudança deve ser feita sem seguir este processo.
---

# NixOS Stability — Padrões de Qualidade

Este skill define o processo obrigatório para modificar configurações NixOS de forma
segura. O objetivo é chegar ao `kryonix switch` com confiança, não descobrir que o
sistema quebrou só depois do reboot.

---

## Regra de Ouro

> **Nunca aplique com `switch` sem antes validar com `test` ou `build`.**
> Nunca faça mais de uma mudança de categoria por vez sem validar entre elas.

---

## FASE 0 — Antes de qualquer edição

### 0.1 Ler o estado atual

```bash
# Qual geração está rodando
nixos-version
nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -5

# Qual commit do flake foi a última geração estável
git -C /etc/kryonix log --oneline -10

# Git tree limpa?
git -C /etc/kryonix status --short
```

### 0.2 Registrar ponto de retorno

Antes de qualquer mudança que envolva:
- Display Manager (GDM, SDDM, greetd, lightdm)
- `programs.hyprland.*`
- `security.pam.services.*`
- `services.xserver.*`
- `boot.*` ou `kernel.*`

Anote o número da geração atual:

```bash
# Anota a geração atual — se quebrar, volta com:
# sudo nixos-rebuild switch --rollback
# ou boot → seleciona geração anterior no GRUB
```

### 0.3 Verificar conflitos de mkForce antes de editar

Procurar todas as definições da opção que vai mexer:

```bash
# Exemplo: antes de mudar displayManager
grep -rn 'displayManager\|sddm\|gdm\|greetd\|lightdm' /etc/kryonix \
  --include='*.nix' --exclude-dir='.git' | grep -v '#'
```

Se a opção aparecer em mais de um arquivo com `mkForce`, há risco de conflito silencioso.
Leia `references/mkforce-conflicts.md` antes de prosseguir.

---

## FASE 1 — Edição segura

### 1.1 Uma categoria por commit

| Categoria | Exemplos | Risco |
|-----------|----------|-------|
| Display Manager | GDM→SDDM, wayland.enable | 🔴 Alto — quebra boot |
| PAM / logind | security.pam.services.* | 🔴 Alto — sessão Wayland |
| Hyprland / UWSM | withUWSM, exec-once | 🔴 Alto — tela preta |
| Pacotes / overlays | systemPackages, pkgs.* | 🟡 Médio |
| Home Manager | programas de usuário | 🟢 Baixo |
| Documentação | docs/, SHORTCUTS.md | 🟢 Baixo |

**Nunca misture categorias de risco Alto em um mesmo commit sem validação entre elas.**

### 1.2 Padrões proibidos

```nix
# ❌ PROIBIDO — exec-once sem path absoluto (quebra se PATH não estiver pronto)
exec-once = kryonix-monitors restore

# ✅ CORRETO
exec-once = ${pkgs.kryonix-monitors}/bin/kryonix-monitors restore
# ou
exec-once = ${lib.getExe pkgs.kryonix-monitors} restore
```

```nix
# ❌ PROIBIDO — wayland.compositor sem garantir que o compositor está instalado
services.displayManager.sddm.wayland.compositor = "kwin";
# (kwin só funciona se plasma6 estiver habilitado)

# ✅ CORRETO para stack Hyprland pura
services.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
  # não definir wayland.compositor sem instalar o compositor
};
```

```nix
# ❌ ARRISCADO — mkForce duplo na mesma opção em arquivos diferentes
# system.nix:       services.displayManager.sddm.enable = lib.mkForce false;
# desktop/default:  services.displayManager.sddm.enable = lib.mkForce true;
# → comportamento depende da ordem de merge, imprevisível

# ✅ CORRETO — um único ponto de verdade por opção
# Centralizar no módulo mais específico, remover mkForce dos outros
```

### 1.3 Padrões obrigatórios para Display Manager + Hyprland

Leia `references/display-manager-hyprland.md` para a configuração canônica
de cada DM suportado (SDDM, GDM, greetd) com Hyprland + UWSM.

---

## FASE 2 — Validação antes de aplicar

### 2.1 Avaliação Nix (obrigatório, sem build)

```bash
# Verifica sintaxe e avaliação de todo o flake
nix flake check /etc/kryonix --keep-going 2>&1 | grep -E 'error:|warning:' | head -20

# Confirma valores das opções críticas
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.sddm.enable
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.gdm.enable
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.programs.hyprland.withUWSM
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.programs.hyprland.enable
```

Esperado para stack Hyprland + SDDM:
- `sddm.enable` → `true`
- `gdm.enable` → `false`  
- `hyprland.enable` → `true`
- `hyprland.withUWSM` → `true`

### 2.2 Build sem ativar (obrigatório para mudanças 🔴)

```bash
# Constrói sem aplicar — detecta erros de build mas não reinicia nada
nixos-rebuild build --flake /etc/kryonix#inspiron 2>&1 | tail -20
```

Se o build falhar, **pare aqui**. Corrija antes de avançar.

### 2.3 Test antes de switch (obrigatório para mudanças de DM)

```bash
# Ativa na sessão atual SEM tornar permanente
# Se o sistema travar, o próximo boot usa a geração anterior automaticamente
sudo nixos-rebuild test --flake /etc/kryonix#inspiron
```

Após o `test`:
1. Verifique que o DM subiu: `systemctl status display-manager`
2. Faça logout → login → confirme que Hyprland abre
3. Verifique a sessão: `loginctl session-status`
4. Confirme: `echo $XDG_SESSION_TYPE` → deve ser `wayland`

**Só prossiga para `switch` se todos os 4 pontos acima passaram.**

### 2.4 Checklist obrigatório pós-test

```
[ ] systemctl status display-manager → active (running)
[ ] Login gráfico aparece (SDDM/GDM greeter visível)
[ ] Hyprland inicia após login (não tela preta)
[ ] loginctl session-status → Type: wayland / Seat: seat0
[ ] echo $XDG_SESSION_TYPE → wayland
[ ] Atalhos básicos do Hyprland funcionam (Super+T abre terminal)
[ ] kryonix switch → somente após todos os itens acima ✅
```

---

## FASE 3 — Commit e push

### 3.1 Commit atômico por categoria

```bash
# Verificar o diff antes de adicionar
git -C /etc/kryonix diff --stat

# Adicionar apenas os arquivos relacionados à mudança
git -C /etc/kryonix add desktop/hyprland/system.nix modules/nixos/desktop/default.nix

# Mensagem de commit descritiva
git -C /etc/kryonix commit -m "fix: migra GDM → SDDM para Hyprland

- services.displayManager.sddm.enable = true
- services.displayManager.sddm.wayland.enable = true  
- Remove gdm.enable (incompatível com nixpkgs-unstable atual)
- Validado: loginctl session-status → wayland / seat0"
```

### 3.2 Só push depois de `switch` validado

```bash
git -C /etc/kryonix push
```

Nunca faça push de algo que ainda não passou pelo checklist da Fase 2.

---

## FASE 4 — Diagnóstico quando quebra

Se o sistema ficou com tela preta ou TTY inacessível, leia:
`references/black-screen-recovery.md`

Se o problema é sessão Wayland inválida (Hyprland não inicia mas TTY funciona):
`references/display-manager-hyprland.md`

---

## Referências rápidas

| Problema | Arquivo de referência |
|----------|-----------------------|
| Black screen / TTY bloqueado | `references/black-screen-recovery.md` |
| DM + Hyprland + UWSM | `references/display-manager-hyprland.md` |
| Conflitos de mkForce | `references/mkforce-conflicts.md` |
| Padrões de módulo NixOS | `references/module-patterns.md` |
