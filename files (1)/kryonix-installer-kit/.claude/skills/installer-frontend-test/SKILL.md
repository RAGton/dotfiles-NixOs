---
name: installer-frontend-test
description: Testa e itera o frontend Vite — npm run build, valida dist/, checa imports. Use após diagnosticar problema no frontend.
allowed-tools: Bash, Read, Edit, Grep
disable-model-invocation: true
argument-hint: "[ação: build|check|serve]"
---

# Test Frontend Vite

Leia specs/02-fix-frontend.md primeiro. Após cada fix, rode build e valida dist/.
