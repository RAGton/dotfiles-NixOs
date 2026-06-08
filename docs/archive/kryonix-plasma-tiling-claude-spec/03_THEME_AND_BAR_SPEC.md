# 03 — Especificação: Tema, barra, painéis e identidade visual

## Objetivo

Criar uma experiência visual decente para Plasma/KWin no Kryonix, com identidade própria, sem depender de tema aleatório e sem quebrar Hyprland/Caelestia.

## Direção visual

Nome sugerido: `Kryonix Dark`.

Estilo:

- dark clean;
- azul gelo / ciano como accent;
- cinza grafite;
- cantos arredondados moderados;
- bordas sutis;
- sem excesso de blur pesado;
- visual técnico, workstation, IA local.

## Tokens visuais

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

## Escopo de tema

### KDE/Plasma

Configurar declarativamente quando possível:

- `kdeglobals`;
- color scheme;
- icon theme;
- cursor theme;
- fonts;
- wallpaper;
- KWin effects mínimos;
- window decoration;
- panel/barra;
- app launcher;
- task manager;
- system tray;
- clock;
- network/battery/audio widgets.

### Barra / painel

Criar uma barra/painel Plasma organizada:

```txt
[launcher] [workspaces/desktops] [tasks]
                         [network] [audio] [battery] [clock] [tray]
```

Se a configuração declarativa completa do painel Plasma for difícil/instável, implemente uma das opções:

1. `plasma-manager`, se o repo já usar ou se for aceitável adicionar;
2. script KConfig/plasma scripting gerado via Nix e executado uma vez por Home Manager;
3. documentação clara do limite e configuração parcial declarativa.

O agente deve pesquisar no repositório se já existe padrão para plasma-manager ou módulos Home Manager avançados antes de adicionar dependência.

### SDDM / login

Apenas se houver escopo seguro:

- tema SDDM/Plasma Login Manager com identidade Kryonix;
- não quebrar login remoto;
- não remover fallback de sessão;
- não setar tema que não está no store.

## Artefatos esperados

```txt
desktop/plasma/themes/kryonix-dark/
desktop/plasma/wallpapers/
desktop/plasma/color-schemes/
desktop/plasma/panels/
docs/desktop/PLASMA_THEME_KRYONIX_DARK.md
```

Ajustar conforme o padrão real.

## Requisitos de qualidade

- Sem hardcode de `/home/rocha` se puder ser genérico.
- Sem assets binários grandes no commit.
- SVG/JSON/QML pequenos são aceitáveis.
- Wallpapers grandes devem ser opcionais ou documentados.
- Tema deve ter fallback se pacote/asset não existir.

## Teste visual mínimo

Após aplicar em ambiente seguro:

```bash
kryonix home
qdbus6 org.kde.KWin /KWin reconfigure || true
systemctl --user restart plasma-plasmashell.service || true
journalctl --user -b --no-pager -n 200 | rg -i "plasma|kwin|theme|kconfig|error|failed" || true
```

Não executar restart destrutivo sem avisar o usuário.
