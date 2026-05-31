---
paths:
  - "packages/kryonix-installer/**"
  - ".github/workflows/**installer**"
---
# Regras para Kryonix Installer
- Cargo.toml: versions travadas, apenas git deps se necessário (com rev/tag).
- Backend: todo endpoint retorna JSON, error handling explicit.
- Frontend: build static, zero hardcoded URLs (use /api/ relative).
- Kiosk: paths absolutos em ExecStart, env vars declarados em systemd.
- Testes: rodar antes de commit, coverage >70% se houver.
- Segredos: NUNCA em arquivo — env var em runtime só.
