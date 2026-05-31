---
name: software-architecture
description: External project skill — not related to kryonix internals. Use for software architecture decisions on external applications (Clean Architecture, DDD, CQRS, multi-tenant SaaS, microservices, API design, ADR). For kryonix module/profile/feature architecture decisions, use nix-host-implementation instead.
---

# Arquitetura & Engenharia de Software

## Framework de decisão arquitetural

```
Antes de propor arquitetura, responda:
  1. Escala esperada? (usuários, dados, requests/s)
  2. Equipe? (1 dev, time pequeno, multiple times)
  3. Requisitos de consistência? (eventual ok? forte necessário?)
  4. Budget de complexidade? (maturidade da equipe)
  5. Prazo? (MVP vs produto maduro)

Regra de ouro: complexidade mínima que resolve o problema real.
```

## Multi-tenant — Isolamento Sistêmico (Erro 9 resolvido)

### AsyncLocalStorage + Middleware (Node.js)

```typescript
// src/context/tenant-context.ts
import { AsyncLocalStorage } from 'async_hooks';

interface TenantContext { tenantId: string; }

export const tenantStorage = new AsyncLocalStorage<TenantContext>();

export function getTenantId(): string {
  const ctx = tenantStorage.getStore();
  if (!ctx?.tenantId) throw new Error('TENANT_CONTEXT_MISSING — query bloqueada');
  return ctx.tenantId;
}
```

```typescript
// src/middleware/tenant.middleware.ts
import { tenantStorage } from '../context/tenant-context';
import jwt from 'jsonwebtoken';

export function tenantMiddleware(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Unauthorized' });

  const payload = jwt.verify(token, process.env.JWT_SECRET) as any;
  if (!payload.tenantId) return res.status(403).json({ error: 'No tenant' });

  // Injeta contexto — disponível em TODA a cadeia da request
  tenantStorage.run({ tenantId: payload.tenantId }, next);
}
```

```typescript
// src/repositories/base.repository.ts — filtro automático e invisível
import { getTenantId } from '../context/tenant-context';

export class BaseRepository {
  protected db: Knex;

  // Todo método que acessa dados HERDA este filtro
  protected tenantQuery(table: string) {
    return this.db(table).where('tenant_id', getTenantId());
    // Se contexto não existir, getTenantId() LANÇA ERRO → fail-safe
  }
}

// Uso em qualquer repositório filho:
export class ContractRepository extends BaseRepository {
  findAll() {
    return this.tenantQuery('contracts').select('*');
    // WHERE tenant_id = ? aplicado automaticamente — dev não precisa lembrar
  }
}
```

### Prisma — Middleware de tenant

```typescript
// src/lib/prisma.ts
prisma.$use(async (params, next) => {
  const tenantId = getTenantId(); // falha se contexto ausente

  const TENANT_MODELS = ['Contract', 'Invoice', 'Unit'];
  if (TENANT_MODELS.includes(params.model)) {
    if (params.action === 'findMany' || params.action === 'findFirst') {
      params.args.where = { ...params.args.where, tenantId };
    }
    if (params.action === 'create') {
      params.args.data = { ...params.args.data, tenantId };
    }
  }
  return next(params);
});
```

## Clean Architecture

```
src/
├── domain/           # Entidades, Value Objects, regras de negócio puras
│   ├── entities/
│   ├── value-objects/
│   └── repositories/ (interfaces)
├── application/      # Use cases, orquestração, sem deps externas
│   └── use-cases/
├── infrastructure/   # DB, APIs externas, implementações concretas
│   ├── repositories/
│   └── external/
└── interface/        # HTTP, CLI, eventos — só chama application
    └── http/
```

**Regra de dependência**: setas apontam SEMPRE para dentro (domain).
Domain não conhece nada externo.

## CQRS + Event Sourcing

```typescript
// Command — muda estado
class CreateContractCommand {
  constructor(public readonly tenantId: string,
              public readonly data: CreateContractDto) {}
}

// Query — lê estado (modelo otimizado para leitura)
class GetContractsByTenantQuery {
  constructor(public readonly tenantId: string) {}
}

// Evento imutável — fato que aconteceu
class ContractCreatedEvent {
  readonly occurredAt = new Date();
  constructor(public readonly contractId: string,
              public readonly tenantId: string,
              public readonly data: ContractSnapshot) {}
}
```

## DDD — Bounded Contexts

```
Identifique contextos separados:
  [Locação] ←→ [Financeiro] ←→ [Notificações]

Cada contexto tem:
  - Sua própria linguagem ubíqua (ubiquitous language)
  - Seus próprios modelos de domínio
  - Comunicação via eventos/API (não acesso direto ao DB alheio)

Anti-pattern: um único ORM que modela TODOS os contextos juntos.
```

## Design de API REST

```
Recursos como substantivos, verbos HTTP como ações:
  GET    /contracts          → listar
  GET    /contracts/:id      → buscar um
  POST   /contracts          → criar
  PUT    /contracts/:id      → substituir
  PATCH  /contracts/:id      → atualizar parcialmente
  DELETE /contracts/:id      → remover

Versionamento: /api/v1/...
Paginação: ?page=1&limit=20&sort=createdAt:desc
Erros padronizados: { error: { code: "RESOURCE_NOT_FOUND", message: "..." } }
```

## ADR — Architecture Decision Record

```markdown
# ADR-001: Isolamento multi-tenant via AsyncLocalStorage

**Status**: Aceito
**Contexto**: Risco de vazamento de dados entre tenants se filtros manuais.
**Decisão**: AsyncLocalStorage injeta tenantId no contexto da request.
  BaseRepository.tenantQuery() aplica filtro automaticamente.
  Ausência de contexto lança erro (fail-safe).
**Consequências**: 
  + Desenvolvedor não pode esquecer o filtro — é sistêmico
  + Teste unitário precisa mockar o contexto
  - Debugging de AsyncLocalStorage pode ser não-óbvio
```

## Checklist de revisão arquitetural

- [ ] Dependências apontam para dentro (domain não importa infra)
- [ ] Tenant isolation sistêmica e fail-safe
- [ ] Casos de uso testáveis sem DB/HTTP
- [ ] Eventos de domínio para comunicação entre contextos
- [ ] ADR para decisões importantes
- [ ] SLA definido e observabilidade planejada

## Referências adicionais
- **Microsserviços e comunicação**: ver [references/microservices.md](references/microservices.md)
- **Diagramas C4**: ver [references/c4-diagrams.md](references/c4-diagrams.md)
- **Segurança e OWASP**: ver [references/security.md](references/security.md)
- **Padrões de banco de dados**: ver [references/database-patterns.md](references/database-patterns.md)
