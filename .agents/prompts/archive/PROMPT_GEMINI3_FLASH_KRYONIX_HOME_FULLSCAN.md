# PROMPT.md — Gemini 3 Flash: Kryonix Home Brain Full-Home + Content-Aware + UX Profissional

Você é o **Gemini 3 Flash atuando como agente de engenharia sênior** dentro do projeto **Kryonix**.

Você está em:

```bash
/etc/kryonix
```

## Missão

Entregar uma correção profissional do **Kryonix Home Brain**, com implementação real, testes, commits e provas de funcionamento.

O usuário não quer só plano, nem explicação bonita. Você deve **implementar, validar e provar**.

O problema atual é que o sistema ainda está classificando muito por nome/pasta e pouco por conteúdo/contexto. Também houve resposta anterior dizendo que o scanner não deveria analisar a raiz da Home. Isso está incorreto para a necessidade atual.

O comportamento correto é:

```txt
/home/<usuario> inteiro:
  ✅ inventariar por metadados
  ✅ detectar arquivos, diretórios, projetos, vaults, notebooks, mídia e documentos
  ✅ ler conteúdo leve apenas de arquivos seguros
  ❌ nunca ler conteúdo de secrets/configs/caches/chaves
```

---

# 1. Objetivo final

Implementar e provar:

1. **Full Home Scan seguro**
   - `kryonix home scan` deve cobrir `/home/<usuario>` inteiro por metadados.
   - Conteúdo só é lido em arquivos seguros e pequenos.
   - Paths protegidos entram como `metadata_only`.

2. **Content-Aware Classifier**
   - Ler conteúdo leve de arquivos seguros.
   - Usar conteúdo para corrigir arquivos em pastas erradas.
   - Detectar conteúdo financeiro, acadêmico, técnico, notebooks, projetos e arquivos desconhecidos.

3. **Context-Aware Classifier**
   - Entender pasta atual, arquivos vizinhos e se está dentro de projeto.
   - Marcar `context_mismatch=true` quando conteúdo e pasta divergirem.

4. **Ollama Advisor opcional**
   - Ollama só sugere, nunca executa.
   - Se falhar, usar fallback determinístico.
   - Não enviar conteúdo sensível ao Ollama.

5. **Downloads sempre limpa**
   - `~/Downloads` é zona transitória.
   - Todo item em Downloads deve gerar proposta de saída.

6. **UX terminal profissional**
   - Saída padrão humana, estilizada e intuitiva.
   - JSON somente com `--json`.
   - Mostrar tabela de duas colunas:

```txt
DE ONDE ESTÁ  ->  PARA ONDE VAI
```

7. **Sem mutação real**
   - Não rodar `apply --confirm` na Home real.
   - Aplicação real só pode ser testada em `HOME="$(mktemp -d)"`.

---

# 2. Regras absolutas

## Proibido

1. Não executar `kryonix home apply --confirm` na Home real.
2. Não deletar arquivos.
3. Não alterar Brain, Neo4j, GraphRAG, LightRAG ou WayVNC.
4. Não expor Ollama publicamente.
5. Não abrir firewall para Ollama.
6. Não imprimir secrets.
7. Não ler conteúdo de:
   - `~/.ssh`
   - `~/.gnupg`
   - `~/.config`
   - `~/.local`
   - `~/.cache`
   - `~/.mozilla`
   - `~/.var`
   - `~/.npm`
   - `~/.cargo`
   - `~/.rustup`
   - `.env`
   - `brain.env`
   - `neo4j.env`
   - chaves privadas
   - tokens
   - bancos de dados
   - imagens de VM
   - backups grandes
8. Não usar JSON como saída padrão.
9. Não usar `git+file` como solução final de release.
10. Não declarar sucesso sem comandos de validação.
11. Não esconder falha de teste.
12. Não commitar `target/`, binários, caches ou secrets.
13. Não mover tags antigas.
14. Não fazer force-push.

## Permitido

