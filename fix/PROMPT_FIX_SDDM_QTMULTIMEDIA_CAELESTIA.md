# Prompt: Corrigir SDDM (QtMultimedia) + Wallpaper via Caelestia

> Dois problemas após aplicar o tema SDDM:
> 1. SDDM astronaut falha: `module "QtMultimedia" is not installed`
> 2. Caelestia sobrepõe o wallpaper do awww — awww é inútil, precisa integrar.

---

## PROBLEMA 1 — QtMultimedia faltando no SDDM

### Diagnóstico

O `sddm-astronaut-theme` importa `QtMultimedia` no `Main.qml:10` (para fundos
animados/vídeo). Esse módulo Qt não está no ambiente do SDDM, então o tema não carrega
e cai no fallback (tema azul default).

```
file:///run/current-system/sw/share/sddm/themes/sddm-astronaut-theme/Main.qml:10:1
module "QtMultimedia" is not installed
```

### Correção em `desktop/hyprland/system.nix` (ou onde o SDDM é configurado)

```nix
services.displayManager.sddm = {
  wayland.enable = true;
  theme = "sddm-astronaut-theme";

  # ADICIONAR — QtMultimedia para o tema astronaut funcionar
  extraPackages = with pkgs.kdePackages; [
    qtmultimedia
  ];
};
```

### Verificar a versão do Qt do SDDM

O tema astronaut é Qt6. Confirmar que o SDDM usa Qt6 (kdePackages), não Qt5:

```bash
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.sddm.package --apply 'p: p.name'
# Se for sddm baseado em Qt6/kdePackages → usar pkgs.kdePackages.qtmultimedia
# Se for Qt5 → usar pkgs.libsForQt5.qt5.qtmultimedia
```

Se o tema continuar falhando após adicionar qtmultimedia, considerar usar a variante
**sem vídeo** do astronaut (fundo estático), que não depende de QtMultimedia:

```nix
environment.systemPackages = [
  (pkgs.sddm-astronaut.override {
    embeddedTheme = "astronaut";   # ou a variante de fundo estático disponível
  })
];
```

### Validação do problema 1

```bash
nixos-rebuild build --flake /etc/kryonix#inspiron
sudo nixos-rebuild switch --flake /etc/kryonix#inspiron

# Confirmar que qtmultimedia está no ambiente do SDDM
ls /run/current-system/sw/ 2>/dev/null | grep -i qml
find /run/current-system -path '*QtMultimedia*' 2>/dev/null | head -3

# Reiniciar SDDM (de um TTY — fecha a sessão)
sudo systemctl restart display-manager
# → tema astronaut deve carregar SEM a mensagem de erro vermelha
```

---

## PROBLEMA 2 — Caelestia sobrepõe o wallpaper

### Diagnóstico

O Caelestia tem seu próprio daemon/sistema de wallpaper que roda no `exec-once`
e toma precedência. Subir o `awww-daemon` em paralelo não adianta — o Caelestia
sobrescreve. Precisamos integrar com o Caelestia, não competir.

### Passo 1 — Descobrir como o Caelestia gerencia wallpaper

```bash
# Ver o comando de wallpaper do Caelestia
caelestia --help 2>/dev/null | grep -i wall
caelestia wallpaper --help 2>/dev/null

# Ver o que o Caelestia roda no exec-once
grep -rn 'caelestia\|wallpaper\|exec-once' /etc/kryonix/desktop/hyprland \
  --include='*.nix' --include='*.conf' | grep -v '#' | grep -iv 'awww'

# Ver onde o Caelestia guarda o wallpaper atual
ls -la ~/.local/share/caelestia/ 2>/dev/null
ls -la ~/.config/caelestia/ 2>/dev/null
cat ~/.local/state/caelestia/wallpaper* 2>/dev/null
```

Reportar como o Caelestia seta wallpaper (comando exato) antes de editar.

### Passo 2 — Reescrever `kryonix-wallpaper` para usar o Caelestia

