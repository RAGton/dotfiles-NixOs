---
source: docs/hosts/inspiron.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Host: Inspiron

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

Este documento consolida o estado do host Inspiron.

## Fonte de Verdade (Serviços e Cliente)
- **Status:** **PRODUCTION** (Desktop diário e desenvolvimento)
- **Serviço:** (Desktop Client - `Hyprland` e User Sessions dependentes)
- **Porta:** N/A
- **Comando:** `kryonix test client`
- **Validação:** Validação da ausência de pendências na CLI principal e integridade via flake check.

## Perfil

- **Tipo:** Workstation / Cliente Leve
- **Hardware Base:** Intel
- **Ambiente Desktop:** Hyprland + Caelestia (Shell Principal)
- **Papel na Rede:** Cliente de desenvolvimento, administração do NixOS e operação diária.

## Papel Arquitetural

O host `inspiron` atua como o cliente para consultas e operações na rede Kryonix. Ele não é encarregado de rodar instâncias locais massivas de Ollama ou hospedar dados brutos (GraphML). 

Ao invés disso, o `inspiron` usa a CLI via rede (LAN / Tailscale).

> [!WARNING]
> O uso da variável `KRYONIX_BRAIN_API` para acessar a porta `8000` do Glacier está listado no ROADMAP, pois o serviço de API contínuo encontra-se desativado no servidor. O cliente pode atualmente apenas operar comandos locais da CLI.

Este desacoplamento impede que o build e verificação local falhem por questões relacionadas ao servidor. Se a comunicação remota com o `glacier` falha ou está inativa, o cliente alerta com um `WARN`, mas valida o código do sistema localmente sem problemas.
