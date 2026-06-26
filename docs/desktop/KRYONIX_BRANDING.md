# Kryonix Branding

Camada canônica de branding reutilizável do Kryonix para KDE, SDDM e
wallpapers.

## O que é

`desktop/branding/kryonix/` agora é a fonte de verdade para:

- paleta oficial;
- wallpapers oficiais;
- logo e mark;
- prompts de mascote e wallpaper;
- design tokens.

## Packages

- `kryonix-branding`
- `kryonix-plasma-theme`
- `kryonix-sddm-theme`

## Outputs

`kryonix-branding` instala:

- `share/kryonix/branding/`
- `share/backgrounds/kryonix/`
- `share/pixmaps/kryonix/`

## Ativacao KDE Blue Glass

```nix
kryonix.desktop.kde.theme.preset = "kryonix-blue-glass-dark";
```

ou:

```nix
kryonix.desktop.kde.theme.preset = "kryonix-blue-glass-light";
```

## Ativacao SDDM Clean

```nix
kryonix.desktop.sddm.theme.preset = "kryonix-clean";
```

## Defaults

- KDE default continua `bonafides`
- SDDM default continua `default`

## Rollback

```nix
kryonix.desktop.kde.theme.preset = "bonafides";
kryonix.desktop.sddm.theme.preset = "default";
```

## Onde ficam os wallpapers

- fonte canônica: `desktop/branding/kryonix/wallpapers/`
- package runtime: `${pkgs.kryonix-branding}/share/backgrounds/kryonix/`

## Onde ficam prompts

- `desktop/branding/kryonix/assets/mascot-concept.md`
- `desktop/branding/kryonix/assets/wallpaper-prompts.md`

## Limitacoes

- o branding comum ainda nao migra o pack legado `kryonix-wallpapers`
- o tema SDDM `kryonix-aurora` segue legado e separado
- nao houve `switch` nem teste runtime no host nesta entrega

## Validacao

```bash
git diff --check
nix flake show --all-systems
nix build .#kryonix-branding --no-link -L --show-trace
nix build .#kryonix-plasma-theme --no-link -L --show-trace
nix build .#kryonix-sddm-theme --no-link -L --show-trace
nix flake check --keep-going
```
