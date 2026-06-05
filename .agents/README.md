# Kryonix Agent Governance

> **Equipe Kora/Antigravity aposentada.** A Kora foi removida (ver
> `docs/aura/KORA_RETIREMENT_STUDY.md`). A assistente do Kryonix agora é a **Aura**
> (`kryonix.services.aura` — camada de roteamento; motor de execução a ser
> redefinido). Os papéis, workflows e prompts `kora-*`/Antigravity foram
> removidos; restam os artefatos de governança não específicos da Kora.

## Estrutura atual

```txt
.agents/
├── INDEX.md             # Índice de agentes ativos
├── README.md            # Este arquivo
├── roles/
│   └── kryonix-nixos-integrator.md   # Integração NixOS & Home Manager declarativa
├── workflows/
│   └── security-review.md            # Revisão de segurança
├── checklists/          # Gates de validação/segurança (validation, no-secrets, nixos-switch-safety)
└── rules/               # Regras operacionais
```

## Filosofia operacional

1. **Local-First & Soberania**: IA roda localmente (Glacier/Inspiron); sem chamadas de nuvem sem opt-in.
2. **NixOS-Native**: tudo declarativo (módulo NixOS/Home Manager); evitar estado imperativo.
3. **Menor mudança validada**: a menor mudança correta + testes locais antes de `switch`.
4. **Segurança hardened**: secrets nunca no Nix Store/Git; revisão via `workflows/security-review.md`.
