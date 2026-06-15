# Kryonix Install Plan

O arquivo `install-plan.json` é a especificação declarativa de como o sistema deve ser instalado. Ele é o intermediário entre a UI e o executor real.

## Exemplo de Plano

```json
{
  "version": 1,
  "hostname": "kryonix",
  "timezone": "America/Cuiaba",
  "locale": "pt_BR.UTF-8",
  "keyboard": "br-abnt2",
  "disk": {
    "mode": "dry-run",
    "target": "/dev/vda",
    "layout": "btrfs-simple",
    "boot_mode": "uefi",
    "profile": "single",
    "selectedDisks": ["/dev/vda"]
  },
  "user": {
    "name": "admin",
    "admin": true
  },
  "features": {}
}
```

## Schema

O schema oficial vive no repo externo do installer:
`github:RAGton/kryonix-installer` → `schemas/install-plan.schema.json`.
Para inspeção local após `nix flake lock`, o tree do input está disponível em
`/nix/store/<hash>-source/schemas/install-plan.schema.json` (rev pinada em `flake.lock`).

### Campos Principais

*   **disk.mode**: `dry-run` para validação, `install`/`real` para execução efetiva.
*   **disk.boot_mode**: `uefi` (recomendado) ou `bios`.
*   **disk.layout**: `btrfs-simple` ou `lvm-simple`.
*   **disk.profile**: `single`, `raid` ou `manual`.
*   **features**: Módulos opt-in do Kryonix.

## Segurança operacional

`/dry-run` valida se o alvo é um block device real, não é o disco do sistema,
não possui partições montadas fora de `/iso` e tem pelo menos 10 GiB.

As rotas legadas `/disk/apply`, `/api/partition` e `/install/finalize` ficam
desativadas. A execução destrutiva passa por `/install`, que roda safety checks
antes de chamar o executor real.
