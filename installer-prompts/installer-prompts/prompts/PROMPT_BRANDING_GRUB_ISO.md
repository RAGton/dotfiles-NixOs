# Prompt: Branding Completo — GRUB ISO + Sistema + Plymouth Live

> A ISO e o sistema instalado mostram "NixOS" em todo lugar.
> Tudo deve ser "Kryonix" com o tema HUD ciano/escuro.
> Três escopos: ISO GRUB, sistema instalado GRUB, Plymouth na ISO.

---

## FASE 1 — Diagnóstico

```bash
# Ver como o host iso configura o GRUB
cat /etc/kryonix/hosts/iso/default.nix

# Ver o que a installation-cd-minimal já define
grep -rn 'grubTheme\|splashImage\|isoImage\|grub2\|nixos-grub' \
  /etc/kryonix/hosts/iso/ \
  /etc/kryonix/modules/nixos/installer/ \
  --include='*.nix' | grep -v '#' | head -20

# Ver se existe tema GRUB customizado
find /etc/kryonix -name "*.grub" -o -name "theme.txt" 2>/dev/null | head -5

# Ver como o branding define o splashImage
grep -n 'grubSplash\|splashImage\|grub' \
  /etc/kryonix/modules/nixos/branding/kryonix/default.nix | head -15
```

---

## FASE 2 — ISO: título e entradas do GRUB

O título "NixOS 26.05... Installer" vem do label gerado automaticamente.
Corrigir em `hosts/iso/default.nix`:

```nix
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ../../modules/nixos/installer/web-kiosk.nix
    ../../modules/nixos/branding/kryonix/default.nix
  ];

  kryonix.branding.enable = true;

  # Título do menu GRUB da ISO
  isoImage.volumeID = "KRYONIX-INSTALLER";

  # Entradas do menu — substituir "NixOS" por "Kryonix"
  boot.loader.grub.extraEntries = lib.mkForce "";
  isoImage.grubTheme = null;  # vamos definir o nosso

  # Label do sistema (aparece no GRUB)
  system.nixos.label = lib.mkForce "Kryonix-Installer";

  # Forçar nome nas entradas geradas
  networking.hostName = "kryonix-installer";

  # Substituir as entradas padrão da ISO
  boot.loader.grub.extraConfig = lib.mkForce ''
    set default=0
    set timeout=5

    menuentry "⟡ Kryonix Installer" {
      search --set=root --label KRYONIX-INSTALLER
      linux /boot/bzImage init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
      initrd /boot/initrd
    }

    menuentry "⟡ Kryonix Installer (modo seguro)" {
      search --set=root --label KRYONIX-INSTALLER
      linux /boot/bzImage init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} nomodeset
      initrd /boot/initrd
    }

    menuentry "Memtest86+" {
      search --set=root --label KRYONIX-INSTALLER
      linux16 /boot/memtest86+.bin
    }
  '';
}
```

> Nota: as entradas do GRUB da ISO são geradas pelo módulo installation-cd.
> Verificar se `isoImage.makeEfiBootable` e `isoImage.makeUsbBootable` estão ativos
> — eles geram entradas separadas que também precisam ser atualizadas.

---

## FASE 3 — Tema GRUB customizado (ISO + sistema)

Criar em `files/grub-theme/`:

```
files/grub-theme/
├── theme.txt          ← layout do tema
├── background.png     ← gerado do wallpaper HUD (via branding)
└── icons/
    └── os_kryonix.png ← ícone do menu (opcional)
```

### `files/grub-theme/theme.txt`

