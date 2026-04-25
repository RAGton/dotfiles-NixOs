# Arquitetura Resumida

## Camadas do sistema

- `hosts/`: hardware, boot e papel por máquina
- `hosts/common/`: agregação compartilhada
- `profiles/`: composição reutilizável por papel
- `features/`: capacidades opt-in
- `modules/nixos/**`: implementação base e serviços
- `desktop/hyprland/**`: stack desktop atual
- `home/**`: configuração user-level por usuário/host
- `packages/`: artefatos do projeto, incluindo a CLI `kryonix`

## Regras de modelagem

- host escolhe papel e opções, não implementa feature inteira
- profile compõe
- feature habilita capacidade
- module implementa comportamento
- shell/rice não redefinem desktop

## Caminho do shell atual

- sessão gráfica: Hyprland + UWSM
- shell principal: Caelestia
- ativação do shell: sistema (`modules/nixos/desktop/caelestia/default.nix`)
- dados mutáveis do shell: Home Manager (`desktop/hyprland/rice/caelestia-config.nix`)

## Caminho do launcher atual

1. `SUPER+A`
2. `kryonix-launcher`
3. resolução declarativa de `.desktop` em XDG/NixOS
4. `gtk-launch <desktop-id>`

O drawer do Caelestia continua suportado via patch local:

1. `modules/launcher/services/Apps.qml`
2. `kryonix-launch <entry.id>`
3. `uwsm app -- <desktop entry resolvido>`
4. fallback `gtk-launch`, depois fallback por `Exec=`

Apps de terminal continuam usando `app2unit`.

## Arquitetura da memória local

- `AGENTS.md`: contrato global e prioridades
- `context/INDEX.md`: índice curto
- `context/CURRENT_STATE.md`: snapshot curto do estado real
- `context/HOSTS/`: notas por host
- `context/RUNBOOKS/`: execução e troubleshooting
- `context/DECISIONS/`: decisões estáveis
- `context/INCIDENTS/`: histórico de falhas reais
- `skills/`: procedimentos reutilizáveis
- `.github/*`: superfície nativa de Copilot

## Princípio

AGENTS não é enciclopédia.
AGENTS aponta para a próxima fonte curta e relevante.
