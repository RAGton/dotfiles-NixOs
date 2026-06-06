# Design Patterns Uteis

## Objetivo

Usar padrões como ferramenta, não como decoração.

## Patterns que aparecem em backend

- Repository quando há troca real de persistência ou testes exigem boundary.
- Strategy para variação explícita de algoritmo/regra.
- Adapter para isolar SDK externo.
- Factory para criação complexa com invariantes.
- Command para jobs/auditoria/ações assíncronas.

## Evitar

- pattern sem problema real;
- abstração antes do segundo consumidor;
- nomes genéricos como Manager/Service sem domínio.

## Links

- [[01-MOCs/Mapa - Engenharia de Software]]