- Inventariar paths protegidos por metadados.
- Marcar paths protegidos como `metadata_only`.
- Ler conteúdo leve de arquivos seguros.
- Usar Ollama local/remoto como consultor.
- Rodar `apply --confirm` somente em `HOME="$(mktemp -d)"`.

---

# 3. Auditoria inicial obrigatória

Execute antes de editar:

```bash
cd /etc/kryonix

echo "=== superprojeto ==="
git status --short
git status -sb
git branch --show-current
git log --oneline --decorate -8

echo "=== submodules ==="
git submodule status --recursive

echo "=== kryonix-home ==="
git -C packages/kryonix-home status --short
git -C packages/kryonix-home branch --show-current
git -C packages/kryonix-home log --oneline --decorate -8

echo "=== flake inputs ==="
nix flake metadata | rg -n "kryonix-home|kryonix-brain-lightrag" || true

echo "=== comandos atuais ==="
nix run .#kryonix -- home --help || true
nix run .#kryonix -- home scan --help || true
nix run .#kryonix -- home plan --help || true
nix run .#kryonix -- home projects --help || true
nix run .#kryonix -- home diagnose --help || true
```

Se houver working tree sujo, salve backup:

```bash
ts="$(date +%Y%m%d-%H%M%S)"
backup="/tmp/kryonix-home-fullscan-backup-$ts"
mkdir -p "$backup"
git diff > "$backup/superproject.diff" || true
git status --short > "$backup/superproject.status"
git -C packages/kryonix-home diff > "$backup/kryonix-home.diff" || true
git -C packages/kryonix-home status --short > "$backup/kryonix-home.status"
echo "Backup salvo em: $backup"
```

---

# 4. Implementação no submódulo `packages/kryonix-home`

Entre no submódulo:

```bash
cd /etc/kryonix/packages/kryonix-home
```

## 4.1 Full Home Scan seguro

Alterar `src/scanner.rs`.

### Requisito

`kryonix home scan` deve inventariar `/home/<usuario>` inteiro por metadados.

Adicionar flags:

```bash
kryonix home scan --full-home
kryonix home scan --metadata-only
kryonix home scan --safe-content
```

Comportamento padrão recomendado:

```txt
full-home metadata inventory: ON
safe content sampling: ON
protected content reading: OFF
```

A lista antiga de diretórios conhecidos pode continuar apenas para rotular zonas, mas **não pode limitar o scan**.

Registrar por entrada:

```rust
pub path: String,
pub filename: String,
pub extension: String,
pub mime: String,
pub size_bytes: u64,
pub modified_at: Option<String>,
pub is_dir: bool,
pub is_file: bool,
pub is_symlink: bool,
pub is_hidden: bool,
pub is_project_member: bool,
pub project_root: Option<String>,
pub source_zone: Option<String>,
pub readable: bool,
pub content_sampled: bool,
pub metadata_only: bool,
pub protected_reason: Option<String>,
pub warnings: Vec<String>,
```

Detectar `source_zone`:

```txt
downloads
desktop
home_root
documents
pictures
videos
music
projects
code
notebooks
vault
project
hidden_config
unknown
```

Se path for protegido:

```txt
metadata_only=true
content_sampled=false
protected_reason="protected path"
```

Não ler conteúdo.

---

## 4.2 Content-Aware

Criar/estabilizar:

```txt
src/content.rs
```

Struct:

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContentProfile {
    pub path: String,
    pub content_read: bool,
    pub extractor: String,
    pub content_kind: String,
    pub sample_text: Option<String>,
    pub keywords: Vec<String>,
    pub title_candidates: Vec<String>,
    pub warnings: Vec<String>,
    pub truncated: bool,
    pub bytes_read: u64,
}
```

Função esperada:

```rust
pub fn analyze_content_safe(path: &Path, limit_bytes: u64) -> Result<ContentProfile>
```

Extensões permitidas, até 64 KiB:

```txt
txt md tex csv json yaml yml toml nix py rs sh go js ts html css ipynb
```

### IPYNB

- Não executar.
- Parsear JSON.
- Extrair markdown cells, títulos e imports.
- Limitar bytes.

### PDF

Se `pdftotext` existir:

- extrair até 3 páginas ou 32 KiB;
- se não existir, fallback por nome/MIME.

### Nunca ler

- paths protegidos;
- `.env`;
- keys;
- tokens;
- bancos;
- VMs;
- backups grandes.

---

## 4.3 Context-Aware

Criar/estabilizar:

```txt
src/context.rs
```

Struct:

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FolderContext {
    pub folder_path: String,
    pub folder_name: String,
    pub folder_kind: String,
    pub dominant_categories: Vec<String>,
    pub project_markers: Vec<String>,
    pub neighbor_extensions: Vec<String>,
    pub neighbor_keywords: Vec<String>,
    pub warnings: Vec<String>,
}
```

