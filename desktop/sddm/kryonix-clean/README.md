# Kryonix SDDM Clean

Tema SDDM opt-in do Kryonix, separado da camada Plasma.

## Objetivo visual

- moderno e sobrio;
- azul discreto;
- glass leve com fallback visual sem blur real;
- card central limpo;
- alta legibilidade.

## Estrutura

```txt
desktop/sddm/kryonix-clean/
├── Main.qml
├── metadata.desktop
├── theme.conf
└── assets/
    ├── avatar-placeholder.svg
    ├── background-dark.svg
    ├── background-light.svg
    └── logo.svg
```

## Preview local

```bash
THEME_PATH="$(nix build .#kryonix-sddm-theme --no-link --print-out-paths)/share/sddm/themes/kryonix-clean"
sddm-greeter --test-mode --theme "$THEME_PATH"
```

Se o binario local for `sddm-greeter-qt6` ou `sddm-greeter6`, use o nome
disponivel no host.
