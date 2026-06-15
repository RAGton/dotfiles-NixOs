---
name: yt-to-notebook
description: Pega o conteúdo de um notebook do NotebookLM e converte para um formato visual e digerível (frontmatter + TL;DR, diagramas Mermaid, callouts, tabelas, emojis e mindmap), entregando no destino que o usuário escolher — pasta do Obsidian, arquivo markdown solto, ou Notion via conector. Use SEMPRE que o usuário quiser passar/extrair/transferir o conteúdo de um notebook do NotebookLM para uma nota/arquivo/documento, "jogar o conhecimento do notebook X" para o Obsidian/Notion/markdown, transformar uma fonte do NotebookLM em material estruturado, ou pedir "yt-to-notebook". Dispare mesmo sem as palavras exatas, quando a intenção for levar conhecimento do NotebookLM para uma nota bonita e bem estruturada.
---

# yt-to-notebook — do NotebookLM para uma nota visual (no destino que o usuário escolher)

Esta skill pega o conhecimento de um **notebook do NotebookLM** e o reescreve naquele **formato visual e digerível** (TL;DR + diagramas Mermaid + callouts + tabelas + emojis + mindmap), entregando **onde o usuário quiser**: numa pasta do Obsidian, como arquivo `.md` solto, ou no Notion via conector.

O princípio que orienta tudo: **o formato é a constante; o destino é variável.** Não assuma nenhuma estrutura de vault — o usuário decide a pasta, o nome e (se tiver) as convenções próprias dele. A skill entrega o conteúdo no formato; ela não impõe a organização de ninguém.

## Pré-requisitos

O fluxo usa a CLI do NotebookLM (a skill `notebooklm` cobre os detalhes de cada comando). Antes de tudo, garanta que há sessão ativa:

- `notebooklm auth check` — se falhar, rode `notebooklm login` (abre o navegador; o usuário loga e o fluxo salva a sessão). Se a janela travar, geralmente é uma instância do Chromium já aberta segurando o perfil — peça pro usuário fechá-la antes de tentar de novo.

## Visão geral — 3 fases

1. **Extrair** o conhecimento do notebook (com fidelidade total).
2. **Formatar** no padrão canônico (estrutura + sequência lógica + artes visuais + voz).
3. **Entregar** no destino escolhido, adaptando a sintaxe ao alvo.

## Fase 1 — Localizar e extrair (fidelidade total)

A qualidade da nota depende de capturar **tudo** o que a fonte ensina. Não resuma cedo demais — primeiro entenda o material inteiro.

1. `notebooklm list --json` → ache o notebook pelo título (pergunte ao usuário qual, se houver ambiguidade).
2. `notebooklm source list --notebook <id> --json` → liste as fontes.
3. Para cada fonte: `notebooklm source fulltext <source_id> --notebook <id> --json` → leia o texto integral. É a base da fidelidade.
   - `notebooklm ask "..."` serve como apoio (sínteses temáticas, tirar dúvidas), mas não substitui o `fulltext`.
4. Antes de escrever, faça um **inventário dos conceitos** — cada ideia, metáfora, número e exemplo importante precisa reaparecer na nota. Fidelidade vem antes de brevidade.

## Fase 2 — Formatar no padrão canônico

Antes de escrever a nota, **leia os dois arquivos de referência** — eles são o coração da skill e definem o "nessa estrutura":

- `references/formato-visual.md` — a especificação do formato: sequência lógica das seções, frontmatter mínimo, voz/parágrafos, catálogo de callouts, padrões de Mermaid (com os cuidados de sintaxe que evitam diagramas quebrados) e notas de portabilidade por destino.
- `references/exemplo-gold.md` — um exemplo-ouro completo, pra você ver o padrão na prática e mirar nesse nível de acabamento.

Monte a nota seguindo a **sequência lógica** abaixo. Adapte os títulos ao conteúdo e **omita** as seções que não fizerem sentido (nem toda fonte tem "metáfora" ou "filosofia" — uma fonte técnica pode trocar isso por "passo a passo" e "armadilhas"):

