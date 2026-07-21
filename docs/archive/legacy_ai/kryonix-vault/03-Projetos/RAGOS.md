# NODE

## Repositório

- GitHub: `RAGEnterprise/node`
- Visibilidade: privado
- Branch padrão: `main`
- Relação: projeto principal do ecossistema NODE

## Descrição operacional

NODE é uma plataforma on-premises para clientes diskless reais em NixOS, com boot via rede, imagem centralizada e operação orientada a previsibilidade.

A visão central do projeto é: **o servidor é o centro do sistema, não o endpoint**.

## Estado atual declarado no README

O repositório declara entregar:

- boot UEFI com PXE + iPXE + HTTP;
- publicação geracional do cliente por `knyc`;
- canais oficiais `generic`, `lab` e `rescue`;
- perfis `desktop-generic`, `desktop-lab`, `rescue-minimal` e `hyperv-debug`;
- inventário externo em `/etc/node-inventory/clients.nix`;
- servidor NixOS declarativo em `server/`;
- instalador do host em `installer/`.

## Contrato técnico atual

Contrato atual declarado:

```txt
/nix/store remoto via NFS read-only
+ overlay tmpfs read-write
+ /home persistente via NFSv4
```

SquashFS/netboot continua no roadmap, mas não deve ser tratado como contrato atual de produção.

## Decisões não negociáveis

- cliente diskless de verdade;
- persistência relevante no servidor;
- split-storage obrigatório;
- BTRFS no tier de dados;
- hostname único por cliente;
- inventário como base operacional;
- Wake-on-LAN pertence ao servidor, mas só deve ser documentado como implementado quando existir no código.

## Componentes

| Componente | Papel |
|---|---|
| `server/` | composição NixOS do servidor NODE |
| `client/` | imagem do cliente diskless |
| `installer/` | instalação do host e bootstrap inicial |
| `knyc/` | build, publish, rollback e GC da imagem do cliente |
| `docs/` | documentação canônica |
| `scripts/` | laboratório, testes e migrações auxiliares |

## Fontes de verdade por domínio

- `flake.nix` e `flake/`: composição, validação e parâmetros globais.
- `server/`: servidor.
- `client/`: imagem do cliente.
- `installer/`: instalação do servidor.
- `knyc/`: publicação da imagem.
- `docs/`: documentação técnica e operacional.

## Regras para IA/agente

Antes de alterar NODE:

1. Ler `README.md`, `INSTRUCT.md`, `INSTRUCOES.md`.
2. Ler documentação do domínio em `docs/`.
3. Verificar se a mudança é servidor, cliente, installer ou knyc.
4. Não misturar mudança de contrato com refatoração.
5. Para boot/storage/rede, exigir plano de rollback.
6. Para NFS/PXE/iPXE, validar fluxo completo.
7. Para NixOS/flake, evitar lock churn sem justificativa.
8. Documentar estado atual vs roadmap.

## Riscos principais

- documentação vendendo roadmap como implementado;
- mudanças em boot quebrando clientes;
- NFS permissivo demais;
- overlay tmpfs consumindo RAM;
- BTRFS/subvolumes mal preparados;
- inventário inconsistente;
- scripts operacionais sem dry-run;
- falta de teste de rollback.

## MOCs relacionados

- [[01-MOCs/Mapa - Proxmox PXE NFS Homelab]]
- [[01-MOCs/Mapa - NixOS e Infra Declarativa]]
- [[01-MOCs/Mapa - Linux e Sistemas]]
- [[01-MOCs/Mapa - Debug Testes e Qualidade]]
- [[03-Projetos/NODE Installer]]
