# Kryonix Branding

Camada canônica de identidade visual reutilizável do Kryonix.

## Objetivo

Centralizar:

- paleta oficial;
- wallpapers oficiais;
- logo e mark;
- prompts de mascote e wallpaper;
- design tokens;
- assets reaproveitados por KDE/Plasma e SDDM.

## Estrutura

```txt
desktop/branding/kryonix/
├── README.md
├── palette.nix
├── colors.md
├── design-tokens.json
├── assets/
│   ├── logo.svg
│   ├── mark.svg
│   ├── mascot-concept.md
│   └── wallpaper-prompts.md
└── wallpapers/
    ├── kryonix-clean-dark.svg
    ├── kryonix-clean-light.svg
    ├── kryonix-blue-glass-dark.svg
    └── kryonix-blue-glass-light.svg
```

## Consumidores

- `packages/kryonix-branding.nix`
- `packages/kryonix-plasma-theme.nix`
- `packages/kryonix-sddm-theme.nix`
- `desktop/kde/theme.nix`
- `desktop/kde/scheme.nix`

## Notas

- esta camada nao troca defaults sozinha;
- `BonaFides` continua default no KDE;
- `kryonix-clean` continua opt-in no SDDM;
- `kryonix-blue-glass-*` continua opt-in no KDE.
