# Firewall Feature Overlap Audit

## Summary
Esta auditoria avalia a potencial sobreposição entre as features `security.firewall` e `network.firewall.strict` no ecossistema Kryonix. O objetivo é garantir consistência na arquitetura declarativa do NixOS e mitigar riscos de bloqueio acidental (SSH, Tailscale, virtualização).

## Options found
- `kryonix.features.security.firewall.enable`
- `kryonix.features.network.firewall.strict.enable`

## Declarations
1. **`network.firewall.strict`**:
   - **Status**: Stub.
   - Declarada em `modules/nixos/features/schema.nix` (`network.firewall.strict`).
   - Registrada em `modules/nixos/features/registry.nix` com `id = "network.firewall.strict"`.
   - **Não possui implementação de runtime ativa** (nenhum `network.nix` a implementa atualmente).

2. **`security.firewall`**:
   - **Status**: Implementada.
   - Declarada no `schema.nix` implicitamente através de legados (atualmente ativada via `modules/nixos/features/security.nix`).
   - Registrada em `modules/nixos/features/registry.nix` com `id = "security.firewall"`.

## Runtime effects
- `security.firewall` impõe as seguintes regras (`modules/nixos/features/security.nix`):
  ```nix
  networking.firewall = {
    enable = true;
    allowPing = false;
  };
  ```
- No NixOS padrão, `networking.firewall.enable` já é `true`. O real efeito dessa feature é desabilitar pacotes ICMP (Ping) para hardening ("Stealth mode").
- `network.firewall.strict` não gera efeitos atuais, pois carece de `config = lib.mkIf cfg.network.firewall.strict.enable { ... }`.

## Overlap analysis
Existe um claro conflito semântico (nome e escopo) entre as duas opções, mas não um conflito técnico de runtime no momento, pois uma delas é um stub. O usuário fica com duas opções no *Feature Registry* que parecem fazer a mesma coisa: aplicar um firewall estrito.

## Risk analysis
Implementar um firewall "estrito" sem os devidos *compat layers* gera alto risco para:
- **SSH Remoto / Tailscale**: Um bloqueio de UDP 41641 (Tailscale) ou bloqueio acidental da porta TCP do SSH resultará em interrupção de gerência remota permanente.
- **Bridge br0 / VLAN / libvirt**: Ferramentas de virtualização (Proxmox-like, libvirt, docker) dependem da liberação de roteamento de pacotes nas interfaces virtuais (ex: `trustedInterfaces = [ "virbr0" ]`). Um firewall estrito padrão ("default deny") quebrará roteamentos complexos.
- **Installer / ISO**: ISOs requerem portas temporárias (ex: API Axum 8080) e descoberta de rede que podem ser prejudicadas.

## Recommended architecture
**Opção A — `network.firewall.strict` como canônico** é a arquitetura mais coerente com a taxonomia do Kryonix:
1. O subsistema `network` deve ser o dono absoluto da manipulação de portas (`allowedTCPPorts`, `allowedUDPPorts`, `trustedInterfaces`).
2. O subsistema `security` (`security.nix`) deve ser reservado para políticas globais de hardening do kernel, fail2ban, apparmor e selinux, e não manipular roteamento de pacotes diretamente.

## Proposed migration plan
1. Criar o módulo canônico `modules/nixos/features/network.nix` se ele ainda não existir.
2. Migrar a lógica de `allowPing = false` e "Stealth mode" para `network.firewall.strict`.
3. Adicionar lógica de fallback seguro no novo módulo `network.firewall.strict`:
   ```nix
   networking.firewall.trustedInterfaces = lib.mkIf config.services.tailscale.enable [ "tailscale0" ];
   ```
4. Depreciar e remover `security.firewall` do `schema.nix` e do `registry.nix`.

## What not to change yet
- Não fazer alterações no runtime (`security.nix` ou `network.nix`) nesta etapa.
- Não remover registros de options.
- Qualquer alteração que aplique políticas restritivas de verdade deve passar por extensa validação no VM Tester (`nixos-rebuild test`) antes de ser mergeada.
