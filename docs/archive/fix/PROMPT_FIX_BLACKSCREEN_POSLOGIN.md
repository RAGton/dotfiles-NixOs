# Prompt: Black Screen APÓS Login (Hyprland não renderiza)

> Situação: SDDM funciona, login funciona, mas após login = tela preta.
> Persiste após reboot. O SDDM/compositor está OK — o problema é o Hyprland
> não renderizando a sessão. Causa provável: mudanças de multi-monitor
> (monitors.nix / kryonix-monitors restore) OU remoção do wrapper NixGL.

---

## IMPORTANTE — distinção do problema

| Sintoma | Significado |
|---------|-------------|
| SDDM não aparecia (black screen no boot) | Era o kwin — JÁ RESOLVIDO |
| SDDM aparece, login OK, depois tela preta | **Hyprland não renderiza — problema ATUAL** |

Não mexer no SDDM. O problema agora é a sessão Hyprland.

---

## FASE 1 — Capturar os logs da sessão que falhou

Estou num TTY ou geração funcional. Preciso ver por que o Hyprland não renderizou.

```bash
# Log do Hyprland da última sessão (a que deu tela preta)
cat ~/.local/share/hyprland/hyprland.log 2>/dev/null | tail -60
# ou
ls -lt ~/.local/share/hyprland/*.log 2>/dev/null

# Logs do boot anterior (-1 = boot que falhou)
journalctl --user -b -1 2>/dev/null | grep -iE 'hyprland|uwsm|exec-once|kryonix-monitors|monitor' | tail -40

# Erros gerais do boot que falhou
journalctl -b -1 -p err 2>/dev/null | tail -30

# Especificamente o que o kryonix-monitors fez
journalctl --user -b -1 2>/dev/null | grep -i 'kryonix-monitors' | tail -20
```

Reportar o que aparecer. Procurar por:
- `exec-once` falhando
- `kryonix-monitors` com erro
- diretiva `monitor=` inválida
- erro de OpenGL/EGL/DRM (indicaria problema do NixGL wrapper)

---

## FASE 2 — Identificar a causa entre os 2 suspeitos

### Suspeito A — monitors.nix / kryonix-monitors restore

O `exec-once = kryonix-monitors restore` pode estar aplicando uma config de
monitor salva que deixa todas as telas desativadas ou com resolução inválida.

```bash
# Ver o estado salvo do monitor (pode estar corrompido)
cat ~/.local/state/kryonix/monitor-mode 2>/dev/null
cat ~/.local/state/kryonix/monitor-* 2>/dev/null

# Ver o que o monitors.nix gera
grep -rn 'monitor=\|workspace=\|exec-once' /etc/kryonix/desktop/hyprland/monitors.nix
cat /etc/kryonix/modules/home-manager/desktop/monitors.nix 2>/dev/null | grep -A3 'monitor\|extraConfig'
```

Se o estado salvo tem algo como `external` ou `internal` que desliga a única
tela ativa do notebook → essa é a causa. O `restore` desliga a tela no boot.

### Suspeito B — remoção do wrapper mkHyprlandNoNixGL

Se os logs mostram erro de OpenGL/EGL/`failed to get EGL display` →
a troca de `mkHyprlandNoNixGL` por `pkgs.hyprland` direto quebrou o rendering.

```bash
grep -rn 'mkHyprlandNoNixGL\|hyprland.package\|nixGL\|nixgl' \
  /etc/kryonix --include='*.nix' --exclude-dir='.git' | grep -v '#'
```

---

## FASE 3 — Correção conforme a causa

### Se for Suspeito A (monitors restore)

**Correção imediata — neutralizar o restore problemático:**

```bash
# Apagar o estado salvo que está quebrando o boot
rm -f ~/.local/state/kryonix/monitor-mode ~/.local/state/kryonix/monitor-*
```

**Correção permanente em `desktop/hyprland/monitors.nix`** — tornar o restore
seguro: nunca desligar a única tela conectada, e tratar estado ausente.

Trocar o `exec-once` por uma versão defensiva:
```nix
wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
  # Restaura monitor de forma segura — fallback se o estado for inválido
  exec-once = ${pkgs.kryonix-monitors}/bin/kryonix-monitors restore || ${pkgs.hyprland}/bin/hyprctl keyword monitor ",preferred,auto,1"
'';
```

E no script `kryonix-monitors restore`, garantir que:
- Se só há 1 monitor conectado, ignora qualquer modo salvo "external"/"internal"
- Se o estado salvo está vazio ou inválido, aplica o fallback `,preferred,auto,1`
- NUNCA roda `monitor=...,disabled` na única tela ativa

### Se for Suspeito B (NixGL/OpenGL)

**Correção em `desktop/hyprland/system.nix`** — garantir aceleração gráfica:

```nix
# Confirmar que o OpenGL/Mesa está habilitado
hardware.graphics.enable = true;        # NixOS 24.11+
# ou hardware.opengl.enable = true;     # versões antigas

programs.hyprland = {
  enable = true;
  withUWSM = true;
  package = pkgs.hyprland;   # direto — OK em NixOS nativo SE hardware.graphics estiver on
};
```

Se ainda falhar, reverter para o wrapper anterior temporariamente até investigar.

---

## FASE 4 — Validar SEM arriscar outro black screen

```bash
# Build
nixos-rebuild build --flake /etc/kryonix#inspiron

# Test — NÃO faz switch ainda
sudo nixos-rebuild test --flake /etc/kryonix#inspiron
```

**Validar a sessão a partir do TTY antes de tentar login gráfico:**

```bash
# Em um TTY, iniciar Hyprland manualmente para ver erros em tempo real
# (só para teste — Ctrl+C ou sair depois)
Hyprland 2>&1 | tee /tmp/hypr-test.log
# Observar se renderiza ou se cospe erro de monitor/EGL
```

Se o Hyprland abrir manualmente do TTY → a config está boa. Sair, fazer switch,
e testar o login pelo SDDM.

---

## FASE 5 — Rede de segurança adicional

Adicionar um bind de emergência no Hyprland que reseta os monitores, caso
trave de novo no futuro:

```nix
# Em hyprland.conf — reset de monitor de emergência
bind = $mainMod CTRL ALT, M, exec, hyprctl keyword monitor ",preferred,auto,1"
```

Assim, se a tela ficar preta mas o Hyprland estiver rodando, `Super+Ctrl+Alt+M`
força todos os monitores pro modo automático seguro.

---

## FASE 6 — Commit (só após login gráfico validado por reboot)

```bash
git -C /etc/kryonix add desktop/hyprland/monitors.nix desktop/hyprland/system.nix
git -C /etc/kryonix commit -m "fix: black screen pós-login — restore de monitor seguro

- kryonix-monitors restore não desliga mais a única tela conectada
- Fallback para monitor=,preferred,auto,1 se estado salvo for inválido
- Bind de emergência Super+Ctrl+Alt+M para reset de monitor
- [se aplicável] hardware.graphics.enable garantido para rendering"
git -C /etc/kryonix push
```

---

## Regras

1. NÃO mexer no SDDM — ele está funcionando
2. Testar Hyprland manualmente do TTY antes de qualquer login gráfico
3. Apagar `~/.local/state/kryonix/monitor-*` é seguro e reversível — fazer primeiro
4. Reboot real obrigatório antes do push
5. Reportar os logs da FASE 1 antes de editar qualquer coisa
6. Se não conseguir identificar a causa em 10 min, reverter o commit do multi-monitor
   inteiro (`git revert 26b763f`) e validar que volta a funcionar
```
