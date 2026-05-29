# Prompt: SDDM — Tema Sci-Fi HUD integrado ao Kryonix

> Objetivo: tela de login visualmente integrada ao tema HUD do Kryonix.
> Paleta: espaço profundo (#0a0d12) + ciano elétrico (#00d4ff) + verde terminal (#39ff14).
> Arte do usuário: `/etc/kryonix/files/wallpaper/` (12 imagens disponíveis).
> Config atual: SDDM funcionando, sem tema aplicado ainda.

---

## FASE 1 — Inventário (somente leitura)

```bash
# Ver config atual do SDDM
grep -rn 'sddm\|displayManager' /etc/kryonix/desktop/hyprland/system.nix \
  /etc/kryonix/modules/nixos/desktop/default.nix | grep -v '#'

# Verificar temas disponíveis no nixpkgs
nix search nixpkgs sddm 2>/dev/null | grep -i 'theme\|astronaut\|catppuccin\|sugar' | head -20

# Verificar se sddm-astronaut-theme está disponível
nix eval nixpkgs#sddm-astronaut-theme.name 2>/dev/null || echo "não encontrado"
nix eval nixpkgs#catppuccin-sddm-corners.name 2>/dev/null || echo "não encontrado"
nix eval nixpkgs#catppuccin-sddm.name 2>/dev/null || echo "não encontrado"

# Ver as artes disponíveis
ls -la /etc/kryonix/files/wallpaper/

# Verificar o nome interno dos temas (pasta real que o SDDM usa)
nix build nixpkgs#sddm-astronaut-theme --no-link --print-out-paths 2>/dev/null \
  | xargs -I{} ls {}/share/sddm/themes/ 2>/dev/null
nix build nixpkgs#catppuccin-sddm-corners --no-link --print-out-paths 2>/dev/null \
  | xargs -I{} ls {}/share/sddm/themes/ 2>/dev/null
```

Reportar: quais pacotes existem, o nome interno de cada tema (pasta em `share/sddm/themes/`),
e quais artes estão disponíveis em `files/wallpaper/`. Essas informações definem
qual tema usar e como configurar o background.

---

## FASE 2 — Escolha e configuração do tema

### Hierarquia de preferência

Usar o primeiro disponível nesta ordem:

**1. `sddm-astronaut-theme`** — estética espacial/sci-fi direta, suporta
   background customizado e cores via configuração QML.

**2. `catppuccin-sddm-corners`** — dark, limpo, já tem variante Mocha (mais escura).
   Não é sci-fi puro mas integra bem com a paleta.

**3. `catppuccin-sddm`** — fallback se corners não existir.

### Configuração em `modules/nixos/desktop/default.nix` ou `desktop/hyprland/system.nix`

Após identificar o nome interno do tema na FASE 1, aplicar:

```nix
services.displayManager.sddm = {
  wayland.enable = true;
  theme = "<nome-interno-confirmado-na-fase-1>";

  settings = {
    Theme = {
      # Background: usar uma das artes do usuário
      # Escolher a mais adequada para tela de login (atmosférica, não muito detalhada)
      Background = "/etc/kryonix/files/wallpaper/<arte-escolhida>";
      ThemeDir = "/run/current-system/sw/share/sddm/themes";
      CursorTheme = "Bibata-Modern-Ice";
      CursorSize = 24;
    };
    General = {
      # Fonte monospace consistente com o HUD
      Font = "JetBrains Mono";
      FontSize = 12;
    };
  };
};
```

### Garantir que os pacotes estão disponíveis no sistema

```nix
environment.systemPackages = with pkgs; [
  <pacote-do-tema>     # ex: sddm-astronaut-theme
  bibata-cursors       # cursor Bibata-Modern-Ice
  nerd-fonts.jetbrains-mono  # fonte JetBrains Mono
];
```

---

## FASE 3 — Customização de cores (se tema suportar)

### Para `sddm-astronaut-theme`

Suporta arquivo de configuração de cores via `ThemeConfig`. Criar override em
`/etc/kryonix/files/sddm/astronaut-theme.conf`:

```ini
[General]
# Paleta Kryonix HUD
AccentColor=#00d4ff
BackgroundColor=#0a0d12
TextColor=#e8f4f8
PlaceholderColor=#4a6b7a
BorderColor=#1e2d3d
HoverColor=#0f1419

ScreenWidth=1366
ScreenHeight=768
FullBlur=true
PartialBlur=false
BlurRadius=30
```

Referenciar no SDDM:

```nix
services.displayManager.sddm.settings.Theme = {
  ThemeConfig = "/etc/kryonix/files/sddm/astronaut-theme.conf";
};
```

### Para `catppuccin-sddm-corners`

Selecionar variante Mocha (mais escura, mais próxima da paleta HUD):

```nix
# O pacote pode aceitar override de flavour
environment.systemPackages = [
  (pkgs.catppuccin-sddm-corners.override { flavor = "mocha"; accent = "teal"; })
];
```

---

## FASE 4 — Integração com o wallpaper do sistema

O SDDM e o Hyprland devem usar a mesma arte ativa quando possível.
O script `kryonix-wallpaper` salva o wallpaper atual em
`~/.local/state/kryonix/wallpaper-current`.

Criar um link simbólico ou script que atualiza o background do SDDM
quando o wallpaper do sistema muda (opcional — implementar se for simples,
caso contrário deixar um wallpaper fixo no SDDM).

**Abordagem simples (recomendada):**
Usar uma das artes do usuário como background fixo no SDDM
— algo mais sombrio e atmosférico, adequado para uma tela de login sci-fi.

```bash
# Ver quais artes existem e escolher a mais adequada
ls -la /etc/kryonix/files/wallpaper/
# Reportar os nomes para o usuário escolher
```

---

## FASE 5 — Validação

```bash
# 1. Verificar avaliação sem erros
nix flake check /etc/kryonix --keep-going 2>&1 | grep '^error' | head -10

# 2. Confirmar nome do tema está correto
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.services.displayManager.sddm.theme

# 3. Confirmar que o pacote do tema está nos system packages
nix eval /etc/kryonix#nixosConfigurations.inspiron.config.environment.systemPackages \
  --apply 'pkgs: map (p: p.name) pkgs' 2>/dev/null | grep -i 'sddm\|astronaut\|catppuccin'

# 4. Build sem ativar
nixos-rebuild build --flake /etc/kryonix#inspiron

# 5. Test — ativa sem tornar permanente
sudo nixos-rebuild test --flake /etc/kryonix#inspiron

# 6. Reiniciar o display manager (sem reboot)
sudo systemctl restart display-manager
# → SDDM deve aparecer com o novo tema
```

### Checklist visual pós-test

```
[ ] SDDM aparece com tema escuro (não o padrão branco)
[ ] Background mostra a arte escolhida
[ ] Cursor é Bibata-Modern-Ice
[ ] Fonte do greeter é legível em monospace
[ ] Campo de senha está visível e funcional
[ ] Login funciona e entra no Hyprland normalmente
[ ] Sem erros no journalctl: journalctl -u display-manager -n 20
```

---

## FASE 6 — Commit

```bash
git -C /etc/kryonix add modules/nixos/desktop/default.nix \
                         desktop/hyprland/system.nix \
                         files/sddm/ 2>/dev/null || true

git -C /etc/kryonix commit -m "feat: tema SDDM integrado ao visual HUD do Kryonix

- Tema: <nome-do-tema-aplicado>
- Background: arte <nome-do-arquivo> do usuário
- Cursor: Bibata-Modern-Ice
- Fonte: JetBrains Mono
- Cores alinhadas à paleta HUD (ciano #00d4ff / espaço #0a0d12)
- Validado: display-manager reiniciado, login funcional"

git -C /etc/kryonix push
```

---

## Regras

1. Verificar o nome INTERNO do tema (pasta em `share/sddm/themes/`) antes de
   configurar `theme = "..."` — nome errado causa black screen
2. Usar `sudo systemctl restart display-manager` para testar o visual sem reboot
3. Não usar `nixos-rebuild switch` sem antes confirmar que o tema carrega com `test`
4. Se o tema não suportar background customizado, usar um tema diferente
5. O background deve ser um path acessível ao SDDM (root) — `/etc/kryonix/files/wallpaper/`
   é acessível; `~/` não é
6. Reportar o nome de cada arte disponível antes de escolher qual usar no SDDM