```
# Kryonix GRUB Theme — HUD Palette
# Fundo: #081018 (espaço profundo)
# Primário: #00d4ff (ciano)
# Texto: #cdd6f4

desktop-image: "background.png"
desktop-color: "#081018"

# Título do menu
title-text: "⟡ KRYONIX"
title-font: "Unifont Regular 20"
title-color: "#00d4ff"

# Box do menu
+ boot_menu {
  left   = 15%
  top    = 20%
  width  = 70%
  height = 50%
  item_font      = "Unifont Regular 16"
  item_color     = "#cdd6f4"
  selected_item_color  = "#081018"
  selected_item_pixmap_style = "select_*.png"
  item_height    = 32
  item_padding   = 12
  item_spacing   = 4
  menu_pixmap_style = "menu_*.png"
  scrollbar      = false
}

# Barra de countdown
+ progress_bar {
  id        = "__timeout__"
  left      = 15%
  top       = 73%
  width     = 70%
  height    = 3px
  fg_color  = "#00d4ff"
  bg_color  = "#1b2a36"
  border_color = "#1b2a36"
}

# Texto de instruções
+ label {
  left     = 0
  top      = 80%
  width    = 100%
  align    = "center"
  text     = "↑↓ selecionar  ↵ confirmar  Tab editar"
  font     = "Unifont Regular 12"
  color    = "#45475a"
}
```

### Derivação Nix do tema

Em `modules/nixos/branding/kryonix/default.nix`, adicionar junto ao `grubSplash`:

```nix
grubTheme = pkgs.stdenv.mkDerivation {
  name = "kryonix-grub-theme";
  nativeBuildInputs = [ pkgs.imagemagick ];

  buildCommand = ''
    themeDir="$out/kryonix"
    mkdir -p "$themeDir"

    # Background do tema (wallpaper processado)
    magick "${kryonixWallpaper}" \
      -resize 1920x1080^ \
      -gravity center \
      -extent 1920x1080 \
      -brightness-contrast -20x0 \
      -fill '#081018' \
      -colorize 40 \
      PNG32:"$themeDir/background.png"

    # Copiar theme.txt
    cp ${./grub-theme/theme.txt} "$themeDir/theme.txt"

    # Pixmaps do menu (seleção ciano)
    # selected item background
    magick -size 10x32 xc:'#00d4ff22' \
      -fill none \
      -stroke '#00d4ff' \
      -strokewidth 1 \
      -draw "rectangle 0,0 9,31" \
      PNG32:"$themeDir/select_c.png"
    cp "$themeDir/select_c.png" "$themeDir/select_w.png"
    magick -size 5x32 xc:'#00d4ff22' PNG32:"$themeDir/select_e.png"
    magick -size 5x32 xc:'#00d4ff22' PNG32:"$themeDir/select_w.png"
  '';
};
```

### Aplicar o tema

No bloco `config = lib.mkIf cfg.enable`:

```nix
# Sistema instalado
boot.loader.grub = {
  splashImage   = grubSplash;
  theme         = "${grubTheme}/kryonix";
  backgroundColor = "#081018";
  splashMode    = "stretch";
};

# ISO
isoImage.grubTheme = "${grubTheme}/kryonix";
```

---

## FASE 4 — Plymouth na ISO (live boot sem verbose)

A installation-cd-minimal desabilita Plymouth por padrão. Reabilitar no host iso:

```nix
# hosts/iso/default.nix
boot.plymouth = {
  enable = lib.mkForce true;
  theme  = "kryonix";
  themePackages = [
    # referenciar o mesmo plymouthTheme do branding
    config.kryonix.branding._plymouthTheme  # ou passar via let
  ];
};

# Parâmetros de silêncio (mesmos do sistema)
boot.initrd.verbose  = lib.mkForce false;
boot.consoleLogLevel = lib.mkForce 0;
boot.kernelParams = lib.mkMerge [
  config.boot.kernelParams
  [ "quiet" "splash" "loglevel=0" "systemd.show_status=false" ]
];
```

> O tema Plymouth já existe no branding. Verificar se `plymouthTheme`
> é exportado ou se precisa ser movido para um let compartilhado.

---

## FASE 5 — Remover referências NixOS visíveis ao usuário

```bash
# Encontrar todas as strings "NixOS" que aparecem na UI
grep -rn '"NixOS\|nixos\b' \
  /etc/kryonix/hosts/iso/ \
  /etc/kryonix/modules/nixos/installer/ \
  --include='*.nix' | grep -viE 'modulesPath|nixpkgs|nixos-install|nixos-rebuild|#' | head -20

# Verificar o os-release gerado (o branding já cuida disso)
nix eval /etc/kryonix#nixosConfigurations.iso.config.environment.etc."os-release".text \
  2>/dev/null | grep -i 'name\|pretty'
```