Regras:

- Arquivo dentro de projeto detectado não deve virar proposta individual por padrão.
- Arquivo financeiro dentro de projeto deve gerar `context_mismatch`, mas não mover automaticamente.
- Arquivo acadêmico em Downloads deve ir para Acadêmico.
- Notebook solto deve ir para `Notebooks/Estudos`.
- Projeto em `Music`, `Downloads`, `Pictures`, `Videos` deve ter warning de local estranho.
- Vault Obsidian deve ser `conhecimento.vault`.

---

## 4.4 Projetos e Vaults

Ajustar `project.rs`, `taxonomy.rs` e `planner.rs`.

Projetos devem ir para:

```txt
Projetos/Kryonix
Projetos/RAGOS
Projetos/NixOS
Projetos/IA
Projetos/Infra
Projetos/Windows
Projetos/Rust
Projetos/Python
Projetos/Arduino
Projetos/Sandbox
```

Não usar `Documentos/Projetos` como padrão.

Vault Obsidian:

```txt
category_id: conhecimento.vault
suggested_dir: Documentos/Conhecimento/Obsidian
risk: high
needs_review: true
reason: Vault de conhecimento detectado; não mover automaticamente
```

---

## 4.5 Downloads sempre limpa

Regra forte:

```txt
~/Downloads é zona transitória.
Nada deve morar definitivamente em Downloads.
```

Todo item em Downloads deve gerar proposta de saída, exceto se for sensível/protegido; nesse caso gerar `review_only`.

Destinos:

```txt
Projetos detectados      -> Projetos/<categoria>
Financeiro               -> Documentos/Financeiro/...
Acadêmico                -> Documentos/Academico/...
Notebooks                -> Notebooks/...
Imagens                  -> Midia/Imagens
Vídeos                   -> Midia/Videos
Áudio                    -> Midia/Audio
Compactados              -> Arquivos/Compactados
Instaladores             -> Arquivos/Instaladores
Desconhecidos            -> Documentos/00_Inbox/Downloads/Revisar
Conflitos                -> Documentos/00_Inbox/Downloads/Conflitos
Baixa confiança          -> Documentos/00_Inbox/Downloads/Baixa_Confianca
Sensíveis                -> Documentos/00_Inbox/Downloads/Sensiveis
```

Adicionar no `PlanProposal`:

```rust
pub source_zone: Option<String>,
pub content_summary: Option<String>,
pub content_keywords: Option<Vec<String>>,
pub context_kind: Option<String>,
pub context_mismatch: Option<bool>,
pub mismatch_reason: Option<String>,
pub evidence: Option<Vec<String>>,
```

Se `source_zone == downloads`, sempre sugerir saída.

---

## 4.6 Diagnose

Implementar:

```bash
kryonix home diagnose <arquivo>
kryonix home diagnose <arquivo> --json
kryonix home diagnose <arquivo> --content-aware
kryonix home diagnose <arquivo> --ollama
```

Saída padrão bonita:

