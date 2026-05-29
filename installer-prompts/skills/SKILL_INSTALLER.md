# Skill: Kryonix / RagOS Installer

## Contexto do projeto

- **Repo principal:** https://github.com/RAGEnterprise/ragos-installer
- **Flake kryonix:** `/etc/kryonix` → host `iso` em `hosts/iso/`
- **Módulo NixOS:** `modules/nixos/installer/`
- **Web-kiosk:** `modules/nixos/installer/web-kiosk.nix`
- **Fase atual:** Fase 1 concluída (probe + planner + backend stub). Fase 2 em andamento.

## Arquitetura do instalador

```
ISO Boot
  └── Cage (compositor Wayland minimal)
        └── Chromium --kiosk http://localhost:PORT
                          └── Frontend Web (React/Svelte)
                                    └── Backend Axum (Rust)
                                          ├── GET  /probe      → HardwareReport JSON
                                          ├── POST /plan       → InstallPlan JSON
                                          ├── POST /dry-run    → validação
                                          └── POST /install    → execução real (Fase 2)
```

## Stack técnica

| Componente | Tecnologia | Status |
|------------|-----------|--------|
| Hardware Probe | Rust | ✅ Fase 1 |
| Disk Planner | Rust | ✅ Fase 1 |
| Backend REST | Rust + Axum | ✅ stub |
| Frontend Web | HTML/JS ou Svelte | 🔨 Fase 2 |
| Compositor Kiosk | Cage + Wayland | 🔨 corrigindo |
| Executor (partições) | Rust + disko | ❌ Fase 2 |

## Estrutura do install-plan.json

```json
{
  "version": 1,
  "profile": "desktop",
  "hostname": "kryonix",
  "timezone": "America/Cuiaba",
  "locale": "pt_BR.UTF-8",
  "keyboard": "br-abnt2",
  "boot": { "mode": "uefi" },
  "disk": {
    "mode": "dry-run",
    "target": "/dev/nvme0n1",
    "layout": "btrfs-simple"
  },
  "user": { "name": "rocha", "admin": true },
  "features": {
    "desktop": "hyprland-caelestia",
    "nvidia": "auto",
    "zram": true,
    "brain_client": true
  }
}
```

## Problema do Cage/Kiosk (contexto)

O serviço `cage` conflitava com o getty autologin no TTY1. O TTY1 já estava ocupado
pelo prompt de login do NixOS, então o Cage não conseguia tomar posse do terminal.

**Fix canônico:** usar `services.getty.autologinUser` com shell substituído pelo
Cage, em vez de um serviço systemd separado brigando pelo TTY.

```nix
# web-kiosk.nix
services.getty.autologinUser = "installer";
users.users.installer = {
  isNormalUser = true;
  extraGroups = [ "video" "input" "drm" ];
  shell = pkgs.writeShellScript "start-kiosk" ''
    cage -- chromium --kiosk http://localhost:${toString cfg.port}
  '';
};
```

## HardwareReport — campos esperados

```json
{
  "cpu": { "model": "...", "cores": 8, "threads": 16 },
  "memory_gb": 16,
  "disks": [
    { "path": "/dev/nvme0n1", "size_gb": 512, "type": "nvme" }
  ],
  "gpu": [
    { "vendor": "nvidia", "model": "RTX 4060", "vram_gb": 8 }
  ],
  "boot_mode": "uefi",
  "network": [
    { "interface": "wlan0", "kind": "wifi" }
  ]
}
```

## Regras absolutas

1. **NUNCA** executar `disko`, `mkfs`, `parted`, `wipefs` sem `--dry-run` ou `mode: dry-run`
2. **NUNCA** rodar o executor em VM de desenvolvimento — somente em hardware de teste
3. Backend Axum NÃO deve escutar em 0.0.0.0 — somente 127.0.0.1
4. Chromium kiosk NÃO deve ter acesso à internet — somente localhost
5. Build da ISO: `nix build .#nixosConfigurations.iso.config.system.build.isoImage`
6. Testar em VM antes de hardware real
7. `cargo test` deve passar antes de qualquer commit no backend Rust
