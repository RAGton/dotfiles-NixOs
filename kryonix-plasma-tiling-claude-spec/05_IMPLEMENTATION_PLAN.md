# 05 — Plano de Implementação

## Fase 0 — Auditoria

Objetivo: entender o repo real.

Comandos:

```bash
cd /etc/kryonix
git status --short
git diff --stat
git submodule status --recursive

rg -n "plasma|kde|kwin|sddm|displayManager|desktopManager|hyprland|caelestia|theme|bar|panel" \
  flake.nix hosts modules profiles features home desktop packages docs context 2>/dev/null || true
```

Entrega da fase:

- mapa dos arquivos relevantes;
- padrão atual de módulos;
- onde encaixar Plasma sem refatorar tudo.

## Fase 1 — Módulo Plasma opt-in

Criar módulo NixOS para habilitar Plasma sem ativar por padrão.

Aceite:

- build avalia;
- opção existe;
- Hyprland/Caelestia continuam intactos.

## Fase 2 — Home Manager Plasma/KWin

Criar módulo Home Manager para:

- kwinrc;
- kdeglobals;
- recarga KWin;
- pacotes opcionais;
- tiling básico.

Aceite:

- `home-manager` avalia;
- arquivos gerados no XDG config;
- sem hardcode desnecessário.

## Fase 3 — Tema Kryonix Dark

Criar assets e configs mínimos:

- color scheme;
- fonts;
- cursor/icons;
- wallpaper placeholder;
- painel/barra;
- docs.

Aceite:

- tema aplicável;
- fallback se pacote ausente;
- documentação clara.

## Fase 4 — Windows tiling configs

Adicionar configs opcionais para Windows:

- Komorebi;
- whkd;
- GlazeWM;
- README.

Aceite:

- sem afetar build NixOS;
- configs legíveis;
- keybindings alinhados com Linux.

## Fase 5 — Docs e validação

Criar documentação final:

```txt
docs/desktop/PLASMA_KWIN_DECLARATIVE.md
docs/desktop/PLASMA_THEME_KRYONIX_DARK.md
docs/desktop/WINDOWS_TILING.md
```

Rodar validações.

## Plano de commits

1. `feat(plasma): add opt-in Plasma desktop module`
2. `feat(home): add declarative Plasma KWin tiling profile`
3. `feat(theme): add Kryonix Dark Plasma theme skeleton`
4. `docs(desktop): document Plasma and Windows tiling workflow`

Não fazer commit sem pedido explícito do usuário.
