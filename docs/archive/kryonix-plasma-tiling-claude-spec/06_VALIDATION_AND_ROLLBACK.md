# 06 — Validação e Rollback

## Validação básica obrigatória

```bash
cd /etc/kryonix

git status --short
git diff --stat
git diff --check

nix fmt
nix flake show --all-systems
nix flake check --keep-going
```

## Build sem aplicar

Para host afetado:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link -L --show-trace
```

Preferir wrapper Kryonix se disponível:

```bash
kryonix check
kryonix diff
```

## Aplicação segura

Não rodar `switch` direto.

Primeiro:

```bash
kryonix test
```

Depois, se aprovado:

```bash
kryonix boot
```

Só usar `kryonix switch` com aprovação explícita.

## Validação Home Manager

```bash
kryonix home
# ou, se o projeto usa home-manager diretamente:
home-manager switch --flake .#<user>@<host>
```

## Validação Plasma/KWin

```bash
echo "$XDG_SESSION_TYPE"
echo "$WAYLAND_DISPLAY"
echo "$DISPLAY"

qdbus6 org.kde.KWin /KWin reconfigure || true
journalctl --user -b --no-pager -n 200 | rg -i "kwin|plasma|kde|kconfig|failed|error" || true
```

## Rollback

### NixOS

```bash
sudo nixos-rebuild switch --rollback
```

Preferir fluxo do Kryonix, se existir:

```bash
kryonix boot --rollback
```

### Git

Se não houve commit:

```bash
git diff
git restore <arquivos>
```

Se houve commit local:

```bash
git revert <commit>
```

### Home Manager

```bash
home-manager generations
home-manager switch --generation <id>
```

ou usar wrapper do projeto se existir.

## Riscos

- Quebrar login gráfico.
- Sessão Plasma não subir.
- KWin não carregar plugin.
- Atalhos conflitarem.
- Home Manager sobrescrever `kwinrc` interativo.
- Tema SDDM quebrar tela de login.
- Restart de KWin fechar janelas.
- Ativar Plasma no host errado.
