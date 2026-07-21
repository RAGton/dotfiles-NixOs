# Documentação (hub)

Este arquivo é o **ponto de entrada** da documentação. Ele existe para:

- Dar um caminho de leitura rápido (humano vs IA)
- Evitar links quebrados (todos os links aqui são relativos a `docs/`)
- Apontar para guias por tema (operação, migração, desktop, etc.)

## Comece aqui

- Projeto (visão geral): [../README.md](../README.md)
- Projeto (English): [../README-en.md](../README-en.md)
- Visão do produto: [NODE_VE.md](NODE_VE.md)
- Quick start (técnico): [QUICK_START.md](QUICK_START.md)
- Status (o que está feito / pendente): [STATUS.md](STATUS.md)

### Se você é mantenedor (humano)

- Resumo executivo: [SUMMARY.md](SUMMARY.md)
- Auditoria e decisões: [ARCHITECTURE_AUDIT.md](ARCHITECTURE_AUDIT.md)

### Se você é IA (Copilot/ChatGPT)

- Regras e padrões: [INSTRUCT.md](INSTRUCT.md)

### Se você quer migrar/reestruturar (v1 → v2)

- Checklist de migração: [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md)
- Guia de migração: [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
- Estrutura alvo: [NEW_STRUCTURE.md](NEW_STRUCTURE.md)

## Guias por tema

### Operação (day-2)

- Operação diária e CLI `node`: [OPERATIONS.md](OPERATIONS.md)
- Manual do Caelestia no RagOS VE: [CAELESTIA_MANUAL.md](CAELESTIA_MANUAL.md)
- Host principal `glacier`: [GLACIER.md](GLACIER.md)
- Makefile (atalhos e fluxo): [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md)
- Boot/recovery: [BOOT_RECOVERY.md](BOOT_RECOVERY.md)
- Wayland session (testes): [TEST_GUIDE_WAYLAND_SESSION.md](TEST_GUIDE_WAYLAND_SESSION.md)

### Performance

- ZRAM: [performance/zram-pt_BR.md](performance/zram-pt_BR.md)

### Virtualização

- libvirt/virt-manager: [virtualization/libvirt-virt-manager-pt_BR.md](virtualization/libvirt-virt-manager-pt_BR.md)

### Desenvolvimento

- Rust (guia PT-BR): [development/rust-pt_BR.md](development/rust-pt_BR.md)

### Games

- Hogwarts Legacy (Heroic): [games/hogwarts-legacy-heroic-pt_BR.md](games/hogwarts-legacy-heroic-pt_BR.md)

## Relatórios e histórico

- Relatório do mantenedor IA: [AI_MAINTAINER_REPORT.md](AI_MAINTAINER_REPORT.md)
- Duplicações/inconsistências: [BUGFIX_DUPLICATIONS.md](BUGFIX_DUPLICATIONS.md)
- Recursão infinita: [BUGFIX_INFINITE_RECURSION.md](BUGFIX_INFINITE_RECURSION.md)

### Migração (marcos)

- Fase 1: [PHASE_1_COMPLETE.md](PHASE_1_COMPLETE.md)
- Step 1.1–1.3: [STEP_1.1-1.3_COMPLETE.md](STEP_1.1-1.3_COMPLETE.md)
- Step 2.1–2.2: [STEP_2.1-2.2_COMPLETE.md](STEP_2.1-2.2_COMPLETE.md)
- Step 2.3: [STEP_2.3_COMPLETE.md](STEP_2.3_COMPLETE.md)
- Step 3.1: [STEP_3.1_COMPLETE.md](STEP_3.1_COMPLETE.md)
- Step 5.1–5.2: [STEP_5.1-5.2_COMPLETE.md](STEP_5.1-5.2_COMPLETE.md)
- Step 6: [STEP_6_COMPLETE.md](STEP_6_COMPLETE.md)

## Legado

O material legado fica em `docs/legacy/`:

- Greetd (histórico): [legacy/greetd/](legacy/greetd/)
- Hyprland (config antiga): [legacy/hyprland/hyprland.conf](legacy/hyprland/hyprland.conf)

## Nota sobre links

Este índice está em `docs/`, então:

- Link para arquivos do repo (raiz) usa `../` (ex.: [../README.md](../README.md))
- Link para subpastas de docs não usa prefixo `docs/` (ex.: [development/rust-pt_BR.md](development/rust-pt_BR.md))
