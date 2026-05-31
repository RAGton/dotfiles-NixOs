# Checklist Final — Installer Pronto

Confira cada item. Quando todos estiverem ✓, o instalador está pronto.

## Build e Compilação
- [ ] `cargo build --release` em backend — compila sem erro.
- [ ] `npm run build` em frontend — gera dist/index.html.
- [ ] `nix build .#nixosConfigurations.iso...` — ISO buildada (~600MB).

## Funcionalidade (em VM)
- [ ] Kiosk lança na boot → interface web visível em fullscreen.
- [ ] Frontend renderiza → form visível com inputs, buttons.
- [ ] Backend responde → curl http://localhost:8080/api/health retorna 200.
- [ ] Navegação → clique "Próximo" muda de tela, POST no backend registrado em logs.
- [ ] Formulário → preenchimento, validação, envio sem erro.

## Segurança
- [ ] Zero credenciais no ISO ou binários (brain.env é env var em runtime).
- [ ] Backend valida todas as entradas (disk paths, hostname, etc).
- [ ] Frontend não expõe secrets em localStorage/cookies.

## Logs e Diagnóstico
- [ ] Erros aparecem em `journalctl` (não em stderr silencioso).
- [ ] Backend loga requisições e respostas (DEBUG ou INFO).
- [ ] Kiosk service status mostra "active (running)" sem erro.

## Rollback
- [ ] `git status` limpo antes de novo build.
- [ ] Cada commit pequeno e revertível via `git revert`.
- [ ] ISO anterior disponível para rollback rápido.

## DoD Final
- Kiosk roda sem erro.
- Web installer funciona end-to-end em VM.
- Instalação completa resulta em NixOS bootável.
- Código reviewado (sem imports soltos, sem TODOs, sem hardcodes).

Se TODOS os itens estão ✓ → Fase 5 (Distro Consumidor) pode começar.
Se algum está ✗ → volte a Spec + Fix, teste VM novamente.
