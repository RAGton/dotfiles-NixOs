# Estratégia de Execução — Kryonix Home Brain (faseada)

> O prompt completo (PROMPT.md) é correto mas grande demais para uma execução.
> Esta estratégia fatia em 5 fases independentes. Cada fase: compila → testa →
> commita ANTES da próxima. Se uma falhar, as anteriores já estão salvas.
>
> Princípio: cada fase entrega algo que FUNCIONA e é VERIFICÁVEL isoladamente.

---

## Por que faseado

Tentativas anteriores falharam porque o escopo é enorme. Ao fatiar:
- Cada fase tem critério de sucesso objetivo (cargo test passa)
- Falha numa fase não perde o trabalho das anteriores
- O agente não se perde tentando fazer 10 coisas ao mesmo tempo
- Você consegue validar incrementalmente em vez de tudo no fim

---

## FASE 0 — Auditoria e baseline (não escreve código)

Antes de tudo, estabelecer o que já existe e o que está quebrado.

```bash
cd /etc/kryonix/packages/kryonix-home

# O que já compila hoje?
cargo build 2>&1 | tail -20
cargo test --all 2>&1 | tail -30

# Estrutura atual
ls src/
wc -l src/*.rs

# O que cada comando faz hoje?
cd /etc/kryonix
nix run .#kryonix -- home scan --help 2>&1 | head -20
nix run .#kryonix -- home plan --help 2>&1 | head -20

# Quais structs/funções já existem?
grep -n 'pub struct\|pub fn' /etc/kryonix/packages/kryonix-home/src/scanner.rs | head -30
grep -rln 'content\|context\|ollama' /etc/kryonix/packages/kryonix-home/src/
```

**Entregável Fase 0:** relatório do estado atual. O que existe, o que compila,
o que falta. SEM escrever código ainda. Só mapear o terreno.

**Checkpoint:** não avançar sem entender o que já está implementado vs o que o
PROMPT.md pede. Muita coisa do prompt pode já existir parcialmente.

---

## FASE 1 — Full Home Scan (só o scanner)

Escopo: APENAS `src/scanner.rs`. Nada de content, context, ollama ainda.

Do PROMPT.md, implementar somente a seção **4.1 Full Home Scan seguro**:
- Inventariar `/home/<user>` inteiro por metadados
- Flags `--full-home`, `--metadata-only`, `--safe-content`
- Campos da struct de scan (path, mime, source_zone, metadata_only, etc.)
- Detecção de `source_zone`
- Paths protegidos → `metadata_only=true`, sem ler conteúdo

**Testes desta fase (do PROMPT.md seção 7):**
- #1 scan inventaria arquivo na raiz da Home
- #2 scan inventaria diretório fora da lista antiga
- #3 paths protegidos são metadata_only
- #4 `.env` não é lido
- #5 `.ssh/id_ed25519` não é lido

**Validação:**
```bash
cd /etc/kryonix/packages/kryonix-home
cargo fmt --check && cargo clippy -- -D warnings && cargo test --all && cargo build
```

**Commit (só se tudo passar):**
```bash
git add src/scanner.rs tests/
git commit -m "feat(home): full-home metadata scan seguro"
```

**Checkpoint:** o scan cobre a home inteira e protege secrets. Provado por teste.
Não avançar sem os 5 testes passando.

---

## FASE 2 — Content-Aware (leitura segura de conteúdo)

Escopo: APENAS `src/content.rs`. Depende da Fase 1.

Do PROMPT.md, seção **4.2 Content-Aware**:
- Struct `ContentProfile`
- `analyze_content_safe(path, limit_bytes)`
- Extensões permitidas até 64 KiB
- IPYNB sem executar (parsear JSON)
- PDF via pdftotext (3 páginas / 32 KiB)
- Nunca ler protegidos

**Testes desta fase:**
- #6 `.txt` com "comprovante pix banco inter" → financeiro
- #7 arquivo com "matriz curricular disciplina" → acadêmico
- #9 notebook `.ipynb` extrai título/imports sem executar

**Validação + commit:** mesma rotina cargo da Fase 1.

```bash
git commit -m "feat(home): content-aware safe reader"
```

**Checkpoint:** conteúdo de arquivo seguro é lido e classificado. Secrets nunca lidos.

---

## FASE 3 — Context-Aware + Downloads + Planner

Escopo: `src/context.rs`, ajustes em `planner.rs`, `taxonomy.rs`, `project.rs`.
Depende das Fases 1 e 2.

Do PROMPT.md, seções **4.3, 4.4, 4.5**:
- Struct `FolderContext`
- Detecção de context_mismatch
- Projetos → `Projetos/<categoria>` (não `Documentos/Projetos`)
- Vault Obsidian → `conhecimento.vault`
- Downloads sempre gera proposta de saída
- Campos novos no `PlanProposal`