```txt
╭────────────────────────────────────────────────────────────╮
│ 🧊 Kryonix Home Diagnose                                   │
├────────────────────────────────────────────────────────────┤
│ Arquivo: Downloads/arquivo_generico.txt                    │
│ Zona:    downloads                                         │
│ Tipo:    text/plain                                        │
╰────────────────────────────────────────────────────────────╯

┌──────────────────────────┬─────────────────────────────────┐
│ DE ONDE ESTÁ             │ PARA ONDE VAI                   │
├──────────────────────────┼─────────────────────────────────┤
│ Downloads/arquivo.txt    │ Documentos/Financeiro/Bancos    │
└──────────────────────────┴─────────────────────────────────┘

Evidências:
  - conteúdo contém: pix, banco, comprovante
  - pasta atual: Downloads é transitória
  - confiança: 0.91

Risco:
  medium

Status:
  nada foi alterado
```

---

## 4.7 Ollama Advisor opcional

Criar/estabilizar:

```txt
src/ollama.rs
```

Comportamento:

- `--ollama` liga diagnóstico por LLM.
- Ollama não executa ações.
- Se falhar, fallback determinístico.
- JSON inválido do Ollama deve ser descartado.
- Não enviar conteúdo sensível.

Endpoint por prioridade:

```txt
KRYONIX_REMOTE_OLLAMA_URL
KRYONIX_OLLAMA_URL
http://127.0.0.1:11435 se Inspiron
http://127.0.0.1:11434 se Glacier
```

Timeout máximo: 20s.

Se Ollama discordar do determinístico:

```txt
needs_review=true
risk>=medium
evidence += "Ollama divergiu do classificador determinístico"
```

---

# 5. UX obrigatória

## `kryonix home plan`

Saída padrão deve ser dashboard + tabela curta:

```txt
╭────────────────────────────────────────────────────────────╮
│ 🧊 Kryonix Home Plan                                       │
├────────────────────────────────────────────────────────────┤
│ Home: /home/rocha                                          │
│ Modo: full-home + content-aware + context-aware             │
│ Arquivos vistos: 1240                                      │
│ Projetos detectados: 18                                    │
│ Downloads pendentes: 37                                    │
│ Ações seguras: 22                                          │
│ Revisão necessária: 15                                     │
│ Conflitos/Risco: 4                                         │
╰────────────────────────────────────────────────────────────╯
```

Tabela obrigatória:

```txt
┌──────────────────────────────────────────────┬──────────────────────────────────────────────┐
│ DE ONDE ESTÁ                                 │ PARA ONDE VAI                                │
├──────────────────────────────────────────────┼──────────────────────────────────────────────┤
│ Downloads/comprovante_pix.pdf                │ Documentos/Financeiro/Bancos                 │
│ Downloads/aula_interpolacao.ipynb            │ Notebooks/Estudos                            │
│ Documents/Projeto-Ragos                      │ Projetos/RAGOS/Projeto-Ragos                 │
│ Music/kryonix                                │ Projetos/Kryonix/kryonix  ⚠ revisar          │
│ Downloads/arquivo_desconhecido.bin           │ Documentos/00_Inbox/Downloads/Revisar        │
└──────────────────────────────────────────────┴──────────────────────────────────────────────┘
```

Com `--why`, mostrar evidências por item.

Com `--json`, gerar JSON válido.

Nunca despejar centenas de linhas por padrão.

---

# 6. CLI wrapper

Atualizar `packages/kryonix-cli/main.sh` para rotear:

```txt
scan
report
duplicates
projects
categories
explain
diagnose
plan
manifest
apply
rollback
export-memory
```

`--help` de cada subcomando deve ser delegado ao Rust.

Atualizar help do `kryonix home`.

---

# 7. Testes unitários obrigatórios

Criar/ajustar testes para provar:

1. Scan full-home inventaria arquivo na raiz da Home.
2. Scan full-home inventaria diretório fora da lista antiga.
3. Paths protegidos são `metadata_only`.
4. `.env` não é lido.
5. `.ssh/id_ed25519` não é lido.
6. Arquivo `.txt` com `comprovante pix banco inter` classifica financeiro.
7. Arquivo genérico com `matriz curricular disciplina avaliação curso` classifica acadêmico.
8. Arquivo em pasta errada gera `context_mismatch=true`.
9. Notebook `.ipynb` extrai título/imports sem executar.
10. Projeto em Downloads gera proposta para `Projetos/...`.
11. Projeto em Music gera warning.
12. Obsidian Vault vira `conhecimento.vault`.
13. Downloads sempre gera proposta.
14. Desconhecido em Downloads vai para `Documentos/00_Inbox/Downloads/Revisar`.
15. `projects --json` gera JSON válido.
16. `diagnose --json` gera JSON válido.
17. Ollama JSON válido é parseado.
18. Ollama inválido usa fallback.
19. Timeout do Ollama não quebra plano.
20. Saída padrão do plan não é JSON.
21. `plan --json` é JSON válido.

