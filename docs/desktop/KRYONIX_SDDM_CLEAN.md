# Kryonix SDDM Clean

Preset SDDM opt-in do Kryonix com foco em visual moderno, limpo e profissional,
sem exagero futurista.

## Objetivo visual

- azul discreto;
- glass leve;
- card central limpo;
- cantos arredondados;
- wallpaper suave;
- alta legibilidade;
- sem RGB gamer;
- sem animacao excessiva.

## Estrutura

```txt
desktop/sddm/kryonix-clean/
├── Main.qml
├── metadata.desktop
├── theme.conf
├── README.md
└── assets/
    ├── avatar-placeholder.svg
    ├── background-dark.svg
    ├── background-light.svg
    └── logo.svg
```

## Comportamento tecnico

- QML simples, sem dependencia de internet;
- assets locais versionados;
- mensagem de erro de login permanece visivel;
- usuario, sessao e teclado continuam expostos no greeter;
- a aparencia glass usa fallback visual sem exigir blur real do compositor;
- botoes de energia respeitam `sddm.canSuspend`, `canReboot` e `canPowerOff`.

## Ativacao opt-in

```nix
kryonix.desktop.sddm.theme.preset = "kryonix-clean";
```

O default continua preservado em `"default"`.

## Preview local

```bash
THEME_PATH="$(nix build .#kryonix-sddm-theme --no-link --print-out-paths)/share/sddm/themes/kryonix-clean"
sddm-greeter --test-mode --theme "$THEME_PATH"
```

## Rollback

```nix
kryonix.desktop.sddm.theme.preset = "default";
```
