# Desktop: KDE Plasma

O KDE Plasma 6 (Wayland) é o ambiente de desktop principal de longo prazo do
Kryonix. Coexiste com o stack legado Hyprland/Caelestia via seleção por host —
nenhum substitui o outro.

## Seleção (opt-in por host)

O ambiente é escolhido pela opção enum `kryonix.desktop.environment`
(`lib/options.nix`):

```nix
kryonix.desktop.environment = "kde";       # ou "hyprland", ou null (headless)
```

- `hosts/inspiron/default.nix` seleciona `"kde"`.
- O branch correspondente vive em `modules/nixos/desktop/default.nix`, que força
  off os display/desktop managers conflitantes (GDM, gnome, greetd).

## Implementação

| Camada                   | Onde                                                |
| ------------------------ | --------------------------------------------------- |
| Sistema (SDDM/Plasma6)   | `modules/nixos/desktop/kde/default.nix`             |
| Home Manager (orquestra) | `desktop/kde/user.nix`                              |
| Tema visual              | `desktop/kde/theme.nix` + `desktop/kde/kvantum.nix` |
| Color-scheme opt-in      | `desktop/kde/scheme.nix` (ver abaixo)               |
| Tiling                   | `desktop/kde/tiling.nix`                            |
| Atalhos                  | `desktop/kde/keybinds.nix` (ver `SHORTCUTS.md`)     |
| Launcher (Wofi)          | `desktop/kde/launcher.nix`                          |
| Lockscreen               | `desktop/kde/lockscreen.nix` (ver `LOCKSCREEN_THEME.md`) |

A configuração do Plasma é declarativa via **plasma-manager**
(`programs.plasma.*`), já presente como input do flake.

## Estado atual

- KDE Plasma 6 sobre Wayland (SDDM): **Implementado**.
- Autologin opcional (`kryonix.desktop.kde.autoLoginUser`): **Implementado**.
- **Tiling**: **Implementado** via **Krohnkite** (KWin/Script), habilitado por
  `kwinrc [Plugins] krohnkiteEnabled=true` em `tiling.nix`. O pacote
  `kdePackages.krohnkite` é instalado no nível do sistema para o KWin enxergá-lo.
  > Nota: plasma-manager (rev pinada) não tem suporte first-class a Krohnkite
  > (só Polonium), por isso usamos o fallback declarativo via `kwinrc`.
  > Polonium/Bismuth/Krohnkite são tratados como opcionais — sem dependência rígida.
- 10 desktops virtuais nomeados (o 10º = Scratchpad), borderless via window-rules.
- **Painel**: "Floating Island" minimalista (`theme.nix`, painel topo flutuante)
  como fallback até a Kryonix Bar (Rust) assumir.
- **Tema**: **BonaFides Dark** (Global Theme + Kvantum + Aurorae,
  `packages/bonafides-theme.nix`) é o default, com accent azul Kryonix.

## Tema / color-scheme

O preset visual principal do KDE agora é selecionável por
`kryonix.desktop.kde.theme.preset`:

- `"bonafides"` (default): mantém o tema histórico do host.
- `"kryonix-blue-glass-dark"`: preset opt-in Blue Glass escuro.
- `"kryonix-blue-glass-light"`: preset opt-in Blue Glass claro.

O Blue Glass é package-backed e não altera o layout do painel por SVG; a
aparência vem do Plasma Style e o layout continua em `desktop/kde/theme.nix`
via `plasma-manager`. Ver [KRYONIX_BLUE_GLASS.md](KRYONIX_BLUE_GLASS.md).

O esquema de cores é selecionável por `kryonix.desktop.kde.theme.colorScheme`:

- `"bonafides"` (default): esquema azul BonaFides — comportamento atual.
- `"kryonix-dark"`: color-scheme oficial Kryonix com tokens próprios
  (background `#0B0F14`, accent `#38BDF8`). Opt-in; mantém o lookAndFeel/Kvantum
  BonaFides, troca apenas color-scheme + accent. Ver
  [PLASMA_THEME_KRYONIX_DARK.md](PLASMA_THEME_KRYONIX_DARK.md).
