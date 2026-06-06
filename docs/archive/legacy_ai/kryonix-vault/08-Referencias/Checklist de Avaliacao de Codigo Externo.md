# Checklist de Avaliação de Código Externo

Use antes de transformar qualquer código de fórum, blog, GitHub, tutorial ou IA em referência do Kryonix Vault.

## 1. Origem

- [ ] A fonte é oficial ou reconhecida?
- [ ] O autor/projeto é identificável?
- [ ] A licença permite uso?
- [ ] O código é recente o suficiente?
- [ ] O projeto ainda é mantido?

## 2. Segurança

- [ ] Não contém secrets hardcoded.
- [ ] Não usa `chmod 777` sem justificativa.
- [ ] Não executa `curl | sh` sem verificação.
- [ ] Não usa `sudo` de forma ampla.
- [ ] Não executa comandos destrutivos sem confirmação.
- [ ] Não interpola entrada em shell/SQL/path sem sanitização.
- [ ] Não loga tokens, senhas, cookies, chaves ou PII.
- [ ] Usa princípio de menor privilégio.

## 3. Confiabilidade

- [ ] Trata erros explicitamente.
- [ ] Tem timeout quando acessa rede/processo externo.
- [ ] Tem retry/backoff quando faz sentido.
- [ ] É idempotente quando pode ser executado mais de uma vez.
- [ ] Tem rollback ou reversibilidade quando altera estado.

## 4. Qualidade de engenharia

- [ ] Funções coesas.
- [ ] Nomes claros.
- [ ] Baixo acoplamento.
- [ ] Sem estado global desnecessário.
- [ ] Sem abstração prematura.
- [ ] Sem duplicação crítica.
- [ ] Código entendível antes de copiar.

## 5. Testes

- [ ] Tem testes automatizados.
- [ ] Cobre sucesso, falha e borda.
- [ ] Tem teste de regressão para bug conhecido.
- [ ] Pode ser validado localmente.
- [ ] Não depende de produção para testar.

## 6. Infra/Linux/NixOS

- [ ] Tem dry-run quando aplicável.
- [ ] Não muda boot/firewall/storage sem alerta.
- [ ] Não assume paths locais escondidos.
- [ ] Não vaza secrets para Nix store.
- [ ] Não causa lock churn sem motivo.
- [ ] Documenta rollback.

## 7. Frontend

- [ ] HTML semântico.
- [ ] Responsivo.
- [ ] Acessível.
- [ ] Estados de loading/erro/vazio.
- [ ] Performance aceitável.
- [ ] CSS organizado.
- [ ] Dependências justificadas.

## 8. Backend/API

- [ ] Validação de entrada.
- [ ] Autenticação clara.
- [ ] Autorização por objeto/tenant.
- [ ] Erros consistentes.
- [ ] OpenAPI/contrato atualizado.
- [ ] Rate limit quando público/caro.
- [ ] Logs estruturados e seguros.

## Decisão

Classifique:

```txt
ACEITO COMO PADRÃO
ACEITO COMO INSPIRAÇÃO
USAR APENAS COM ADAPTAÇÃO
REJEITADO
```

## Registro

```md
## Código avaliado

## Fonte

## Decisão

## Motivo

## Riscos

## Adaptações necessárias

## Testes exigidos
```
