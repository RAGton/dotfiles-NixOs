---
name: installer-backend-test
description: Testa e itera o backend Axum — cargo build, run, health check, logs. Use após diagnosticar problema no backend.
allowed-tools: Bash, Read, Edit, Grep
disable-model-invocation: true
argument-hint: "[ação: build|run|test|logs]"
---

# Test Backend Axum

Leia specs/01-fix-backend.md primeiro. Após cada fix de código, rode os testes abaixo.
