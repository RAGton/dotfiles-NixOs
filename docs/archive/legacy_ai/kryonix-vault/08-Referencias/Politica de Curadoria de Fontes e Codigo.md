# Política de Curadoria de Fontes e Código

## Objetivo

Impedir que o Kryonix Vault seja contaminado por código ruim, documentação desatualizada, fórum sem validação ou opinião técnica sem evidência.

Este vault deve priorizar qualidade, segurança, operação real e código mantível.

## Hierarquia de confiança

```txt
Tier 0 — Fonte de verdade local
- código do projeto atual
- testes do projeto
- documentação canônica do projeto
- decisões/ADRs do projeto

Tier 1 — Fontes oficiais
- documentação oficial
- manuais oficiais
- specs
- RFCs
- OWASP
- documentação de linguagem/framework

Tier 2 — Livros técnicos reconhecidos
- livros clássicos
- autores reconhecidos
- materiais usados no mercado/academia

Tier 3 — Repositórios exemplares
- projetos maduros
- CI ativo
- issues/PRs saudáveis
- testes reais
- maintainers ativos
- segurança tratada

Tier 4 — Fóruns e blogs
- úteis para troubleshooting
- nunca fonte única de verdade
- validar contra docs oficiais e testes

Tier 5 — Código aleatório
- não usar como referência sem auditoria
- pode servir apenas como inspiração descartável
```

## Critérios para aceitar código como referência

Código só entra como referência se passar por esta análise:

- [ ] tem licença compatível;
- [ ] é mantido;
- [ ] tem testes;
- [ ] tem CI;
- [ ] não vaza secrets;
- [ ] não usa padrões inseguros;
- [ ] trata erros;
- [ ] tem nomes claros;
- [ ] não depende de estado global desnecessário;
- [ ] não faz shell injection;
- [ ] não usa permissões amplas sem motivo;
- [ ] não ignora falhas;
- [ ] não mistura responsabilidades;
- [ ] é compatível com versões atuais;
- [ ] é compreendido antes de ser adaptado.

## Sinais de código ruim

- ausência total de testes;
- comandos destrutivos sem confirmação;
- `curl | sh` sem verificação;
- `chmod 777`;
- `sudo` espalhado;
- secrets hardcoded;
- SQL/string interpolation insegura;
- shell sem `set -euo pipefail` quando apropriado;
- tratamento de erro com `|| true` sem justificativa;
- funções enormes sem coesão;
- nomes genéricos;
- dependências abandonadas;
- documentação que promete mais do que o código entrega;
- conflito Git no código/docs;
- ausência de rollback em infra.

## Fóruns

Fóruns são úteis para:

- sintomas reais;
- bugs específicos;
- incompatibilidades de hardware;
- comportamento não documentado;
- troubleshooting.

Fóruns não devem ser usados para:

- definir arquitetura;
- copiar script de produção;
- decidir segurança;
- validar contrato de API;
- substituir documentação oficial.

## Livros

Livros entram como referência conceitual, não como lei absoluta.

Sempre adaptar ao contexto:

- tamanho do projeto;
- equipe;
- criticidade;
- custo operacional;
- stack;
- tempo de manutenção.

## Como registrar fonte no vault

Use este formato:

```md
# Fonte - <nome>

## Tipo
Documentação oficial | livro | fórum | repo | blog | artigo

## Link

## Confiabilidade
Tier 0-5

## O que é útil

## O que NÃO copiar cegamente

## Riscos

## Como validar

## Notas relacionadas
```

## Regra final

Nenhum código externo vira padrão do Kryonix Vault sem passar por revisão técnica.

O objetivo não é copiar muito.
O objetivo é absorver decisões boas e evitar dívidas ruins.
