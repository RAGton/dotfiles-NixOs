# Plano REVISADO — Corrigir Stack SDDM + Hyprland (black screen)

> Análise crítica + complementos ao plano original. As correções de diagnóstico
> estão certas; os complementos são sobre **validação real** e **segurança de boot**.

---

## ✅ O que o plano original acertou

1. **Causa raiz correta**: `wayland.compositor = "kwin"` exige `kdePackages.kwin` (plasma6),
   ausente no setup Hyprland-only. SDDM não sobe → black screen.
2. **Default wes
ton correto**: remover a linha equivale a usar weston (standalone, funciona).
3. **mkForce duplicado**: identificou certo o conflito entre `system.nix` e `desktop/default.nix`.

---

## ⚠️ Falhas e riscos do plano original

### FALHA 1 — `nixos-rebuild test` NÃO reproduz o boot

> **Esta é a falha mais perigosa do plano.**

O `test` ativa a config na **sessão atual em execução**, onde você já está logado pela
geração antiga. Mas a falha original aconteceu **no boot** — SDDM iniciando do zero no VT1.

O `systemctl restart display-manager` durante o `test` é um proxy decente, mas NÃO é
idêntico ao boot frio. Diferenças que só aparecem no boot real:
- Ordem de inicialização de DRM/KMS
- Estado do framebuffer antes do SDDM
- Race conditions com o seat do logind

**Complemento obrigatório**: depois do `test` passar, fazer `switch` e **reboot real**
antes de `push`. Só declarar vitória após login gráfico pós-reboot.

### FALHA 2 — Commit mistura categorias (viola o princípio de isolamento)

O commit proposto junta:
- 🔴 Fix crítico: remover kwin (resolve o black screen)
- 🟡 Cosmético: adicionar tema `catppuccin-sddm-corners`
- 🟢 Não relacionado: remover wrapper `mkHyprlandNoNixGL`

Se o sistema quebrar de novo após esse commit, você não sabe **qual** das 3 mudanças
foi a culpada. E o tema do SDDM é um suspeito real — tema mal referenciado faz o SDDM
falhar no boot, exatamente o sintoma que estamos tentando corrigir.

**Complemento obrigatório**: testar PRIMEIRO sem o tema (só o fix do kwin). Confirmar
que o SDDM sobe com o tema default. Só então adicionar o tema custom em commit separado.

### FALHA 3 — Não valida que o tema custom existe e está correto

`catppuccin-sddm-corners` no `systemPackages` instala o tema, mas o **nome interno**
que o SDDM espera em `theme = "..."` pode ser diferente do nome do pacote. Tema
inexistente → SDDM tenta carregar → falha → pode voltar ao black screen.

**Complemento obrigatório**: verificar o nome real do tema instalado antes de referenciá-lo.

---

## 📋 PLANO REVISADO — execução em 2 commits

### COMMIT 1 — Fix crítico isolado (só o que resolve o black screen)

#### Edições em `desktop/hyprland/system.nix`

Bloco SDDM final do commit 1 (SEM tema ainda):

```nix
services.displayManager.sddm = {
  wayland.enable = true;
  # compositor: usa default "weston" (standalone). NÃO usar "kwin" (exige plasma6).
};
```

Remover:
- `enable = lib.mkForce (!config.kryonix.desktop.directLogin.enable);` (duplicado — fica só em `desktop/default.nix`)
- `wayland.compositor = "kwin";` ou `"weston";` (deixar implícito o default)
- `theme = "catppuccin-sddm-corners";` (mover para commit 2)

#### Validação ANTES do build — verificar que weston entra no closure

```bash
# Confirma que o compositor resolvido é weston
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.sddm.wayland.compositor
# → "weston"

# Confirma que weston está disponível (não vai falhar build por pacote ausente)
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.sddm.package --apply 'p: p.name' 2>/dev/null || echo "checar manualmente"

# Eval das opções críticas
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.sddm.enable    # → true
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.gdm.enable     # → false
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.defaultSession # → "hyprland-uwsm"
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.programs.hyprland.withUWSM             # → true
```

#### Verificar que não sobrou referência a kwin/gdm/wrapper

```bash
grep -rn 'kwin\|mkHyprlandNoNixGL\|gdm\.enable' /etc/kryonix/desktop /etc/kryonix/modules \
  --include='*.nix' --exclude-dir='.git' | grep -v '#'
# Esperado: nenhuma linha ativa referenciando kwin como compositor
```

#### Build + test + REBOOT REAL

```bash
# Build sem ativar
nixos-rebuild build --flake /etc/kryonix#inspiron

# Test (rollback automático no próximo boot se travar a sessão atual)
sudo nixos-rebuild test --flake /etc/kryonix#inspiron
systemctl status display-manager   # → active (running), sem restart loop

# ⚠️ CRÍTICO: switch + reboot real para validar o boot path
sudo nixos-rebuild switch --flake /etc/kryonix#inspiron
sudo reboot
```

#### Checklist pós-reboot (o teste que realmente importa)

```
[ ] SDDM greeter aparece no boot (não black screen)
[ ] Login funciona
[ ] Hyprland renderiza (não tela preta após login)
[ ] loginctl session-status → Type: wayland, Seat: seat0
[ ] echo $XDG_SESSION_TYPE → wayland
[ ] Super+T (ou seu bind de terminal) abre terminal
```

#### Commit 1 (só após reboot validado)

