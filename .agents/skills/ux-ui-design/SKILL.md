---
name: ux-ui-design
description: External project skill — not related to kryonix internals. Use for web/product design projects outside the kryonix stack (React apps, SaaS products, Figma, design systems, CSS/Tailwind). For Hyprland/Caelestia visual work within kryonix, use hyprland-performance instead.
---

# UX & UI Design

## Processo de design centrado no usuário

```
Descoberta → Definição → Ideação → Prototipagem → Teste → Implementação
    │              │           │          │            │          │
  Research     Problem      Sketches  Wireframes   Usability   Handoff
  Entrevistas  Statement   HMW       Mockups      Testing      Dev Specs
  Analytics    Personas    Crazy 8s  Prototype    A/B Test     Design Tokens
```

## Hierarquia de decisões de design

```
1. Função — resolve o problema do usuário?
2. Usabilidade — é fácil de usar?
3. Acessibilidade — todos conseguem usar?
4. Estética — é visualmente consistente e agradável?
```

## Design System — estrutura

```
tokens/
├── colors.json      # paleta base
├── typography.json  # tipo, tamanhos, pesos
├── spacing.json     # escala de espaçamento
└── shadows.json     # sombras

components/
├── atoms/           # Button, Input, Badge, Icon
├── molecules/       # SearchBar, FormField, Card
├── organisms/       # Header, Sidebar, DataTable
└── templates/       # PageLayout, DashboardLayout
```

## Design Tokens — exemplo

```json
{
  "color": {
    "primary": { "50": "#eff6ff", "500": "#3b82f6", "900": "#1e3a8a" },
    "neutral": { "50": "#f9fafb", "500": "#6b7280", "900": "#111827" },
    "success": { "500": "#22c55e" },
    "error":   { "500": "#ef4444" },
    "warning": { "500": "#f59e0b" }
  },
  "typography": {
    "size": { "xs": "0.75rem", "sm": "0.875rem", "base": "1rem",
              "lg": "1.125rem", "xl": "1.25rem", "2xl": "1.5rem" },
    "weight": { "regular": 400, "medium": 500, "semibold": 600, "bold": 700 }
  },
  "spacing": { "1": "0.25rem", "2": "0.5rem", "4": "1rem",
               "8": "2rem", "16": "4rem" }
}
```

## Tipografia — sistema

```css
/* Escala tipográfica com proporção aurea (~1.25) */
--text-xs:   0.75rem;   /* 12px — labels, captions */
--text-sm:   0.875rem;  /* 14px — body secundário */
--text-base: 1rem;      /* 16px — body principal */
--text-lg:   1.125rem;  /* 18px — subtítulos */
--text-xl:   1.25rem;   /* 20px — h3 */
--text-2xl:  1.5rem;    /* 24px — h2 */
--text-3xl:  1.875rem;  /* 30px — h1 */

/* Regras gerais */
line-height: 1.5 para texto corrido; 1.25 para headings
max-width: 65-75ch para parágrafos (leiturabilidade)
```

## Cores — sistema funcional

```
Paleta mínima funcional:
  Primary     — ação principal, brand
  Secondary   — ação secundária
  Neutral     — texto, bordas, fundos
  Success     — confirmações, positivo
  Error       — erros, destrutivo
  Warning     — alertas
  Info        — informacional

Regra 60-30-10:
  60% — cor neutra (fundo, superfícies)
  30% — cor secundária (sidebar, cards)
  10% — cor primária (CTAs, destaques)
```

## Acessibilidade — WCAG 2.1 checklist

```
Contraste:
  ✓ Texto normal: 4.5:1 mínimo (AA)
  ✓ Texto grande (>18px): 3:1 mínimo
  ✓ Componentes UI: 3:1 mínimo

Teclado:
  ✓ Todos elementos interativos são focáveis
  ✓ Ordem de foco lógica (Tab)
  ✓ Esc fecha modais e dropdowns
  ✓ Atalhos de teclado para ações principais

Semântica HTML:
  ✓ Headings em ordem (h1 > h2 > h3)
  ✓ Imagens com alt descritivo
  ✓ Formulários com <label> associado
  ✓ Botões com texto ou aria-label
  ✓ role e aria-* quando necessário
```

## Componente Button — especificação completa

```typescript
// Variantes
type Variant = 'primary' | 'secondary' | 'ghost' | 'danger'
type Size = 'sm' | 'md' | 'lg'

// Estados visuais obrigatórios:
// default, hover, active (pressed), focus-visible, disabled, loading

// Tailwind — Button primário
const buttonStyles = {
  base: "inline-flex items-center justify-center font-medium rounded-lg \
         transition-colors focus-visible:outline-none focus-visible:ring-2 \
         focus-visible:ring-blue-500 focus-visible:ring-offset-2 \
         disabled:opacity-50 disabled:cursor-not-allowed",
  primary: "bg-blue-600 text-white hover:bg-blue-700 active:bg-blue-800",
  sm: "px-3 py-1.5 text-sm gap-1.5",
  md: "px-4 py-2 text-base gap-2",
  lg: "px-6 py-3 text-lg gap-2.5",
}
```

## Fluxo de usuário — notação

```
[Página]  →  (Decisão?)  →  <Ação>  →  {Sistema}

Exemplo — onboarding:
[Landing] → <Criar conta> → [Form cadastro] → (Email válido?)
  → Sim → {Enviar email} → [Verificar email] → [Dashboard]
  → Não → [Form] com erro "Email inválido"
```

## Métricas de UX

```
Quantitativas:
  Task completion rate    — % que completa a tarefa
  Time on task            — tempo médio por tarefa
  Error rate              — erros por sessão
  Conversion rate         — % que converte
  Bounce rate             — % que sai sem interagir

Qualitativas:
  SUS (System Usability Scale) — score 0-100 (>68 = acima da média)
  NPS (Net Promoter Score)     — recomendaria?
  CSAT (Customer Satisfaction) — satisfação pontual
```

## Handoff para desenvolvimento

```
Especificações necessárias no Figma/Zeplin:
  ✓ Espaçamentos exatos (px ou rem)
  ✓ Cores em hex/hsl + token name
  ✓ Estados interativos (hover, focus, disabled)
  ✓ Comportamento responsivo (breakpoints)
  ✓ Animações (duração, easing)
  ✓ Textos com fonte/peso/tamanho/line-height
  ✓ Casos extremos (texto longo, sem dados, erro)
```

## Referências adicionais
- **Atomic Design detalhado**: ver [references/atomic-design.md](references/atomic-design.md)
- **Testes de usabilidade**: ver [references/usability-testing.md](references/usability-testing.md)
- **Motion design e animações**: ver [references/motion.md](references/motion.md)
- **Figma workflows**: ver [references/figma.md](references/figma.md)
