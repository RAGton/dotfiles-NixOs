# Waywallen no Kryonix

## Resumo

O Kryonix empacota o Waywallen via release oficial binaria porque o pin atual
do nixpkgs nao oferece `pkgs.waywallen` e o build upstream from-source ainda e
caro para este repo:

- CMake + Rust + Qt6
- `Cargo.lock` ausente no repo upstream
- fetches internos em `deps.json`

Por isso, o caminho atual e:

- `kryonix-waywallen` — AppImage oficial reempacotado
- `kryonix-waywallen-display-kde` — plasmoid KDE oficial
- `kryonix-open-wallpaper-engine` — plugin oficial opt-in

## Pacotes expostos

- `.#kryonix-waywallen`
- `.#kryonix-waywallen-display-kde`
- `.#kryonix-open-wallpaper-engine`
- overlays:
  - `pkgs.kryonix-waywallen`
  - `pkgs.kryonix-waywallen-display-kde`
  - `pkgs.kryonix-open-wallpaper-engine`

## Execucao declarativa

O daemon user sobe como:

```bash
waywallen --ui <...>/waywallen-ui --plugin <...>/share/waywallen [--plugin <open-wallpaper-engine>]
```

No Hyprland, o backend de display sobe como:

```bash
waywallen-layer-shell --name kryonix
```

## Limites atuais

- sem `switch` automatico
- sem preview runtime validado neste commit
- sem automacao declarativa para selecionar o wallpaper dinamico no Plasma
- o plugin `open-wallpaper-engine` continua dependendo de assets/licenca do
  Wallpaper Engine quando o usuario quiser consumir Workshop/scene/web

## Preview local

```bash
nix build .#kryonix-waywallen --no-link --print-out-paths
```

Depois, com o pacote no store:

```bash
<out>/bin/waywallen
<out>/bin/waywallen-ui
<out>/bin/waywallen-layer-shell --help
```