```bash
git -C /etc/kryonix add desktop/hyprland/system.nix
git -C /etc/kryonix commit -m "fix: remove kwin compositor do SDDM (causa do black screen)

- Commit 8cdca5e definiu wayland.compositor=kwin (exige plasma6, ausente)
- SDDM não subia → black screen no boot → TTY inacessível
- Remove a linha: default weston é standalone e correto para Hyprland puro
- Remove sddm.enable duplicado (ponto único de verdade em desktop/default.nix)
- Validado por REBOOT REAL: SDDM sobe, Hyprland renderiza
- loginctl → Type:wayland Seat:seat0"

git -C /etc/kryonix pull --rebase
git -C /etc/kryonix push
```

---

### COMMIT 2 — Tema SDDM (separado, só após commit 1 estável)

#### Verificar o nome interno do tema

```bash
# Descobrir o nome real do tema dentro do pacote
nix build /etc/kryonix#legacyPackages.x86_64-linux.catppuccin-sddm-corners --no-link --print-out-paths 2>/dev/null
# Inspecionar a estrutura — o nome do tema é o nome da pasta em share/sddm/themes/
ls $(nix eval --raw nixpkgs#catppuccin-sddm-corners.outPath 2>/dev/null)/share/sddm/themes/ 2>/dev/null \
  || echo "verificar manualmente o nome da pasta do tema"
```

O nome em `theme = "..."` deve ser **exatamente** o nome da pasta em
`share/sddm/themes/`, não o nome do pacote.

#### Adicionar o tema

```nix
services.displayManager.sddm = {
  wayland.enable = true;
  theme = "catppuccin-sddm-corners";  # ← confirmar nome real da pasta primeiro
};

# Garantir que o pacote do tema está nos systemPackages
environment.systemPackages = [ pkgs.catppuccin-sddm-corners ];
```

#### Validar e testar o tema

```bash
nixos-rebuild build --flake /etc/kryonix#inspiron
sudo nixos-rebuild test --flake /etc/kryonix#inspiron
systemctl restart display-manager
# Deslogar e verificar que o greeter aparece COM o tema (não fallback feio nem black screen)
```

Se o greeter aparecer com o tema → commit. Se voltar a black screen → o nome do tema
está errado, reverter para sem tema e investigar o nome correto.

#### Commit 2

```bash
git -C /etc/kryonix add desktop/hyprland/system.nix
git -C /etc/kryonix commit -m "feat: tema catppuccin-sddm-corners no SDDM

- Validado: greeter renderiza com o tema, não cai em fallback
- Nome do tema confirmado em share/sddm/themes/"
git -C /etc/kryonix push
```

---

### COMMIT 3 (opcional) — Remover wrapper mkHyprlandNoNixGL

Isso é uma mudança **independente** do black screen. Em NixOS nativo, `pkgs.hyprland`
direto funciona (nixGL só é necessário em distros não-NixOS). Mas isolar em commit
próprio para rastreabilidade.

```bash
# Validar que hyprland direto funciona
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.programs.hyprland.package --apply 'p: p.name'

git -C /etc/kryonix commit -m "refactor: usa pkgs.hyprland direto (remove wrapper mkHyprlandNoNixGL)

- nixGL desnecessário em NixOS nativo
- Mudança isolada do fix de black screen"
```

---

## 🛟 Plano B — se weston também falhar

Se mesmo com weston o SDDM não subir no boot, a config mais battle-tested é
**SDDM rodando em X11** lançando sessão Wayland do Hyprland:

```nix
services.displayManager.sddm = {
  enable = true;
  wayland.enable = false;   # SDDM greeter em X11
  # Hyprland ainda roda em Wayland — só o GREETER é X11
};
services.xserver.enable = true;
```

Isso elimina toda a categoria de problemas de compositor do greeter Wayland.
O greeter fica em X11 (estável), mas a sessão do usuário (Hyprland) continua Wayland.
Trade-off: greeter um pouco menos bonito, mas zero risco de black screen por compositor.

---

## 🔍 Por que o TTY ficou inacessível (contexto importante)

Black screen que bloqueia até o TTY (`Ctrl+Alt+F2`) é mais grave que SDDM só falhar.
Indica que o SDDM entrou em **loop de restart** segurando o VT1, ou o DRM/KMS travou.

Para mitigar isso no futuro, considerar limitar restarts do display-manager:

```nix
systemd.services.display-manager.serviceConfig = {
  StartLimitburst = 3;
  StartLimitIntervalSec = 60;
  # Após 3 falhas em 60s, para de tentar e libera o VT para TTY
};
```

Isso garante que, se o DM falhar, você consegue chegar ao TTY em vez de ficar preso
no black screen. **Recomendo adicionar isso ao commit 1** como rede de segurança.

---

## Resumo das melhorias sobre o plano original

| Melhoria | Por quê |
|----------|---------|
| Reboot real obrigatório antes do push | `test` não reproduz o boot, que era onde falhava |
| Separar fix / tema / wrapper em commits | Isolar a causa se quebrar de novo |
| Verificar nome interno do tema SDDM | Nome errado → black screen de novo |
| Plano B: SDDM em X11 | Fallback à prova de falha de compositor |
| `StartLimitBurst` no display-manager | Garante acesso ao TTY se o DM falhar |
| Verificar weston no closure | Evitar falha de build por pacote ausente |