Strings a substituir nos arquivos encontrados:
- `"NixOS Installer"` → `"Kryonix Installer"`
- `"NixOS Live"` → `"Kryonix Live"`
- Logo NixOS no GRUB → removido (substituído pelo background customizado)

---

## FASE 6 — Verificação visual antes de rebuild

```bash
# Avaliar se o tema será aplicado
nix eval /etc/kryonix#nixosConfigurations.iso.config.boot.loader.grub.theme \
  --apply 'p: if p == null then "NULL" else "PRESENTE"' 2>/dev/null

nix eval /etc/kryonix#nixosConfigurations.inspiron.config.boot.loader.grub.theme \
  --apply 'p: if p == null then "NULL" else "PRESENTE"' 2>/dev/null

# Build dry-run da ISO
nix build /etc/kryonix#nixosConfigurations.iso.config.system.build.isoImage \
  --dry-run 2>&1 | grep -c 'error' | xargs echo "Erros:"

# Build real
nix build /etc/kryonix#nixosConfigurations.iso.config.system.build.isoImage \
  -o /tmp/result-iso -L 2>&1 | tail -10
```

---

## FASE 7 — Validação visual na VM

```bash
qemu-system-x86_64 \
  -m 2048 -cpu host -enable-kvm \
  -vga virtio -display gtk \
  -cdrom /tmp/result-iso/iso/*.iso \
  -boot d
```

### Checklist visual

```
GRUB
[ ] Fundo escuro com wallpaper HUD (não azul claro genérico do NixOS)
[ ] Título "⟡ KRYONIX" no topo (não "NixOS")
[ ] Entrada "⟡ Kryonix Installer" (não "NixOS 26.05...")
[ ] Texto do menu em branco/ciano (não cinza)
[ ] Barra de countdown ciano
[ ] Logo NixOS não aparece em nenhum lugar

PLYMOUTH (boot após selecionar)
[ ] Sem verbose do kernel (tela escura/animação)
[ ] Logo Kryonix animado visível
[ ] Transição suave para o kiosk

KIOSK
[ ] Chromium abre sem barra de abas
[ ] Site do instalador carrega
```

---

## Commit

```bash
git -C /etc/kryonix add \
  hosts/iso/default.nix \
  modules/nixos/branding/kryonix/default.nix \
  files/grub-theme/

git -C /etc/kryonix commit -m "feat: branding Kryonix completo — GRUB + ISO + Plymouth

GRUB ISO:
- Título: 'NixOS Installer' → '⟡ Kryonix Installer'
- isoImage.volumeID = KRYONIX-INSTALLER
- Tema HUD: fundo escuro, texto ciano, barra de progresso ciano
- Logo NixOS removido

GRUB sistema instalado:
- Mesmo tema aplicado via branding module
- splashImage do wallpaper HUD

Plymouth ISO:
- Reabilitado na ISO (installation-cd desabilita por padrão)
- Mesmo tema animado do sistema

Branding:
- grubTheme derivation adicionada (ImageMagick + theme.txt)
- Nenhuma referência visual ao NixOS ao usuário final"

git -C /etc/kryonix push
```

---

## Regras

1. `lib.mkForce` no `isoImage.grubTheme` — a installation-cd define o padrão NixOS com prioridade alta
2. `system.nixos.label = lib.mkForce "Kryonix-Installer"` — o label é gerado automaticamente
3. Plymouth na ISO exige `lib.mkForce true` — a cd-minimal desabilita com mkForce
4. Verificar que `isoImage.grubTheme` aceita o path da derivação (pode precisar de `toString`)
5. O `theme.txt` do GRUB2 tem sintaxe própria — validar com `grub-script-check` se disponível
6. Build da ISO demora — rodar `--dry-run` antes para garantir que não tem erros de avaliação
7. Reportar o output do `nix eval ...grub.theme` antes e depois para confirmar que aplicou
