# Estado Atual para Agentes

Atualizado em 2026-04-25.

## Resumo

- O repositório agora opera como Kryonix.
- `kryonix.*` é o namespace público ativo.
- `rag.*` segue como alias temporário.
- Hyprland é o desktop real.
- Caelestia é o shell/rice principal dos hosts Hyprland.
- DMS ainda existe como legado de transição e não deve receber novos acoplamentos.
- `kryonix` é o entrypoint operacional preferencial.
- `node` segue como alias temporário com aviso de depreciação.
- Repo principal: `https://github.com/RAGton/kryonix`.
- Vault: `https://github.com/RAGton/kryonix-vault.git`.

## Hosts ativos

- `inspiron`: notebook principal de desenvolvimento local, Hyprland + Caelestia.
- `inspiron-nina`: perfil mais leve, Hyprland + Caelestia.
- `glacier`: workstation principal para virtualização/gaming, storage em `/srv/ragenterprise`.
- `iso`: output de instalação, não confundir com fluxo de adoção de host já instalado.

## Estado atual do launcher

- O launcher do Caelestia usa o código upstream em `modules/launcher/services/Apps.qml`.
- Apps gráficas passam pelo wrapper `kryonix-launch` usando `entry.id`, não `entry.command`.
- Apps marcadas como `runInTerminal` passam por `app2unit`.
- A falha principal estava no launch de apps gráficas por desktop ID sem resolução robusta do desktop entry antes de `uwsm`.
- O fuzzy search de apps fica desativado para reduzir latência do launcher.

## Correção local adotada

- O pacote do Caelestia recebe um patch local para chamar `kryonix-launch`.
- O wrapper tenta `uwsm app -- <desktop-entry>` primeiro, depois `gtk-launch`, e só então usa o `Exec=` do desktop file como fallback.
- A ativação Home Manager limpa `~/.local/state/caelestia/apps.sqlite*` e roda `update-desktop-database` para as entradas do usuário.

## Camada local de contexto

- `AGENTS.md` continua sendo o contrato principal.
- `context/` agora é o índice curto e estável.
- `skills/` guarda rotinas operacionais reutilizáveis.
- `.github/copilot-instructions.md`, `.github/instructions/*.instructions.md` e `.github/prompts/*.prompt.md` cobrem a integração nativa com Copilot.
- `ai/` permanece como material anterior e não é a nova entrada principal.

## Atenções abertas

- `desktop/hyprland/user.nix` segue grande e concentra wrappers demais.
- Ainda há documentação histórica divergente fora da trilha curta de contexto.
- No host atual usado para teste, o Obsidian apresentou falha antiga de runtime do pacote (`Cannot find module 'electron'`), separada da correção do launcher.