Em `desktop/hyprland/theme/wallpaper.nix`, trocar a lógica do `awww img` por
`caelestia wallpaper`:

```nix
home.file.".local/bin/kryonix-wallpaper" = {
  executable = true;
  text = ''
    #!/usr/bin/env bash
    # Integra com o sistema de wallpaper do Caelestia
    WALL_DIR="/etc/kryonix/files/wallpaper"

    set_wall() {
      local img="$1"
      [ -f "$img" ] || { echo "Arquivo não encontrado: $img"; exit 1; }

      # Usar o comando do Caelestia (sintaxe confirmada no Passo 1)
      caelestia wallpaper -f "$img"

      # Gerar paleta de cores (matugen) — opcional, Caelestia pode já fazer isso
      command -v matugen >/dev/null && matugen image "$img" --mode dark 2>/dev/null &

      notify-send "🖼 Wallpaper" "$(basename "$img")" --expire-time 2000
    }

    case "$1" in
      --random)
        img=$(find "$WALL_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.webp' \) | shuf -n1)
        set_wall "$img"
        ;;
      --next)
        # Caelestia pode ter um comando próprio de "próximo"
        caelestia wallpaper 2>/dev/null || $0 --random
        ;;
      "")
        $0 --random
        ;;
      *)
        set_wall "$1"
        ;;
    esac
  '';
};
```

> **Importante:** ajustar `caelestia wallpaper -f` para a sintaxe EXATA descoberta
> no Passo 1. Pode ser `caelestia wallpaper set <path>`, `caelestia wallpaper -i <path>`,
> ou outro formato. Verificar com `caelestia wallpaper --help`.

### Passo 3 — Remover o awww (não serve neste setup)

Como o Caelestia gerencia o wallpaper, o `awww-daemon` é desnecessário e conflita:

```nix
# Remover do exec-once:
"awww-daemon --format xrgb"
"sleep 0.5 && kryonix-wallpaper"

# Remover awww das dependências (manter matugen se Caelestia não fizer cores):
home.packages = [ pkgs.matugen ];  # remover pkgs.awww
```

O Caelestia já restaura o wallpaper no login — não precisa de `exec-once` próprio.

### Passo 4 — Manter os atalhos funcionando

Os atalhos `Super+Alt+W` e `Super+Ctrl+Alt+W` continuam chamando `kryonix-wallpaper`,
que agora delega ao Caelestia. Não precisa mudar os binds.

### Validação do problema 2

```bash
home-manager switch --flake /etc/kryonix#rocha@inspiron

# Testar troca de wallpaper — deve persistir (Caelestia não sobrescreve mais)
kryonix-wallpaper --random
# → wallpaper muda E permanece (não volta pro do Caelestia)

# Testar atalho dentro do Hyprland
# Super+Alt+W → próximo wallpaper
```

---

## Commit (após os dois problemas validados)

```bash
git -C /etc/kryonix add desktop/hyprland/system.nix \
                         desktop/hyprland/theme/wallpaper.nix

git -C /etc/kryonix commit -m "fix: SDDM QtMultimedia + wallpaper via Caelestia

- Adiciona kdePackages.qtmultimedia ao SDDM (tema astronaut precisa)
- kryonix-wallpaper agora usa 'caelestia wallpaper' em vez de awww
- Remove awww-daemon do exec-once (conflitava com o Caelestia)
- Atalhos Super+Alt+W mantidos, delegando ao Caelestia
- Validado: tema astronaut carrega sem erro, wallpaper persiste"

git -C /etc/kryonix push
```

---

## Regras

1. Descobrir a sintaxe EXATA de `caelestia wallpaper` antes de reescrever o script
2. Não rodar awww-daemon em paralelo com o Caelestia — escolher um (Caelestia vence)
3. Testar SDDM com `systemctl restart display-manager` de um TTY
4. Se qtmultimedia não resolver, usar variante estática do astronaut (sem vídeo)
5. Reportar o output de `caelestia wallpaper --help` antes de editar o script
6. matugen pode ser redundante se o Caelestia já extrai cores — verificar
```
