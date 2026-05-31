---
name: kryonix-audit
description: Audita a estrutura do repositório Kryonix (arquivos Nix, documentação, artefatos soltos) e propõe um padrão de diretórios mais limpo.
allowed-tools:
  - Bash
---

# Skill: Auditoria do Repositório Kryonix

Para auditar o repositório, utilize a ferramenta Bash e execute os seguintes comandos de busca de forma independente, sem encadear loops complexos:

1. Contagem de arquivos Nix: `find . -name "*.nix" -not -path '*/.git/*' | wc -l`
2. Contagem de Markdown: `find . -name "*.md" -not -path '*/.git/*' | wc -l`
3. Contagem de scripts Shell: `find . -name "*.sh" -not -path '*/.git/*' | wc -l`
4. Contagem de arquivos Rust: `find . -name "*.rs" -not -path '*/.git/*' | wc -l`
5. Listagem da raiz: `ls -la`
6. Busca por diretórios de IA dispersos: `ls -d .ai .agents .context skills 2>/dev/null`

Após coletar essas informações, analise a redundância e proponha uma reorganização incremental, focada em consolidar o contexto da IA na pasta `.agents/` e organizar os pacotes soltos, respeitando a integridade do `flake.nix`.
