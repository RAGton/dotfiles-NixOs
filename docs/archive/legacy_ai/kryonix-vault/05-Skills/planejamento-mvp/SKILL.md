# Planejamento de MVP

## Objetivo

Transformar ideia em produto mínimo vendável.

## Quando usar

- quando a tarefa se repetir;
- quando precisar de saída padronizada;
- quando houver risco técnico;
- quando for útil reduzir prompt longo.

## Quando não usar

- tarefa trivial;
- ausência de contexto mínimo;
- decisão crítica sem revisão humana;
- produção sem validação.

## Entrada esperada

- objetivo;
- contexto curto;
- arquivos/links relevantes;
- restrições;
- critério de aceite;
- riscos conhecidos.

## Saída esperada

- diagnóstico;
- plano curto;
- recomendações ou patch sugerido;
- checklist;
- riscos restantes;
- links para notas relacionadas.

## Procedimento

1. Confirmar escopo.
2. Identificar risco principal.
3. Usar menor mudança correta.
4. Separar fato, prática, opinião e hipótese.
5. Produzir saída verificável.
6. Sugerir validação.

## Checklist

- [ ] escopo respeitado
- [ ] segurança considerada
- [ ] testes/validação considerados
- [ ] trade-offs explícitos
- [ ] sem hype
- [ ] sem secrets
- [ ] links Obsidian adicionados quando útil

## Riscos

- recomendação genérica;
- falso senso de segurança;
- excesso de abstração;
- mudança maior que o necessário;
- aceitar saída de IA sem revisão.

## Como economiza tokens

Centraliza instruções recorrentes para evitar prompts longos repetidos. O usuário envia apenas o contexto variável.

## Prompt base

```txt
Use a Skill "Planejamento de MVP".

Objetivo: <objetivo>
Contexto: <contexto curto>
Entrada: <dados/arquivos relevantes>
Restrições: <restrições>
Saída esperada: <formato>
Critério de aceite: <validação>

Aplique menor mudança correta, explicite riscos e não invente fatos.
```

## Links relacionados

- [[01-MOCs/Mapa - IA e Agentes]]
- [[PROMPT_MASTER]]