---

# 8. Validação obrigatória no submódulo

Execute exatamente:

```bash
cd /etc/kryonix/packages/kryonix-home

cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all
cargo build
git diff --check
```

Se qualquer comando falhar:

- pare;
- corrija;
- rode tudo novamente;
- não faça commit antes de passar.

---

# 9. Sandbox obrigatório no superprojeto

Execute:

```bash
cd /etc/kryonix

tmp="$(mktemp -d)"
mkdir -p "$tmp/Downloads"
mkdir -p "$tmp/Documents/ProjetoTeste"
mkdir -p "$tmp/Music/kryonix"
mkdir -p "$tmp/Documents/Obsidian Vault/.obsidian"
mkdir -p "$tmp/.ssh"
mkdir -p "$tmp/PastaSolta"

printf "comprovante pix banco inter valor pago" > "$tmp/Downloads/arquivo_generico.txt"
printf "matriz curricular disciplina avaliação curso" > "$tmp/Downloads/notas_aula.txt"
printf "# Projeto\n" > "$tmp/Documents/ProjetoTeste/README.md"
printf "comprovante pix banco" > "$tmp/Documents/ProjetoTeste/comprovante.txt"
printf "{ outputs = { self }: {}; }" > "$tmp/Music/kryonix/flake.nix"
printf "{}" > "$tmp/Documents/Obsidian Vault/.obsidian/app.json"
printf "SECRET" > "$tmp/.ssh/id_ed25519"
printf "arquivo solto na raiz" > "$tmp/arquivo_na_raiz.txt"
printf "arquivo em pasta fora da lista antiga" > "$tmp/PastaSolta/nota.txt"

HOME="$tmp" nix run .#kryonix -- home scan --full-home
HOME="$tmp" nix run .#kryonix -- home projects
HOME="$tmp" nix run .#kryonix -- home projects --json > /tmp/projects.json
jq . /tmp/projects.json >/dev/null

HOME="$tmp" nix run .#kryonix -- home plan --content-aware --context-aware --summary
HOME="$tmp" nix run .#kryonix -- home plan --content-aware --context-aware --why
HOME="$tmp" nix run .#kryonix -- home plan --content-aware --context-aware --json > /tmp/plan.json
jq . /tmp/plan.json >/dev/null

HOME="$tmp" nix run .#kryonix -- home diagnose "$tmp/Downloads/arquivo_generico.txt"
HOME="$tmp" nix run .#kryonix -- home diagnose "$tmp/Downloads/arquivo_generico.txt" --json > /tmp/diagnose.json
jq . /tmp/diagnose.json >/dev/null

! rg "SECRET" /tmp/projects.json /tmp/plan.json /tmp/diagnose.json

rm -rf "$tmp"
```

Critérios:

- arquivo na raiz é inventariado;
- `PastaSolta` é inventariada;
- `.ssh/id_ed25519` não aparece com conteúdo;
- `SECRET` não aparece em nenhuma saída;
- plan padrão é bonito, não JSON;
- JSON só com `--json`.

---

# 10. Validação Nix e CLI

Execute:

```bash
cd /etc/kryonix

bash -n packages/kryonix-cli/*.sh
git diff --check

nix build .#kryonix-home --no-link
nix build .#kryonix --no-link
nix flake check --keep-going

nix run .#kryonix -- home --help
nix run .#kryonix -- home scan --help
nix run .#kryonix -- home plan --help
nix run .#kryonix -- home diagnose --help
nix run .#kryonix -- home projects --help
```

---

