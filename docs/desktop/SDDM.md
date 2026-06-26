# SDDM no Kryonix

O SDDM no Kryonix deve ser tratado como camada separada do Plasma Desktop
Theme. Tema de login nao controla painel, widgets ou layout da sessao Plasma.

## Estado atual

- display manager usado hoje: `SDDM`;
- KDE usa SDDM Wayland no modulo `modules/nixos/desktop/kde/default.nix`;
- Hyprland continua com seu fluxo atual de SDDM + tema astronaut;
- tema proprio legado existente: `kryonix-aurora`;
- novo preset opt-in: `kryonix-clean`.

## Package

O output `.#kryonix-sddm-theme` instala os temas versionados em:

```txt
$out/share/sddm/themes/kryonix-aurora
$out/share/sddm/themes/kryonix-clean
```

Overlay:

- `pkgs.kryonix-sddm-theme`

## Selecao de tema

### Caminho canônico novo

```nix
kryonix.desktop.sddm.theme.preset = "kryonix-clean";
```

### Compat legado KDE

```nix
kryonix.desktop.kde.sddm.theme = "kryonix-aurora";
```

### Preservacao do default

```nix
kryonix.desktop.sddm.theme.preset = "default";
```

Em KDE, isso preserva o Breeze por default e continua respeitando a opcao
legada `kryonix.desktop.kde.sddm.theme`.

## Validacao sem switch

```bash
cd /home/rocha/kryonix/kryonix-dev/repos/kryonix
git diff --check
nix flake show --all-systems
nix build .#kryonix-sddm-theme --no-link -L --show-trace
nix flake check --keep-going
```

Preview local do greeter:

```bash
THEME_PATH="$(nix build .#kryonix-sddm-theme --no-link --print-out-paths)/share/sddm/themes/kryonix-clean"
sddm-greeter --test-mode --theme "$THEME_PATH"
```

Se o binario local for `sddm-greeter6` ou `sddm-greeter-qt6`, use o que existir
no host.

## Rollback

- voltar `kryonix.desktop.sddm.theme.preset = "default";`
- ou voltar `kryonix.desktop.kde.sddm.theme = "breeze";`
- validar com `kryonix test`
- aplicar depois com `kryonix switch`
