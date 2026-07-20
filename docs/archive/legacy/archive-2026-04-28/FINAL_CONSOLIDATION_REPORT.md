# Final Consolidation Report — node-nixos

**Autor:** Gabriel Rocha (rag) + Codex  
**Data:** 2026-03-12

## 1) Problemas encontrados

### Arquitetura
- Existência de legado KDE/Plasma no repositório (arquivos e módulos) sem uso na composição ativa.
- Camadas de desktop ainda com rastros de tooling GNOME/Nautilus no Home Manager de Hyprland.
- Obsidian deve ser o app canônico de notas/conhecimento; referências antigas a Notion precisam sair do caminho principal.

### UX Hyprland + DMS
- Atalho `SUPER+V` não tinha fallback robusto para quando o IPC do DMS não estivesse disponível.
- Lockscreen/power menu sem padronização total em atalhos de uso diário.
- Ausência de menu rápido padronizado para troca de dispositivos de áudio (output/input) usando `wpctl`.
- Rede/Bluetooth ainda muito dependente de CLI puro sem menu unificado no fluxo de atalhos.

### Organização de módulos
- Alguns comentários/assertions ainda citavam SDDM, mesmo com estratégia de desktop único em Hyprland.

## 2) Mudanças aplicadas

### Consolidação Hyprland + DMS
- `SUPER+V` agora usa script `rag-clipboard-menu`:
  - prioriza `dms ipc clipboard toggle`;
  - fallback para `cliphist + rofi` se DMS não responder.
- Padronização de atalhos utilitários:
  - `SUPER+L` lockscreen;
  - `SUPER+X` power menu (`wlogout`);
  - `SUPER+O` menu de áudio com `wpctl`;
  - `SUPER+W` menu de rede/Bluetooth.
- Padronização de file manager: atalho rápido secundário trocado de Nautilus para Dolphin.

### Áudio / Bluetooth
- Adicionado `rag-audio-menu` com seleção de output/input padrão via `wpctl` + rofi.
- Mantido stack PipeWire/WirePlumber/Blueman com ferramentas de diagnóstico e controle.

### Rede além de nmcli puro
- `rag-network-menu` com:
  - `networkmanager_dmenu`;
  - `nm-connection-editor`;
  - `blueman-manager`.

### Dolphin + KIO
- Consolidado `kdePackages.dolphin`, `kdePackages.dolphin-plugins` e `kdePackages.kio-extras`.
- `kio-gdrive` e `kio-admin` adicionados condicionalmente quando disponíveis no canal.
- Transparência do Dolphin mantida no `hyprland.conf` via `windowrule`.

### VSCodium + Obsidian
- VSCodium já consolidado nos hosts (`stable + nixpkgs`).
- Obsidian passa a ser o app canônico de notas, estudo e memória pessoal no stack.

### Limpeza estrutural e coerência
- Removido bloco de preferências Nautilus do Home Manager Hyprland.
- Removida referência de `wofi`; o launcher principal deve ser Caelestia IPC e o fallback continua fora do caminho principal.
- Ajustado texto/validação de opções para remover menção a SDDM no fluxo principal.

## 3) Pendências e limitações
- **Limitação de ambiente/política de execução:** remoção física de alguns diretórios legados KDE/Plasma via operação destrutiva foi bloqueada nesta sessão.
- O legado permanece no histórico/árvore, mas fora da composição ativa.
- Recomenda-se limpeza física final em uma sessão que permita `git rm` dos caminhos legados.

## 4) Testes executados nesta sessão
- Busca de consistência de atalhos/scripts Hyprland via `rg`.
- Busca de consistência de Dolphin/KIO/Obsidian e remoção de Notion/Wofi via `rg`.
- Tentativa de validação Nix (`nix flake check`) não executável por ausência de binário `nix` no ambiente.

## 5) Testes obrigatórios para fechamento (rodar em host com Nix)
1. `nix flake show`
2. `nix flake check`
3. `nix build .#nixosConfigurations.inspiron.config.system.build.toplevel`
4. `nix build .#nixosConfigurations.glacier.config.system.build.toplevel`
5. `nix build .#nixosConfigurations.iso.config.system.build.isoImage`
6. `nix build .#homeConfigurations.rocha@inspiron.activationPackage`
7. `nix build .#homeConfigurations.rocha@glacier.activationPackage`

## 6) Notas por host

### inspiron
- Mantém foco laptop (ABNT2, energia, lock, rede, áudio e Bluetooth com atalhos padronizados).

### glacier
- Mantém foco desktop NVIDIA com stack Wayland/Hyprland + DMS e menus de áudio/rede para produtividade diária.
