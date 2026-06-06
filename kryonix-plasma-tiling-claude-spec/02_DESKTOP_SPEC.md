# 02 — Especificação: KDE Plasma/KWin declarativo no NixOS

## Objetivo

Criar uma camada Plasma/KWin decente, modular e declarativa para o Kryonix, sem quebrar o desktop atual.

## Resultado esperado

Uma implementação opt-in que permita:

```nix
kryonix.desktop.plasma.enable = true;
kryonix.desktop.plasma.tiling.enable = true;
kryonix.desktop.plasma.theme.enable = true;
kryonix.desktop.plasma.theme.name = "kryonix-dark";
```

ou estrutura equivalente compatível com o padrão real do repositório.

## Requisitos funcionais

### Plasma base

- Habilitar Plasma 6 de forma declarativa.
- Usar display manager compatível com o canal atual do `nixpkgs`.
- Não ativar Plasma globalmente em todos os hosts.
- Não remover Hyprland/Caelestia.
- Não mudar sessão padrão do usuário sem opção explícita.

### KWin tiling

Prioridade:

1. Usar tiling nativo do KWin/Plasma quando possível.
2. Se usar plugin externo, encapsular como opção.
3. Tratar Polonium/Bismuth/Krohnkite como dependências opcionais e potencialmente instáveis.
4. Não depender de plugin arquivado sem fallback.
5. Configurar `kwinrc` e shortcuts via Home Manager quando possível.
6. Usar `onChange` ou serviço user para `qdbus6 org.kde.KWin /KWin reconfigure`.

### Home Manager

Criar módulo Home Manager para:

- `xdg.configFile."kwinrc"`;
- `xdg.configFile."kdeglobals"`;
- notas/arquivo para `kglobalshortcutsrc`;
- serviço user opcional para recarregar KWin;
- pacotes KDE extras necessários.

## Estrutura sugerida

Ajuste conforme o repo real:

```txt
modules/nixos/desktop/plasma/default.nix
modules/home/desktop/plasma/default.nix
modules/home/desktop/plasma/tiling.nix
modules/home/desktop/plasma/theme.nix
desktop/plasma/themes/kryonix-dark/
desktop/plasma/kwin/
docs/desktop/PLASMA_KWIN_DECLARATIVE.md
```

Se o projeto usa outra estrutura, siga o padrão real.

## Não fazer

- Não apagar `desktop/hyprland`.
- Não substituir Caelestia por Plasma.
- Não ativar no `inspiron` ou `glacier` sem uma opção clara.
- Não escrever configuração mutável manual em `~/.config` sem Home Manager.
- Não usar script shell solto fora do Nix.
- Não forçar `kwin_wayland --replace` automaticamente como default.

## Diagnóstico que deve ser documentado

```bash
echo "$XDG_SESSION_TYPE"
echo "$WAYLAND_DISPLAY"
echo "$DISPLAY"

systemctl --user status plasma-kwin_wayland.service --no-pager || true
journalctl --user -b --no-pager -n 200 | rg -i "kwin|plasma|kde|sddm|wayland|dbus" || true

kcmshell6 --list | rg -i "kwin|shortcut|style|theme|color" || true
kpackagetool6 --type=KWin/Script --list || true
qdbus6 org.kde.KWin /KWin reconfigure || true
```