**Testes desta fase:**
- #8 arquivo em pasta errada → context_mismatch=true
- #10 projeto em Downloads → proposta Projetos/...
- #11 projeto em Music → warning
- #12 Obsidian Vault → conhecimento.vault
- #13 Downloads sempre gera proposta
- #14 desconhecido em Downloads → 00_Inbox/Downloads/Revisar

**Validação + commit:**
```bash
git commit -m "feat(home): context-aware + downloads sempre limpa"
```

**Checkpoint:** classificação considera pasta, vizinhos e projeto. Downloads sempre proposta.

---

## FASE 4 — UX terminal + Diagnose (sem Ollama)

Escopo: output bonito do `plan`, comando `diagnose`, wrapper CLI.
Depende das Fases 1-3.

Do PROMPT.md, seções **4.6, 5, 6**:
- `kryonix home plan` com dashboard + tabela DE ONDE → PARA ONDE
- `kryonix home diagnose <arquivo>` com saída estilizada
- `--why`, `--summary`, `--json`
- Wrapper `main.sh` roteando os subcomandos

**Testes desta fase:**
- #15 `projects --json` é JSON válido
- #16 `diagnose --json` é JSON válido
- #20 saída padrão do plan NÃO é JSON
- #21 `plan --json` é JSON válido

**Validação + commit:**
```bash
git commit -m "feat(home): UX terminal profissional + diagnose"
```

**Checkpoint:** plan e diagnose têm saída humana bonita. JSON só com --json.

---

## FASE 5 — Ollama Advisor (opcional, por último)

Escopo: APENAS `src/ollama.rs`. Depende de tudo anterior.
Por último porque é o ÚNICO componente que pode ficar pra depois sem quebrar nada.

Do PROMPT.md, seção **4.7**:
- `--ollama` liga diagnóstico por LLM
- Ollama só sugere, nunca executa
- Fallback determinístico se falhar
- Não enviar conteúdo sensível
- Timeout 20s
- Endpoint por prioridade (env vars → localhost)

**Testes desta fase:**
- #17 Ollama JSON válido é parseado
- #18 Ollama inválido usa fallback
- #19 timeout do Ollama não quebra plano

**Validação + commit:**
```bash
git commit -m "feat(home): ollama advisor opcional com fallback"
```

**Checkpoint:** Ollama enriquece mas nunca bloqueia. Glacier offline = fallback funciona.

---

## FASE 6 — Integração final (superprojeto + glacier)

Só depois das 5 fases commitadas no submódulo.

```bash
# Atualizar o lock do submódulo no superprojeto
cd /etc/kryonix
nix flake update kryonix-home

# Build completo
nix build .#kryonix-home --no-link
nix build .#kryonix --no-link
nix flake check --keep-going

# Sandbox completo (do PROMPT.md seção 9)
# [rodar o bloco de sandbox com HOME=$(mktemp -d)]

# Commit do superprojeto
git add flake.lock packages/kryonix-home packages/kryonix-cli/main.sh
git commit -m "feat(home): wire full-home content-aware planner"
git push origin main

# Glacier pull (do PROMPT.md seção 13)
ssh glacier-public 'cd /etc/kryonix && git pull --ff-only && nix build .#kryonix --no-link'
```

---

## Regras que valem para TODAS as fases

1. **Uma fase por vez.** Não começar a Fase N+1 sem a Fase N commitada e verde.
2. **cargo fmt + clippy + test + build** tem que passar antes de cada commit.
3. **Nunca** rodar `apply --confirm` na home real. Sandbox só em `mktemp -d`.
4. **Nunca** ler conteúdo de secrets (lista do PROMPT.md seção 2).
5. Se uma fase falhar, parar e reportar — não pular pra próxima.
6. Se distrair com erro de outra parte → anotar, não corrigir agora.
7. Ao fim de cada fase, reportar: o que mudou, testes que passaram, commit hash.
8. Não declarar sucesso sem os comandos de validação executados de verdade.

---

## Por que esta ordem

```
Fase 1 (scan)     → base de tudo, sem ela nada funciona
Fase 2 (content)  → precisa do scan para saber o que ler
Fase 3 (context)  → precisa de content para decidir mismatch
Fase 4 (UX)       → precisa de plan completo para exibir
Fase 5 (ollama)   → enriquece o que já funciona, 100% opcional
Fase 6 (integra)  → só depois de tudo provado no submódulo
```

Cada fase entrega valor sozinha. Se parar na Fase 4, você já tem um sistema
content+context-aware funcional, só sem Ollama. Nada fica pela metade.

---

## Como usar com o agente

Passar UMA fase por vez:

```
@fix/PROMPT.md execute APENAS a FASE 1 da estratégia em
fix/ESTRATEGIA_HOME_BRAIN_FASEADA.md.
Pare após o commit da Fase 1 e reporte. Não avance para a Fase 2.
```

Quando a Fase 1 estiver verde e commitada, aí sim:

```
Execute a FASE 2. Pare após o commit. Reporte.
```

E assim por diante. Cada fase é uma conversa separada com o agente — isso
evita que ele se perca e força validação incremental.
