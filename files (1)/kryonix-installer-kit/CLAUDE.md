# Kryonix Installer — Kit de Diagnóstico e Fix Iterativo

Diagnóstico, correção e testes do **Kryonix Installer** (Kiosk + Web): stack Rust/Axum (backend) + Vite (frontend).
Objetivo: kiosk lança a interface web em fullscreen; web installer funciona como página fixa + trocas de estado.

## Princípios de trabalho
- **Diagnóstico antes de fix**: não alucine o erro — rode, veja, reporte.
- **VM testing obrigatório**: toda mudança se valida em VM, nunca assume "pronto no build".
- **Iteração rápida**: commit pequeno, teste, rollback se quebrou, próximo.
- **Nada secreto no installer**: brain.env é RUNTIME, nunca builder.

## Layout do instalador
```
packages/kryonix-installer/
├── backend/              # Axum (Rust)
│   ├── src/main.rs
│   ├── Cargo.toml
│   └── src/routes/      # endpoints
├── frontend/             # Vite (TypeScript/React)
│   ├── src/
│   ├── vite.config.ts
│   └── package.json
├── kiosk/               # Wrapper kiosk (lança web em fullscreen)
│   ├── kiosk.nix        # home-manager module
│   └── launch.sh        # script bash que roda a aplicação
└── package.nix          # nix expr que builda tudo
```

## Contrato de sucesso (DoD)
- [ ] Backend compila sem erro (cargo build --release).
- [ ] Frontend builda sem erro (npm run build).
- [ ] ISO é criada com o instalador integrado.
- [ ] Em VM: kiosk.service inicia e lança a web em fullscreen.
- [ ] Em VM: web responde a interações (cliques, formulário).
- [ ] Em VM: backend registra requisições sem erro (logs limpios).
- [ ] Rollback de qualquer passo retorna à versão anterior intacta.

## Regras críticas
- Nunca rodar `nixos-rebuild switch` no installer — test em VM antes.
- Logs do backend em `/tmp/installer.log` ou stderr de systemd.
- Frontend buildado staticamente, servido como `/static` pelo Axum.
- Kiosk usa cgroup/systemd/wayland para ambiente isolado.

@AGENTS.md
