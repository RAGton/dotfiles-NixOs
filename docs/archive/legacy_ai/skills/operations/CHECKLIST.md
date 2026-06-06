# Checklist: Operations

- confirmar host alvo e origem da flake
- revisar se a mudança pede `test`, `boot` ou `switch`
- rodar validação mínima antes da aplicação
- registrar qual erro já existia antes da mudança
- tratar erro novo como regressão até prova em contrário
- em falha de aplicação, preservar contexto para rollback
- não misturar correção funcional com limpeza ampla de docs ou arquitetura
