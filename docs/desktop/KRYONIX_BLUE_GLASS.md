# Kryonix Blue Glass

Preset opt-in para KDE Plasma 6 no Kryonix. O default do sistema continua
`BonaFides`; `Blue Glass` existe como camada declarativa ativável por preset.

`playlist_status = UNKNOWN`

## Objetivo

- Entregar um desktoptheme próprio do Kryonix com glass azul, bordas suaves,
  contraste alto e wallpapers dedicados.
- Separar aparência do painel da definição do layout.
- Corrigir duplicidade visual de Wi-Fi no KDE sem remover `NetworkManager`.

## Estrutura

- Package: `packages/kryonix-plasma-theme.nix`
- Branding base: `packages/kryonix-branding.nix`
- Assets: `desktop/kde/kryonix-blue-glass/`
- Branding canônico: `desktop/branding/kryonix/`
- Preset NixOS: `kryonix.desktop.kde.theme.preset`

Conteúdo do package:

- `share/plasma/desktoptheme/kryonix-blue-glass`
- `share/color-schemes/KryonixBlueGlassDark.colors`
- `share/color-schemes/KryonixBlueGlassLight.colors`
- `share/wallpapers/kryonix-blue-glass/*.svg`
- `share/kryonix/mascot/*`

Conteúdo do branding base:

- `share/backgrounds/kryonix/kryonix-blue-glass-dark.svg`
- `share/backgrounds/kryonix/kryonix-blue-glass-light.svg`
- `share/pixmaps/kryonix/logo.svg`

## Como ativar

No host downstream:

```nix
kryonix.desktop.kde.theme.preset = "kryonix-blue-glass-dark";
```

Ou:

```nix
kryonix.desktop.kde.theme.preset = "kryonix-blue-glass-light";
```

## Layout vs aparência

- Aparência: `desktoptheme`, `plasmarc`, SVGs e color schemes do package.
- Wallpapers canônicos e paleta oficial: `desktop/branding/kryonix/`.
- Layout: `desktop/kde/theme.nix` via `plasma-manager`.
- O Kryonix não edita `plasma-org.kde.plasma.desktop-appletsrc` manualmente
  nesta implementação.

## Wi-Fi

Causa da duplicidade visual observada no KDE:

- `programs.nm-applet.enable = true` no módulo comum de rede.
- widget standalone `org.kde.plasma.networkmanagement` no painel superior.
- `org.kde.plasma.systemtray` no mesmo painel, que já agrega `plasma-nm`.

Correção aplicada:

- `nm-applet` fica desativado quando `kryonix.desktop.environment == "kde"`.
- o painel superior mantém apenas `org.kde.plasma.systemtray`.
- `NetworkManager` permanece ativo.

## Validação esperada

- `nix build .#kryonix-branding --no-link -L --show-trace`
- `nix flake check --keep-going` em `repos/kryonixos`
- `nix flake show --all-systems` em `repos/kryonix`
- `nix build .#kryonix-plasma-theme --no-link -L --show-trace`
- `nix flake check --keep-going` em `repos/kryonix`

## Status da entrega

- `Blue Glass`: preset ativável
- `Runtime testado`: não
- `Build-validado`: depende do relatório final desta execução

## Rollback

Para reverter o preset:

```nix
kryonix.desktop.kde.theme.preset = "bonafides";
```
