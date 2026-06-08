# Prompt mestre para Claude — Fechar Plasma/KWin/Tiling/Theme no Kryonix

Você é Claude atuando como engenheiro sênior NixOS, KDE Plasma/KWin, Home Manager, desktop Linux, UI theming e automação declarativa.

Você está trabalhando no repositório:

```txt
/etc/kryonix
```

## Objetivo

Fechar de forma decente a parte ruim/incompleta do projeto relacionada a:

1. KDE Plasma declarativo no NixOS.
2. KWin tiling / window management declarativo.
3. Home Manager para configurações KDE/Plasma.
4. Tema visual próprio do Kryonix.
5. Barra/painel do Plasma com layout coerente.
6. Configs opcionais para tiling manager no Windows.
7. Documentação, validação e rollback.

A entrega deve ser limpa, modular, testável e opt-in.

## Contexto obrigatório

Antes de modificar qualquer arquivo, leia:

```txt
AGENTS.md
docs/README.md
docs/ARCHITECTURE.md
docs/OPERATIONS.md
docs/TESTING.md
docs/TROUBLESHOOTING.md
docs/ROADMAP.md
.context/CURRENT_STATE.md se existir
docs/ai/PROJECT_CONTEXT.md se existir
docs/ai/PROJECT_INDEX.md se existir
```

Depois inspecione o código real:

```bash
cd /etc/kryonix

git status --short
git diff --stat
git submodule status --recursive

rg -n "plasma|kde|kwin|sddm|displayManager|desktopManager|hyprland|caelestia|theme|bar|panel|waybar|ags|astal" \
  flake.nix hosts modules profiles features home desktop packages docs context 2>/dev/null || true
```

## Regra de precedência

1. Código real do repo vence.
2. Flake, hosts, modules, profiles, features, home e packages definem comportamento.
3. Docs atuais orientam, mas não substituem código.
4. Memória/conversa antiga não vence repo.
5. Se algo não existir, não invente que existe.

## Regras absolutas

- Não remover Hyprland.
- Não remover Caelestia.
- Não ativar Plasma como padrão global sem opção explícita.
- Não rodar `switch`, `boot`, `disko`, `mkfs`, `format-*`, `install-system`, `reboot`, `shutdown`.
- Não mexer em discos, bootloader, rede, SSH, Tailscale, GPU ou storage fora do escopo.
- Não usar `git add .`.
- Não commitar sem pedido explícito.
- Não alterar `flake.lock` sem necessidade real.
- Não expor secrets.
- Não escrever configuração mutável solta em `~/.config` fora do Home Manager.
- Não declarar pronto sem validação.
- Não esconder erro.

## Implementação esperada

### 1. Módulo Plasma NixOS opt-in

Criar ou ajustar módulo conforme estrutura real do repo.

Alvo conceitual:

```nix
kryonix.desktop.plasma.enable = true;
kryonix.desktop.plasma.tiling.enable = true;
kryonix.desktop.plasma.theme.enable = true;
```

Se o namespace real for outro, use o padrão real.

O módulo deve:

- habilitar Plasma 6 quando ativado;
- escolher display manager de forma compatível com o canal atual;
- não quebrar Hyprland/Caelestia;
- não ativar em todos os hosts;
- permitir fallback.

### 2. Home Manager Plasma/KWin

Criar módulo Home Manager para:

- `kwinrc`;
- `kdeglobals`;
- `kglobalshortcutsrc` se for seguro;
- pacotes KDE necessários;
- recarregamento do KWin via `qdbus6 org.kde.KWin /KWin reconfigure`;
- serviço user opcional, se necessário.

### 3. Tiling KWin

Implementar abordagem em camadas:

1. KWin/Plasma nativo quando possível.
2. Plugin externo apenas como opção.
3. Fallback documentado se Polonium/Bismuth/Krohnkite não estiverem disponíveis no nixpkgs atual.

Não trate Polonium/Bismuth como dependência obrigatória.

### 4. Tema Kryonix Dark

Criar tema mínimo decente:

- cores;
- fontes;
- icon/cursor theme;
- wallpaper placeholder;
- KDE global config;
- janela/decoração quando possível;
- docs.

Tokens visuais:

```txt
background      #0B0F14
surface         #111827
surface-alt     #1F2937
border          #334155
text            #E5E7EB
text-muted      #94A3B8
accent          #38BDF8
accent-strong   #0EA5E9
danger          #EF4444
warning         #F59E0B
success         #22C55E
```

### 5. Barra/painel

Criar especificação e implementação mínima para barra/painel Plasma:

```txt
[launcher] [workspaces/desktops] [tasks]            [network] [audio] [battery] [clock] [tray]
```

Se configuração declarativa total do painel for instável, documente o limite e implemente a parte segura.

Pode considerar:

- plasma-manager, se for adequado e validado;
- KConfig/plasma scripting gerado via Nix;
- Home Manager com arquivos XDG.

Mas não adicione dependência grande sem justificar.

### 6. Windows tiling

Adicionar configs opcionais em pasta de docs/configs, sem afetar build NixOS:

- Komorebi `komorebi.json`;
- `whkdrc`;
- GlazeWM `config.yaml`;
- README comparando FancyZones, Komorebi e GlazeWM.

### 7. Documentação

Criar/atualizar:

```txt
docs/desktop/PLASMA_KWIN_DECLARATIVE.md
docs/desktop/PLASMA_THEME_KRYONIX_DARK.md
docs/desktop/WINDOWS_TILING.md
```

Ou equivalente conforme padrão real do repo.

## Estrutura sugerida

Adapte ao repo real:

```txt
modules/nixos/desktop/plasma/default.nix
modules/home/desktop/plasma/default.nix
modules/home/desktop/plasma/tiling.nix
modules/home/desktop/plasma/theme.nix
desktop/plasma/themes/kryonix-dark/
desktop/plasma/kwin/
windows/tiling/
docs/desktop/
```

## Validação obrigatória

Execute ou classifique claramente a impossibilidade:

```bash
cd /etc/kryonix

git status --short
git diff --stat
git diff --check

nix fmt
nix flake show --all-systems
nix flake check --keep-going
```

Build sem aplicar:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link -L --show-trace
```

Se o projeto exige wrapper:

```bash
kryonix check
kryonix diff
```

Não rode `kryonix switch` sem autorização explícita.

## Testes Plasma/KWin

Se estiver em sessão Plasma segura:

```bash
echo "$XDG_SESSION_TYPE"
echo "$WAYLAND_DISPLAY"
echo "$DISPLAY"

qdbus6 org.kde.KWin /KWin reconfigure || true
journalctl --user -b --no-pager -n 200 | rg -i "kwin|plasma|kde|kconfig|failed|error" || true
```

## Entrega esperada

Ao terminar, responda com:

```md
# Relatório Final — Plasma/KWin/Tiling/Theme Kryonix

## Status
Implementado / Parcial / Não implementado

## Arquivos alterados
...

## O que mudou
...

## Validação executada
...

## Resultado dos testes
...

## Riscos
...

## Rollback
...

## Pendências
...
```

## Critério de pronto

Só pode dizer pronto se:

- o diff está limpo de secrets;
- `git diff --check` passou;
- formatter passou;
- flake avalia ou falha foi classificada;
- build do host afetado passou ou falha foi classificada;
- docs foram atualizadas;
- Hyprland/Caelestia foram preservados;
- Plasma é opt-in;
- rollback foi documentado.

Agora execute a tarefa com disciplina: leia o repo, proponha o plano mínimo, aplique patches pequenos e valide.
