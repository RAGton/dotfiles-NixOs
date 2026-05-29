# Especificações Técnicas: Kryonix Context-Aware Architecture

A implementação deve seguir um modelo híbrido para garantir o máximo desempenho no lado cliente (`inspiron`) sem sobrecarregar seu hardware.

┌─────────────────────────┐               ┌─────────────────────────┐
│   Workstation Client    │   Tailscale   │    AI Server (Heavy)    │
│       (Inspiron)        │ ────────────> │        (Glacier)        │
│  - watchdog/telemetry   │   (VPN/LAN)   │  - Ollama Engine (CUDA) │
│  - systemd user daemons │               │  - Graph/Brain API :8000│
└─────────────────────────┘               └─────────────────────────┘

## 🛠️ Fase 1: Smart Filer Core (Rust)
- **Binário Base:** Incrementado a partir do pacote `kryonix-home`.
- **Mecanismo:** Utiliza a crate `notify` ou execução via temporizador baseado em eventos `inotify` no Linux.
- **Resiliência de Rede:** Timeout global fixado em `3.0s` nas requisições HTTP para a API do Glacier. Em caso de quebra de conexão ou timeout, o arquivo permanece intacto na pasta de entrada e a operação tenta novamente no próximo ciclo.

## 🐍 Fase 2: RAM Optimizer Core (Python)
- **Pacote:** Alocado em `packages/kryonix-optimizer/`.
- **Mecanismo de Coleta:** Script Python assíncrono utilizando `psutil` para ler estatísticas globais da memória a cada 60 segundos.
- **Gatilho (Trigger):** Disparo condicional ativado somente quando `psutil.virtual_memory().percent >= 90.0`.
- **Validação de Testes:** Exige uma suíte de testes unitários com mocks em `packages/kryonix-optimizer/tests/test_optimizer.py` injetando cenários de falta de rede com o Glacier e validando que o script nunca emite chamadas para `kill -9`.
