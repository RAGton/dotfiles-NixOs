# Tema: Kryonix Dark (color-scheme opt-in)

Color-scheme oficial do Kryonix para o KDE Plasma 6, com a identidade visual
própria (dark clean, azul gelo / ciano como accent, grafite). É **opt-in**: não
substitui o tema default (BonaFides Dark) — apenas troca o **color-scheme** e o
**accent**, mantendo o Global Theme / Kvantum / Aurorae BonaFides como base.

## Tokens

| Token         | Hex       | RGB           | Uso principal                          |
| ------------- | --------- | ------------- | -------------------------------------- |
| background    | `#0B0F14` | `11,15,20`    | Window/View BackgroundNormal           |
| surface       | `#111827` | `17,24,39`    | Button/Header/WM ativo                 |
| surface-alt   | `#1F2937` | `31,41,55`    | Backgrounds alternados                 |
| border        | `#334155` | `51,65,85`    | Separadores / blend inativo            |
| text          | `#E5E7EB` | `229,231,235` | ForegroundNormal                       |
| text-muted    | `#94A3B8` | `148,163,184` | ForegroundInactive                     |
| accent        | `#38BDF8` | `56,189,248`  | DecorationFocus, Selection, AccentColor|
| accent-strong | `#0EA5E9` | `14,165,233`  | DecorationHover                        |
| danger        | `#EF4444` | `239,68,68`   | ForegroundNegative                     |
| warning       | `#F59E0B` | `245,158,11`  | ForegroundNeutral                      |
| success       | `#22C55E` | `34,197,94`   | ForegroundPositive                     |

## Como ativar

No host (ex.: `hosts/inspiron/default.nix`):

```nix
kryonix.desktop.kde.theme.colorScheme = "kryonix-dark";   # default: "bonafides"
```

Depois aplique o Home Manager pelo fluxo Kryonix (sem `switch` direto):

```bash
kryonix home        # ou kryonix test/boot conforme o fluxo do host
```

## Como funciona

- **Opção NixOS**: `kryonix.desktop.kde.theme.colorScheme`
  (`modules/nixos/desktop/kde/default.nix`), enum `bonafides | kryonix-dark`,
  default seguro `bonafides`.
- **Geração do esquema**: `desktop/kde/scheme.nix` escreve **sempre**
  `~/.local/share/color-schemes/KryonixDark.colors` (formato `.colors` do Plasma 6,
  montado a partir dos tokens acima). Assim o esquema também aparece em
  *System Settings → Colors* para seleção manual.
- **Ativação**: quando `colorScheme = "kryonix-dark"`, o módulo força
  `programs.plasma.workspace.colorScheme = "KryonixDark"` e o
  `kdeglobals General.AccentColor = 56,189,248` (sobrepõem os valores BonaFides
  via `lib.mkForce`).

## Fallback e segurança

- Com `bonafides` (default), o `.colors` fica em disco mas **não é ativado** — o
  esquema azul BonaFides do `theme.nix` prevalece. Nada muda no host atual.
- Chaves desconhecidas no `.colors` são ignoradas pelo KWin; no pior caso o
  Plasma cai no esquema default — sem quebra de sessão.
- **Não remove** Hyprland/Caelestia nem o tema BonaFides: lookAndFeel, Kvantum e
  decoração Aurorae continuam vindo do `bonafides-theme`.

## Rollback

```bash
# basta voltar a opção para o default e reaplicar o HM:
kryonix.desktop.kde.theme.colorScheme = "bonafides";
```

Ou `git restore desktop/kde/scheme.nix` + remover o import em `desktop/kde/user.nix`
se quiser reverter por completo (nada é commitado automaticamente).
