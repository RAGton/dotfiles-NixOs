# Wallpaper Dinamico no Kryonix

## Objetivo

Adicionar wallpapers dinamicos como recurso opt-in, sem trocar o wallpaper
estatico atual por default e sem acoplar Plasma, SDDM e branding.

## Estado atual

- motor suportado: `waywallen`
- pacote do nixpkgs atual do flake: `UNKNOWN/ausente`, empacotado localmente no Kryonix
- plugin Wallpaper Engine: `open-wallpaper-engine` opt-in
- Steam: opt-in
- KDE Plasma: suportado via plasmoid `org.waywallen.kde`
- Hyprland: preparado via `waywallen-layer-shell`

## Opcoes

```nix
kryonix.desktop.wallpaper.dynamic = {
  enable = true;
  engine = "waywallen";
  steam.enable = false;
  wallpaperEngine.enable = false;
  defaultWallpaper = null;
};
```

## Comportamento

- `enable = false`: nada muda no wallpaper atual.
- `enable = true`: instala Waywallen e sobe o daemon via `systemd --user`.
- Em KDE, instala tambem o plasmoid `org.waywallen.kde`.
- Em Hyprland, sobe tambem `waywallen-layer-shell`.
- O plugin `open-wallpaper-engine` so entra quando `wallpaperEngine.enable = true`.
- `steam.enable = true` ativa `programs.steam.enable` e `hardware.graphics.enable32Bit`
  por `mkDefault`, sem mexer no perfil gamer global.

## Wallpapers fallback do Kryonix

Quando o recurso esta habilitado, o Home Manager expõe:

- `~/.local/share/kryonix/waywallen/default-wallpaper`
- `~/.local/share/kryonix/waywallen/wallpapers/`

Arquivos publicados:

- `kryonix-blue-glass-dark.svg`
- `kryonix-blue-glass-light.svg`
- `kryonix-clean-dark.svg`
- `kryonix-clean-light.svg`

Esses assets servem como fallback/local import dentro do Waywallen sem alterar
o wallpaper estatico do host.

## Validacao recomendada

```bash
nix build .#kryonix-waywallen --no-link -L --show-trace
nix build .#kryonix-open-wallpaper-engine --no-link -L --show-trace
nix build .#kryonix-waywallen-display-kde --no-link -L --show-trace
nix flake check --keep-going
```

## Runtime manual

Nao executar `switch` automaticamente. Depois do rebuild do host:

```bash
systemctl --user status kryonix-waywallen.service
systemctl --user status kryonix-waywallen-layer-shell.service
```

No KDE, adicionar o wallpaper/plugin `org.waywallen.kde` pela interface do
Plasma.
