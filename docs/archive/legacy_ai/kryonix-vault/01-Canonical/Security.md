---
source: docs/SECURITY.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Segurança e Hardening do Kryonix

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

Este documento descreve as políticas e definições de segurança para os hosts gerenciados pelo Kryonix.

## Secrets e Credenciais

Os secrets (Tailscale auth key, variáveis de ambiente, etc) **nunca** devem ser "commitados" no repositório.

- O `.mcp.json` real fica em `.gitignore`. O repositório versiona apenas o `.mcp.example.json`.
- Nenhum acesso de escrita fora do diretório do vault é permitido para o MCP.
- O NixOS *store* é de leitura pública. Nenhuma credencial sensível deve ser colocada inline dentro das derivações do Nix ou variáveis systemd exportadas em logs de forma pública. Use arquivos no runtime (`/run/secrets`).

## Rede e Firewall

- Exposição pública deve ser evitada. Utilize acessos em LAN ou Tailscale preferencialmente.
- **Glacier SSH**: Porta customizada `2224`.
- **Kryonix Brain API**: Porta `8000`.
- **Ollama API**: Porta `11434`.

A regra geral do firewall é restringir todas as outras portas de conexões externas não documentadas explicitamente e aprovadas.

## Relatório de Vulnerabilidades

Não abra issues públicas para problemas de segurança, senhas expostas, credenciais vazadas ou configurações sensíveis. Envie e-mail privadamente para `gabriel.rag@proton.me` incluindo a descrição do problema, arquivo afetado, e avaliação de impacto.

O repositório cobra responsabilidade apenas pelas configurações e infraestrutura provisionada pelo Kryonix; vulnerabilidades upstream no Nixpkgs e serviços terceiros são reportadas às respectivas instâncias oficiais.
