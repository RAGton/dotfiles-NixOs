---
source: docs/hosts/glacier.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Host: Glacier

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

Este documento detalha o papel e infraestrutura canônica do servidor `glacier`.

## Fonte de Verdade (Serviços Autônomos Ativos)
- **Status:** **PRODUCTION** (Servidor central e IA)
- **Serviço:** `ollama.service`
- **Porta:** `11434`
- **Comando:** `systemctl status ollama.service --no-pager`
- **Validação:** `ss -ltnp | grep 11434`

> [!WARNING]
> Quaisquer outros serviços prometidos de IA ou Graph (API na porta 8000, MCP Server contínuo) não estão validados em runtime e foram movidos para o ROADMAP.

## Perfil Base

- **Tipo:** Servidor IA / Workstation / Datacenter Pessoal
- **Hardware:** AMD CPU + NVIDIA RTX 4060
- **Ambiente Desktop (se habilitado):** Hyprland + Caelestia
- **Sistema Base:** NixOS declarativo

## Papel no Ecossistema

O Glacier é o servidor principal do projeto Kryonix. O repositório o consolida como a fonte de processamento pesado, Virtualização e eventual base de Gaming de performance.

### 1. Centro de Inteligência Artificial (Kryonix Brain)
- **Ollama**: Roda nativamente para expor modelos locais na porta `11434`.
- **LightRAG e Grafo**: Operacional via chamadas diretas pela CLI `kryonix` (não autônomo).
- **Vault Index**: Processa o Vault Obsidian para pesquisa semântica através de comandos invocados manualmente.

### 2. Infraestrutura e Redes
- Possui o repositório instalado em `/etc/kryonix`.
- Mantém IP fixo interno alvo (`10.0.0.2`).
- Expõe porta segura `2224` para acessos SSH (LAN ou Tailscale).

### 3. Workstation e Virtualização
- Armazena imagens base e templates de hipervisores KVM no diretório central: `/srv/ragenterprise`.
- Pode assumir um perfil gamer completo opt-in sem afetar os serviços de servidor.

## Validação e Gerenciamento
Para testar a vitalidade de runtime autônomo no `glacier`, execute:
```sh
kryonix test server
systemctl status ollama.service --no-pager
```