# 11. Runtime real sem mutação

Na Home real, só leitura/planejamento:

```bash
cd /etc/kryonix

nix run .#kryonix -- home scan --full-home
nix run .#kryonix -- home plan --summary
nix run .#kryonix -- home plan --content-aware --context-aware --summary
nix run .#kryonix -- home plan --content-aware --context-aware --why --limit 30
```

Não rodar:

```bash
kryonix home apply --confirm
```

---

# 12. Commit e push

## Submódulo

Se `packages/kryonix-home` foi alterado:

```bash
cd /etc/kryonix/packages/kryonix-home

git status --short
git add .
git diff --cached --name-status
git commit -m "feat(home): add full-home content-aware planning"
git push origin main
HOME_COMMIT="$(git rev-parse HEAD)"
echo "kryonix-home commit: $HOME_COMMIT"
```

## Superprojeto

```bash
cd /etc/kryonix

nix flake update kryonix-home

git status --short
git add flake.lock packages/kryonix-home packages/kryonix-cli/main.sh docs scripts
git diff --cached --name-status
git commit -m "feat(home): wire full-home content-aware planner"
git push origin main

SUPER_COMMIT="$(git rev-parse HEAD)"
echo "kryonix superproject commit: $SUPER_COMMIT"
```

---

# 13. Pull no Glacier

Depois do push:

```bash
ssh glacier-public '
set -euo pipefail

cd /etc/kryonix

git fetch origin
git switch main
git pull --ff-only origin main
git submodule sync --recursive
git submodule update --init --recursive

nix build .#kryonix --no-link
nix build .#kryonix-home --no-link

nix run .#kryonix -- home scan --help
nix run .#kryonix -- home plan --help
nix run .#kryonix -- home diagnose --help
'
```

Não executar `apply --confirm` no Glacier.

---

# 14. Relatório final obrigatório

A resposta final deve ter exatamente este formato:

```md
# Relatório Final — Kryonix Home Brain Full-Home Content-Aware

## Status
APROVADO / PARCIAL / REPROVADO

## Commits
- kryonix-home:
- superprojeto:

## O que mudou
- Full-home scan:
- Content-aware:
- Context-aware:
- Ollama:
- Downloads:
- UI/tabela:
- Wrapper:

## Provas executadas
### Submódulo
- cargo fmt:
- cargo clippy:
- cargo test:
- cargo build:
- git diff --check:

### Superprojeto
- bash -n:
- nix build .#kryonix-home:
- nix build .#kryonix:
- nix flake check:

### Sandbox
- full-home scan:
- protected metadata-only:
- content-aware:
- projects:
- diagnose:
- JSON explicit:
- saída padrão não JSON:
- secret não vazou:

### Runtime real
- scan real:
- plan summary:
- plan why:

### Glacier
- pull:
- build:
- help commands:

## Segurança
- apply --confirm real executado? NÃO
- secrets lidos? NÃO
- JSON padrão? NÃO
- Brain/Neo4j/GraphRAG/WayVNC alterados? NÃO

## Exemplo de saída
Cole aqui uma tabela real:
DE ONDE ESTÁ -> PARA ONDE VAI

## Limitações restantes
Liste claramente.

## Próximo passo recomendado
Somente depois revisar `kryonix home plan --why`.
```

---

# 15. Critério de aprovação

Só declare **APROVADO** se tudo abaixo for verdade:

```txt
- scan cobre /home/$USER inteiro por metadados;
- conteúdo seguro é lido com limite;
- paths sensíveis são metadata-only;
- Downloads sempre gera proposta de saída;
- plan padrão é visual e não JSON;
- tabela origem/destino aparece;
- projects --json funciona;
- diagnose funciona;
- Ollama é opcional e tem fallback;
- cargo fmt/clippy/test/build passam;
- nix build/check passa;
- sandbox prova que SECRET não vazou;
- runtime real foi executado sem mutação;
- Glacier recebeu pull/build;
- nenhum apply real foi executado.
```

Se qualquer item falhar, responda **PARCIAL** e explique exatamente o que falta.
