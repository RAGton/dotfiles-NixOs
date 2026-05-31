# AGENTS.md — Kryonix Installer

Contrato cross-tool para debugging do Kryonix Installer.

## O que é o Installer
Aplicação web (Vite) rodada em servidor Rust (Axum) em fullscreen (Kiosk) durante a instalação do NixOS.
Recebe requisições POST de hardware, disk, instalação; retorna estado em JSON.

## Diagnóstico = Código Real
Não suponha: rode `kryonix iso`, teste em VM, leia o stderr de kiosk.service. Código ativo é a verdade.

## Segurança
- Brain.env nunca é baked no binário — só env var em runtime.
- Frontend não expõe credenciais (localStorage vazio de secrets).
- Backend valida TODAS as entradas (disk, hostname, partições).

## Quando escalalar
- Backend (Axum): se houver erro de binding de porta, panic, ou compilação.
- Frontend (Vite): se houver erro de build, import quebrado, ou UI não renderiza.
- Kiosk (systemd): se service não inicia, se wayland/display não funciona.
- Teste em VM: se tudo builda mas comportamento é diferente de esperado.
