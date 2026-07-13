# Estrutura do RAGC (Fase 1)

Este diretório contém a implementação modular dos comandos da CLI `ragc`, agora operando em um modelo **geracional e imutável**.

## Comandos Implementados

- **`switch.sh`**: Build, publicação e promoção atômica.
- **`rollback.sh`**: Reversão instantânea via troca de ponteiros (`current`/`previous`).
- **`list.sh`**: Listagem de gerações com status e metadados.
- **`status.sh`**: Exibição detalhada da geração ativa e links operacionais.
- **`gc.sh`**: Coleta de lixo segura (protege gerações vivas e recentes).
- **`doctor.sh`**: Diagnóstico de infraestrutura e integridade geracional.
- **`router.sh`**: Despachante de comandos.
- **`help.sh`**: Documentação de uso.

O entrypoint público do pacote Nix está em [ragc/default.nix](../default.nix).
