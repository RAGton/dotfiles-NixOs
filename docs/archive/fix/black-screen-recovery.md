# Recuperação de Black Screen / TTY Inacessível

## Sintoma: tela preta após reboot, TTY não responde

### Passo 1 — Forçar acesso ao TTY

```
Ctrl+Alt+F2   (ou F3, F4 — tente todos)
Ctrl+Alt+F1   (volta pro display manager)
```

Se nenhum funcionar: o sistema provavelmente está travado no boot
antes do login. Vá para o Passo 2.

### Passo 2 — Boot em geração anterior pelo GRUB

1. Reiniciar (power button se necessário)
2. Durante o boot, segurar `Shift` (BIOS) ou `Esc` (UEFI) para abrir o GRUB
3. Selecionar **"NixOS — All configurations"**
4. Escolher a **segunda geração** (a que funcionava antes)
5. Logar normalmente

### Passo 3 — Identificar o que quebrou

Já dentro do sistema funcional:

```bash
# Ver o diff entre a geração atual e a anterior
nix store diff-closures \
  /nix/var/nix/profiles/system-$(( $(readlink /nix/var/nix/profiles/system | grep -oP '\d+') - 1 ))-link \
  /nix/var/nix/profiles/system

# Ver os logs do boot que quebrou
journalctl -b -1 -p err | head -50

# Ver logs do display manager especificamente
journalctl -b -1 -u display-manager | tail -30

# Ver logs do Hyprland (se chegou a iniciar)
journalctl -b -1 --user -u hyprland | tail -30
```

### Passo 4 — Causas mais comuns e correções

#### A) SDDM não sobe: `wayland.compositor = "kwin"` sem plasma6

```bash
# Confirmar causa
journalctl -b -1 -u display-manager | grep -i "kwin\|compositor\|failed"
```

Correção em `/etc/kryonix/desktop/hyprland/system.nix`:
```nix
# Remover a linha:
wayland.compositor = "kwin";
# Manter apenas:
services.displayManager.sddm.wayland.enable = true;
```

#### B) TTY travado: display manager em loop de crash

```bash
# Verificar se display-manager está crashando em loop
journalctl -b -1 -u display-manager -n 50 | grep "Start request\|Stopped\|Failed"
```

Correção temporária para acessar o sistema:
```bash
# Para o display manager e abre TTY
sudo systemctl stop display-manager
# Agora você tem o TTY puro para editar e reconstruir
```

#### C) exec-once sem path absoluto

O Hyprland trava ao tentar executar um binário que não está no PATH durante o boot.

```bash
# Ver logs do Hyprland
cat ~/.local/share/hyprland/hyprland.log | grep -i "error\|failed\|exec"
# ou
journalctl --user -b -1 | grep -i "hyprland\|exec-once" | tail -20
```

Correção: substituir todos os `exec-once` por paths absolutos de derivação.

#### D) mkForce conflict — opção indefinida por ordem de merge

```bash
# Verificar valor real que foi avaliado na geração quebrada
nix eval /nix/var/nix/profiles/system#config.services.displayManager.sddm.enable 2>/dev/null
```

Se diferente do esperado, há conflito de mkForce. Ver `references/mkforce-conflicts.md`.

### Passo 5 — Reconstruir com a correção

```bash
# Sempre testar antes de switch
sudo nixos-rebuild test --flake /etc/kryonix#inspiron

# Verificar que o DM subiu
systemctl status display-manager

# Só então aplicar permanentemente
sudo nixos-rebuild switch --flake /etc/kryonix#inspiron
```

---

## Sintoma: login loop (entra e volta para o greeter)

Causa: UWSM não consegue criar sessão Wayland válida.

```bash
# Diagnóstico após login bem-sucedido no TTY
loginctl session-status
# Se mostrar Class: manager e Seat: (nenhum) → problema de PAM
```

Solução: configuração PAM do display manager. Ver `references/display-manager-hyprland.md`.

---

## Comandos de emergência úteis

```bash
# Voltar para geração anterior sem reboot
sudo nixos-rebuild switch --rollback

# Listar gerações disponíveis
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Ativar geração específica (ex: 42)
sudo nix-env --switch-generation 42 --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```
