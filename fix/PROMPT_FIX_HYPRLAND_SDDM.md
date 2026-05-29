# Prompt: Diagnóstico e Correção — Black Screen / Hyprland Quebrado

> Use este prompt no Claude Code com acesso a `/etc/kryonix`.
> O sistema está na geração funcional anterior. Objetivo: corrigir os commits
> recentes para que `kryonix switch` resulte em sistema estável.

---

## Contexto

Os commits `bc5fdac` (manutenção) e `26b763f` (multi-monitor) mais `8cdca5e`
(GDM→SDDM) quebraram o Hyprland — tela preta, TTY inacessível após reboot.
O usuário voltou para a geração anterior. Precisamos identificar a causa exata
e corrigir de forma cirúrgica.

**Stack esperada:** SDDM → UWSM → Hyprland (Caelestia/DMS)

---

## FASE 1 — Diagnóstico forense (somente leitura)

### 1.1 Comparar o que mudou nos commits problemáticos

```bash
# Ver todos os arquivos mudados nos 3 commits
git -C /etc/kryonix show --stat bc5fdac 26b763f 8cdca5e

# Diff completo de cada arquivo de sistema crítico
git -C /etc/kryonix show bc5fdac -- desktop/hyprland/system.nix
git -C /etc/kryonix show 8cdca5e -- desktop/hyprland/system.nix
git -C /etc/kryonix show 8cdca5e -- modules/nixos/desktop/default.nix
git -C /etc/kryonix show 26b763f -- desktop/hyprland/monitors.nix
```

### 1.2 Auditar o estado atual dos arquivos críticos

Ler na íntegra:
- `desktop/hyprland/system.nix`
- `modules/nixos/desktop/default.nix`
- `desktop/hyprland/monitors.nix`

Verificar especificamente:

**Em `system.nix`:**
- Há `wayland.compositor` definido? Com qual valor?
- `services.xserver.enable` está presente?
- `defaultSession` está definido? Com qual valor?
- Há algum `mkForce` em opções de DM?

**Em `desktop/default.nix`:**
- Como `sddm.enable` e `gdm.enable` são definidos para env `hyprland`?
- Há conflito de `mkForce` com `system.nix`?

**Em `monitors.nix`:**
- O `exec-once` usa path absoluto ou nome de binário?
- O módulo recebe `pkgs` como argumento?

### 1.3 Verificar conflitos de mkForce

```bash
grep -rn 'sddm\|gdm\|greetd\|displayManager' /etc/kryonix \
  --include='*.nix' --exclude-dir='.git' | grep -v '#' | grep 'enable\|mkForce'
```

Se a mesma opção aparece com `mkForce` em mais de um arquivo → conflito.
Reportar cada conflito encontrado.

### 1.4 Avaliar o estado atual do flake

```bash
nix flake check /etc/kryonix --keep-going 2>&1 | grep -E '^error' | head -20

nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.sddm.enable
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.gdm.enable
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.defaultSession
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.programs.hyprland.withUWSM
```

**Reportar o resultado antes de qualquer edição.**

---

## FASE 2 — Correção cirúrgica

Com base no diagnóstico, aplicar as correções na ordem abaixo. Fazer apenas
o mínimo necessário — não refatorar o que não está quebrado.

### 2.1 Corrigir o DM em `desktop/hyprland/system.nix`

O arquivo deve ter **exatamente** esta configuração de DM (adaptar ao padrão existente):

```nix
services.xserver.enable = true;

services.displayManager.sddm = {
  enable = lib.mkForce (!config.kryonix.desktop.directLogin.enable);
  wayland.enable = true;
  # NÃO definir wayland.compositor — kwin não está instalado
};

services.displayManager.defaultSession = "hyprland-uwsm";
```

**Remover qualquer referência a:**
- `services.displayManager.gdm.*`
- `services.displayManager.sddm.wayland.compositor` (a menos que plasma6 esteja habilitado)

### 2.2 Corrigir `modules/nixos/desktop/default.nix`

No bloco `(lib.mkIf (env == "hyprland"))`, garantir:

```nix
services.displayManager.gdm.enable  = lib.mkForce false;
services.displayManager.sddm.enable = lib.mkForce true;
services.desktopManager.gnome.enable = lib.mkForce false;
services.greetd.enable = lib.mkForce false;
```

Não deve haver `mkForce` em `sddm.enable` **também** em `system.nix`
(um só ponto de verdade).

### 2.3 Corrigir `desktop/hyprland/monitors.nix`

Garantir que o `exec-once` usa path absoluto:

```nix
wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
  exec-once = ${pkgs.kryonix-monitors}/bin/kryonix-monitors restore
'';
```

Se o módulo não recebe `pkgs` como argumento, adicionar:
```nix
{ config, lib, pkgs, nhModules, ... }:
```

---

## FASE 3 — Validação obrigatória (não pular)

```bash
# 1. Avaliação pura — sem build
nix flake check /etc/kryonix --keep-going 2>&1 | grep '^error' | head -10

# 2. Confirmar valores
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.sddm.enable
# → true

nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.gdm.enable
# → false

nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.defaultSession
# → "hyprland-uwsm"

nix eval /etc/kryonix#nixosConfigurations.inspiron.config.programs.hyprland.withUWSM
# → true

# 3. Build sem ativar
nixos-rebuild build --flake /etc/kryonix#inspiron

# 4. Test (ativa sem tornar permanente — falha → reboot = geração anterior)
sudo nixos-rebuild test --flake /etc/kryonix#inspiron
```

**Após o `test`, verificar manualmente:**
```bash
systemctl status display-manager
# → active (running), sem restart loops
```

Fazer logout → login pelo SDDM → confirmar que Hyprland abre.

```bash
loginctl session-status
# → Type: wayland, Seat: seat0
```

**Só prosseguir se todos os checks acima passaram.**

---

## FASE 4 — Commit e push

```bash
git -C /etc/kryonix add desktop/hyprland/system.nix \
                         modules/nixos/desktop/default.nix \
                         desktop/hyprland/monitors.nix

git -C /etc/kryonix commit -m "fix: corrige stack SDDM+Hyprland após regressão

- Remove wayland.compositor = kwin (kwin não instalado, causava black screen)
- Centraliza sddm.enable em desktop/default.nix (remove mkForce duplicado)
- exec-once monitors usa path absoluto da derivação
- Validado: sddm=true, gdm=false, session=hyprland-uwsm, withUWSM=true
- Validado: loginctl → Type:wayland Seat:seat0"

git -C /etc/kryonix pull --rebase
git -C /etc/kryonix push
```

---

## Regras invioláveis

1. Não use `nixos-rebuild switch` sem antes passar pelo `test`
2. Não defina `wayland.compositor` sem confirmar que o compositor está instalado
3. Não duplique `mkForce` na mesma opção em arquivos diferentes
4. Todo `exec-once` com pacote do overlay usa `${pkgs.pacote}/bin/cmd`
5. Reporte o diff completo de cada arquivo antes de commitar
6. Não faça push de nada que não passou pelo checklist de validação

---

## Se o build ainda falhar após as correções

Verificar se há outros erros não relacionados ao DM:

```bash
nixos-rebuild build --flake /etc/kryonix#inspiron --show-trace 2>&1 | \
  grep -A3 'error:' | head -40
```

Cada erro deve ser tratado separadamente — não misturar correções de categorias
diferentes no mesmo commit.
