# Spec 02 — Ecossistema de Pacotes + Kryonix Installer

## Estado atual (verificado)
CLI `kryonix` = writeShellApplication (shell), não Rust. Rust = kryonix-home + installer (Axum + Vite/React).
Brain = submódulo Python (packages/kryonix-brain-lightrag). registry.sh = fonte de comandos.
Installer UI: packages/kryxd/ui/ (React + Vite, outDir=static).
Installer Backend: packages/kryxd/ (Rust, Axum). npmDepsHash gerenciado via buildNpmPackage.

## Objetivos
- `packages/default.nix` com callPackage; casas separadas para CLI/Rust/installer/doctor/brain.
- Injeção via overlay (`pkgs.kryonix.<comp>`).
- **Kryonix Installer completo**: fluxo Bare-Metal → Produtividade via GitHub OAuth.

---

## Arquitetura do Kryonix Installer

### Stack
| Camada   | Tecnologia         | Função                                           |
|----------|--------------------|--------------------------------------------------|
| Backend  | Rust + Axum        | API REST, orquestração, execução de comandos Nix |
| Frontend | Vite + React       | UI progressiva servida pelo backend              |
| Hardware | kryonix-hardware-probe | Leitura de UUID, CPU, GPU, partições         |
| Disco    | kryonix-disk-planner + disko | Particionamento declarativo             |
| Cache    | Cachix (kryonix.cachix.org) | Binários pré-compilados do repo upstream |

### Fluxo Bare-Metal → Produtividade

```
[1] Auth GitHub OAuth
       ↓
[2] URL do repositório pessoal (kryonixos)
       ↓
[3] Clone → /etc/kryonixos
       ↓
[4] kryonix-hardware-probe (background)
     ├─ UUID da placa-mãe
     ├─ CPU vendor + modelo
     └─ GPU vendor(s) + modelo
       ↓
[5] Match Hardware × hosts/
     ├─ Match → seleciona hosts/<existente> automaticamente
     └─ New machine → cria hosts/<nova>/hardware-configuration.nix
                       importa users/ + temas do repo
                       git commit "chore: add <hostname>"
       ↓
[6] Instalação
     nixos-install --flake /etc/kryonixos#<host>
     substituters: kryonix.cachix.org (binários pré-compilados)
```

### Passo 1 — Autenticação GitHub (OAuth Device Flow)
- Backend inicia Device Authorization Flow (POST `github.com/login/device/code`)
- Frontend exibe QR Code + URL + código de 8 dígitos ao usuário
- Backend faz polling em `github.com/login/oauth/access_token` até confirmar
- Token armazenado em memória apenas durante a sessão do installer (nunca em disco/store)
- Com o token, backend usa GitHub API para listar repos do usuário (públicos e privados)
- Permite clonar via HTTPS com credencial temporária: `https://<token>@github.com/...`

**Segurança:** token nunca vai ao Nix Store, apenas ao processo do installer em memória.
Após instalação bem-sucedida, token é descartado e não fica em nenhum arquivo.

### Passo 2 — Seleção / Criação do Repositório
UI oferece duas opções:
- **"Usar repositório existente"**: lista repos do usuário via GitHub API; seleção via dropdown
- **"Criar do zero"**: cria novo repo GitHub via API (POST `/user/repos`), inicializa com template
  do kryonix upstream (fork ou template clone com estrutura mínima de `flake.nix` + `users.nix`)

### Passo 3 — Clone para /etc/kryonixos
```rust
// Backend executa:
git clone https://<token>@github.com/<user>/<repo> /etc/kryonixos
```
Permissões: `/etc/kryonixos` criado com `chown rocha:node` para edição sem sudo posterior.

### Passo 4 — Hardware Probe (background)
Backend lança `kryonix-hardware-probe` que retorna JSON:
```json
{
  "board_uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "cpu": { "vendor": "Intel", "model": "Core i7-12700H", "cores": 20 },
  "gpu": [{ "vendor": "Intel", "model": "Iris Xe", "pci_id": "8086:46a6" }],
  "memory_gb": 16,
  "disks": [{ "path": "/dev/nvme0n1", "size_gb": 512, "type": "nvme" }]
}
```

### Passo 5 — Match Hardware × hosts/
```
Para cada hosts/<name>/hardware-configuration.nix em /etc/kryonixos:
  - Extrai board UUID ou CPU+GPU fingerprint
  - Compara com probe atual
  - Score ≥ threshold → match automático

Se nenhum match:
  - Gera hosts/<hostname>/hardware-configuration.nix via nixos-generate-config
  - Detecta CPU Intel/AMD → importa hardware.nixosModules.common-cpu-*
  - Detecta GPU → importa hardware.nixosModules.common-gpu-*
  - Importa users.nix e temas do repo (sem alterar)
  - git add + git commit + git push (usando token da sessão)
```

### Passo 6 — Instalação com Cache Cachix
```bash
nixos-install \
  --flake /etc/kryonixos#<hostname> \
  --option substituters "https://cache.nixos.org https://kryonix.cachix.org" \
  --option trusted-public-keys "cache.nixos.org-1:... kryonix.cachix.org-1:xZvvORDy..."
```
Progress feed via SSE (Server-Sent Events) do backend para a UI.

---

## Plano incremental (1 bloco/commit)

1. `packages/default.nix` com callPackage; mover kryonix-cli para pasta com lib/*.sh.
2. Formalizar installer/backend — endpoints REST para cada passo do fluxo:
   - `POST /auth/github/device` → inicia Device Flow
   - `GET  /auth/github/poll`   → verifica token
   - `GET  /repos`              → lista repos do usuário
   - `POST /clone`              → clona repo
   - `GET  /hardware`           → retorna probe JSON
   - `POST /configure`          → match + gera config
   - `POST /install`            → dispara nixos-install
   - `GET  /install/progress`   → SSE com output
3. Frontend React — tela por passo (stepper progressivo):
   Step 1: QR Code GitHub OAuth
   Step 2: Seleção / criação de repo
   Step 3: Progress bar clone + probe
   Step 4: Review da configuração gerada
   Step 5: Install progress (log ao vivo via SSE)
   Step 6: Reboot / próximos passos
4. Criar kryonix-doctor (TUI Python) — novo.
5. Plugar overlay; trocar imports relativos.

## Validação
- `nix build .#kryxd` sem erro de hash
- UI reachable em localhost:5173 (dev) e embutida no binário (prod)
- Device Flow completa em conta GitHub de teste
- Clone de repo privado funciona com token OAuth
- hardware-probe retorna JSON válido no inspiron e glacier
- Match detecta inspiron pelo UUID; nova máquina gera config correta
- `nixos-install --dry-run` conclui sem erro usando o flake gerado

## Segurança
- GitHub token: apenas em memória do processo, nunca em arquivo, nunca no Nix Store
- Nenhum secret no `flake.nix` ou `users.nix` do kryonixos
- Clone HTTPS com token efêmero; após install, remover remote credential do git config

## Risco / Rollback
- npmDepsHash/cargoLock errados → fixar hashes; rollback via overlay
- OAuth scope: pedir apenas `repo` (acesso a repos); não pedir `admin:org` ou `delete_repo`
- Clone falha → mensagem clara + opção de tentar URL alternativa ou modo offline
- Match errado → UI permite sobrescrever seleção manualmente antes de confirmar
