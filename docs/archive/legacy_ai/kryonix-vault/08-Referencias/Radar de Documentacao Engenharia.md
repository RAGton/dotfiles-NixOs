# Radar de Documentação de Engenharia

## Objetivo

Lista curada de fontes para alimentar o Kryonix Vault sem copiar código ruim.

Use junto com [[08-Referencias/Politica de Curadoria de Fontes e Codigo]].

## NixOS / Nix / Flakes

### Fontes oficiais

- NixOS Manual
- nix.dev
- Nix Reference Manual
- Nixpkgs Manual
- NixOS Wiki oficial

### Critérios de uso

- Priorizar manual oficial para opções e comportamento.
- Usar exemplos de blog apenas se forem validados em VM/devShell.
- Tratar flakes como recurso experimental quando a documentação oficial assim declarar.
- Não copiar flakes gigantes sem entender inputs, outputs, overlays e modules.

## Proxmox VE

### Fontes oficiais

- Proxmox VE Documentation Index
- Proxmox VE Administration Guide
- Proxmox Backup Server docs
- Fórum oficial Proxmox para casos de hardware e storage

### Critérios de uso

- Fórum serve para troubleshooting, não arquitetura final.
- Validar storage, rede bridge, VLAN, backup e cluster contra docs oficiais.
- Nunca copiar comando destrutivo sem snapshot/backup.

## PXE / iPXE

### Fontes oficiais

- iPXE documentation
- iPXE scripting docs
- documentação DHCP/TFTP/HTTP usada no projeto

### Critérios de uso

- Validar BIOS vs UEFI separadamente.
- Documentar chainload.
- Não misturar TFTP e HTTP sem explicar o papel de cada um.
- Testar MAC routing e fallback.

## NFS

### Fontes oficiais

- Linux Kernel NFS docs
- man pages: `exports`, `nfs`, `mount.nfs`, `nfsd`

### Critérios de uso

- Revisar permissões e root squash.
- Validar firewall.
- Separar NFS para `/nix/store` read-only e `/home` persistente.
- Documentar locking, UID/GID e impacto de rede.

## Segurança backend/API

### Fontes oficiais

- OWASP API Security Top 10
- OWASP ASVS
- OWASP Cheat Sheet Series
- documentação oficial do framework

### Critérios de uso

- Nunca usar tutorial de auth como referência única.
- Testar object-level authorization.
- Evitar copiar middleware genérico sem entender threat model.

## Frontend moderno

### Fontes oficiais

- MDN Web Docs
- React docs
- Next.js docs quando usado
- web.dev
- WCAG/W3C

### Critérios de uso

- Priorizar semântica, acessibilidade e performance.
- Não copiar componente visual sem revisar responsividade.
- Validar estados: loading, empty, error, success.

## Engenharia de software

### Livros fortes

- The Pragmatic Programmer
- Refactoring — Martin Fowler
- Clean Architecture — Robert C. Martin
- Software Architecture: The Hard Parts
- Designing Data-Intensive Applications
- Site Reliability Engineering — Google
- Release It!
- Domain-Driven Design Distilled

### Critérios de uso

- Livros ensinam princípios, não receitas absolutas.
- Aplicar com senso de escala.
- Evitar overengineering por imitar livro fora de contexto.

## Fóruns e comunidades

### Usar para

- bugs reais;
- hardware específico;
- incompatibilidades;
- sintomas operacionais;
- mensagens de erro.

### Não usar para

- copiar arquitetura;
- copiar script de produção;
- decidir segurança;
- substituir documentação oficial.

## Checklist antes de virar nota permanente

- [ ] fonte classificada por tier
- [ ] link registrado
- [ ] data de consulta registrada
- [ ] aplicabilidade explicada
- [ ] riscos listados
- [ ] validação prática definida
- [ ] não contém código copiado sem auditoria
