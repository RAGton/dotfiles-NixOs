---
description: Monta o bloco de entrega VIBECODE (Plano/Diff/Teste/Risco/Rollback)
allowed-tools: Bash(git diff:*), Bash(git status:*), Read
---
Gere o bloco de entrega do trabalho atual com:
- **Plano**: o que foi feito e por quê.
- **Diff**: !`git diff --stat`
- **Teste**: comandos rodados e resultado (flake check + build dos hosts afetados).
- **Risco**: o que pode quebrar.
- **Rollback**: passos exatos para reverter.
Não declare "pronto" se algum teste falhou.
