# Estado Atual para Agentes

Atualizado em 2026-04-25.

## Resumo

- O repositório agora opera como Kryonix.
- `kryonix.*` é o namespace público ativo.
- Hyprland é o desktop real.
- Caelestia é o shell/rice principal dos hosts Hyprland.
- DMS ainda existe como legado de transição e não deve receber novos acoplamentos.
- `kryonix` é o entrypoint operacional preferencial.
- `packages/kryonix-cli.nix` é o único pacote de CLI do projeto; pacote e módulos antigos foram removidos.
- Repo principal: `https://github.com/RAGton/kryonix`.
- Vault: `https://github.com/RAGton/kryonix-vault.git`.

## Hosts ativos

- `inspiron`: notebook principal de desenvolvimento local, Hyprland + Caelestia.
- `inspiron-nina`: perfil mais leve, Hyprland + Caelestia.
- `glacier`: workstation principal para virtualização/gaming, storage em `/srv/ragenterprise`.
- `iso`: output de instalação, não confundir com fluxo de adoção de host já instalado.

## Estado atual do launcher

- O atalho principal `SUPER+A` chama `kryonix-launcher`.
- `kryonix-launcher` existe como script versionado em `modules/home-manager/scripts/bin` e resolve arquivos `.desktop` declarativamente via diretórios XDG/NixOS antes de executar com `gtk-launch`.
- O launcher do Caelestia usa o código upstream em `modules/launcher/services/Apps.qml` com patch local para chamar `kryonix-launch`.
- Apps gráficas passam pelo wrapper `kryonix-launch` usando `entry.id`, não `entry.command`.
- Apps marcadas como `runInTerminal` passam por `app2unit`.
- Launchers e menus do stack Hyprland usam `kryonix-menu`: `fuzzel --dmenu` no Wayland e `fzf` apenas como fallback TTY.
- Clipboard e runner foram restaurados sem menu legado via `kryonix-clipboard-menu` e `kryonix-runner`.
- O fuzzy search de apps fica desativado para reduzir latência do launcher.
- `kryonix-ipc` é o wrapper atual para comandos IPC do Caelestia/Quickshell.
- Winbox é instalado pelo módulo NixOS com wrapper isolado em XWayland por padrão.

## Correção local adotada

- O pacote do Caelestia recebe um patch local para chamar `kryonix-launch`.
- O wrapper tenta `uwsm app -- <desktop-entry>` primeiro, depois `gtk-launch`, e só então usa o `Exec=` do desktop file como fallback.
- A ativação Home Manager limpa `~/.local/state/caelestia/apps.sqlite*` e roda `update-desktop-database` para as entradas do usuário.
- Hyprland usa blur/shadow desativados, VFR ativo e animações curtas; Caelestia fica sem visualiser e sem transparência pesada por padrão.

## Camada local de contexto

- `AGENTS.md` continua sendo o contrato principal.
- `context/` agora é o índice curto e estável.
- `skills/` guarda rotinas operacionais reutilizáveis.
- `.github/copilot-instructions.md`, `.github/instructions/*.instructions.md` e `.github/prompts/*.prompt.md` cobrem a integração nativa com Copilot.
- `ai/kryonix-vault` permanece como vault local para skills/templates; o fluxo operacional consulta `context/` primeiro e usa o vault para melhorar qualidade quando a tarefa pedir conhecimento reutilizável.

## Atenções abertas

- `desktop/hyprland/user.nix` segue grande e concentra wrappers demais.
- Ainda há documentação histórica divergente fora da trilha curta de contexto.
- No host atual usado para teste, o Obsidian apresentou falha antiga de runtime do pacote (`Cannot find module 'electron'`), separada da correção do launcher.
