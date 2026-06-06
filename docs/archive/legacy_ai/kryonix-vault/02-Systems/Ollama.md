---
source: docs/ARCHITECTURE.md, docs/hosts/glacier.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Ollama

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

O Ollama é o motor de inferência local utilizado pelo Kryonix para rodar LLMs de forma autônoma.

## Fonte de Verdade
- **Serviço Principal Ativo:** `ollama.service` (no Glacier)
- **Porta:** `11434`
- **Comando de Validação:** `systemctl status ollama.service --no-pager`
- **Validação de Porta:** `ss -ltnp | grep 11434`

## Perfil e Papel
- **Onde Roda:** Exclusivamente no host `glacier`.
- **Acesso:** Pode ser acessado via LAN/Tailscale por hosts clientes (`inspiron`).
- **Status:** **PRODUCTION** (Validado e operacional no Glacier)

## Integração
O Ollama serve como o backend para o **Kryonix Brain** e o **LightRAG**. A CLI `kryonix brain` interage com o Ollama para realizar buscas semânticas e responder perguntas.
