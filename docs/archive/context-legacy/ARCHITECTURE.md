# Arquitetura Resumida

## Camadas do sistema

- `hosts/`: hardware, boot e papel por máquina
- `hosts/common/`: agregação compartilhada
- `profiles/`: composição reutilizável por papel
- `features/`: capacidades opt-in
- `modules/nixos/**`: implementação base e serviços
- `desktop/hyprland/**`: stack desktop atual
- `home/**`: configuração user-level por usuário/host
- `packages/`: artefatos do projeto, incluindo `kryonix` e o wrapper compat `node`

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

1. bind ou drawer do Caelestia
2. `modules/launcher/services/Apps.qml`
3. `kryonix-launch` para apps gráficas
4. `uwsm app -- <desktop entry resolvido>`
5. fallback `gtk-launch`, depois fallback por `Exec=`

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
