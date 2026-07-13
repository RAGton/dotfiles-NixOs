# Roadmap RAGOS

Status: archived  
Scope: Roadmap historico de maturidade do projeto

O roadmap do RAGOS é dividido em marcos de maturidade operacional. A numeração de fases no roadmap não corresponde necessariamente às fases de refatoração do repositório, mas ao amadurecimento do produto.

## Fase 1 — MVP (Concluída)

**Objetivo:** Boot diskless funcional em ambiente de laboratório.

- [x] PXE + TFTP + iPXE chainload.
- [x] HTTP servindo kernel/initrd/boot.ipxe.
- [x] NFS `/nix/store` (ro) + overlay tmpfs.
- [x] NFS `/home` (rw, persistente).
- [x] KDE Plasma 6 Wayland-only.
- [x] Flake com parâmetros centralizados.
- [x] Firewall habilitado com portas mínimas.
- [x] Documentação base em `docs/`.

---

## Fase 2 — Estabilidade e Ciclo de Vida (Concluída)

**Objetivo:** Operação confiável e gestão de imagens.

- [x] **Modelo Geracional**: Publicação imutável com `current`/`previous` via `ragc`.
- [x] **Rollback Atômico**: Reversão de imagem em segundos sem rebuild.
- [x] **Storage Estruturado**: BTRFS com subvolumes (@homes, @images, @snapshots).
- [x] **Separação de Discos**: Sistema em NVMe/SSD, dados em disco dedicado.
- [x] **CLI de Operação**: `ragos` para servidor e `ragc` para clientes.
- [x] **Observabilidade Base**: Prometheus + Node Exporter + Grafana.

---

## Fase 3 — Segurança e Rede

**Objetivo:** Blindagem da rede de boot.

- [ ] **MAC Allowlist**: Controle de boot apenas para dispositivos autorizados.
- [ ] **VLAN Isolation**: Separação física/lógica da rede de boot.
- [ ] **Hardening de NFS**: Otimização de parâmetros de montagem para escala.
- [ ] **Testes QEMU**: Validação automatizada de regressão de boot.

---

## Fase 4 — Escala e Performance

**Objetivo:** Suporte a dezenas de clientes simultâneos.

- [ ] **HTTPBoot Nativo**: UEFI direto para HTTP (sem TFTP).
- [ ] **Cache Nix Local**: Uso de `attic` ou `nix-serve` para acelerar builds.
- [ ] **Build Farm**: Offload de compilação para máquinas potentes.
- [ ] **Rede 10Gb**: Otimização de stack TCP/NFS para alta vazão.

---

## Fase 5 — Produto e UX

**Objetivo:** RAGOS como plataforma instalável e gerenciável.

- [x] **ISO RAGOS**: Imagem de instalação do servidor (concluída a estrutura base).
- [x] **RAGOS Installer**: UI React + Rust para instalação assistida.
- [ ] **Painel Web**: Interface administrativa para gestão de clientes e usuários.
- [ ] **Módulo NixOS**: Empacotamento do RAGOS como módulo reutilizável.