1. `# 🔖 Título` — H1 com um emoji-âncora.
2. `> [!abstract] TL;DR` — a ideia central em 1-2 frases.
3. `> [!info]` — a fonte/contexto (de qual notebook/vídeo veio).
4. **Ideia central / mecanismo** — a tese, com uma tabela comparativa ou diagrama se ajudar a fixar.
5. **Conceitos / metáforas** — onde entram os **diagramas Mermaid** (fluxos).
6. **Operacional** — o "como fazer", em callouts (`tip` / `warning` / `example`).
7. **Camada mais profunda** *(se houver)* — princípios, filosofia, o "porquê".
8. `## 🎯 Como aplicar` — takeaways acionáveis.
9. `## 🗺️ Mapa` — um **mindmap** Mermaid do todo (um fechamento visual satisfatório).
10. `## 📌 Cola rápida` — tabela-resumo de uma olhada.

Aplique o toolkit visual **com critério**: cada diagrama, tabela e callout precisa ajudar a entender — enfeite gratuito polui. Voz: PT-BR, clara, na pegada "digerível e divertida". Siga os cuidados de sintaxe de Mermaid de `formato-visual.md` pra não gerar diagrama quebrado.

## Fase 3 — Entregar no destino

Se o usuário não disse onde quer, **pergunte**: pasta no Obsidian? arquivo `.md` solto (e onde)? Notion?

### Pasta no Obsidian ou arquivo `.md` solto
- Escreva o arquivo no caminho que o usuário indicar. Use **frontmatter mínimo**: `titulo`, `fonte`, `data`. Nada de tags, `hub` ou índice — a menos que o usuário tenha esse sistema **e peça**.
- O markdown é Obsidian-flavored: callouts (`> [!...]`) e Mermaid renderizam nativamente no Obsidian, sem plugin (basta abrir em Reading view ou Live Preview).
- Rode o validador: `python3 <skill-dir>/scripts/validar_nota.py <arquivo.md>` e corrija o que ele apontar.

### Notion (via conector)
- O Notion **não** entende a sintaxe `> [!...]` do Obsidian. Se houver um conector (MCP) do Notion disponível nesta sessão, crie a página mapeando a estrutura para **blocos nativos do Notion**: callout nativo no lugar dos callouts, code block `mermaid` para os diagramas, tabela do Notion, toggles para seções longas.
- Se **não** houver conector do Notion, diga isso claramente e ofereça: (a) entregar o markdown portátil pro usuário colar no Notion, ou (b) ajudar a conectar o MCP do Notion. Nunca finja que existe um conector que não está disponível.

### Destino genérico / outro app
- Entregue **markdown portátil**: Mermaid, tabelas, emojis e blockquotes são universais; os callouts degradam para blockquotes simples em viewers que não os suportam — segue legível, sem problema.

Ao final, **reporte**: o que foi criado e onde, um mini-checklist de fidelidade (os principais conceitos cobertos) e peça pro usuário conferir o render.

## Anti-padrões (evite)

- **Perder conteúdo.** Fidelidade > brevidade. Na dúvida entre cortar e manter, mantenha.
- **Assumir a estrutura do vault de alguém.** Sem pastas fixas, sem `#hub/...`, sem índice automático — a menos que o usuário tenha e peça.
- **Mermaid quebrado.** Use `<br/>` (não `\n`) pra quebra de linha; no `mindmap`, evite `( ) [ ] = : /` nos rótulos. Detalhes e exemplos em `formato-visual.md`.
- **Inventar a fonte.** Cite de qual notebook/fonte o conhecimento veio.
- **Pular a validação** em destinos markdown.

## Arquivos desta skill

- `references/formato-visual.md` — a especificação do formato (leia na Fase 2).
- `references/exemplo-gold.md` — exemplo-ouro completo (leia na Fase 2).
- `scripts/validar_nota.py` — validador estrutural do markdown gerado (rode na Fase 3).
