# Intel GPU Feature — Kryonix

## O que faz

A feature `kryonix.features.gpu.intel` configura drivers de vídeo, aceleração
VA-API, Quick Sync, ferramentas de diagnóstico e variáveis de ambiente para
GPUs Intel integradas ou discretas no Kryonix.

## Como habilitar

```nix
kryonix.features.gpu.intel.enable = true;
```

Isso ativa os defaults seguros:

- `services.xserver.videoDrivers = [ "modesetting" ]`
- `hardware.graphics.enable = true` e `enable32Bit = true`
- Drivers VA-API modernos (`intel-media-driver`, `libvdpau-va-gl`)
- Quick Sync / oneVPL (`vpl-gpu-rt`)
- Diagnóstico (`libva-utils`, `intel-gpu-tools`, `vulkan-tools`, `mesa-demos`)
- `LIBVA_DRIVER_NAME = "iHD"` (driver moderno)

## Subopções

| Opção | Default | Descrição |
|---|---|---|
| `enable` | `false` | Liga/desliga toda a feature Intel GPU |
| `enable32Bit` | `true` | Suporte 32-bit (Steam/Wine) |
| `vaapi.enable` | `true` | Drivers VA-API modernos |
| `quickSync.enable` | `true` | Intel Quick Sync / oneVPL |
| `compute.enable` | `false` | Intel compute/OpenCL (pesado) |
| `diagnostics.enable` | `true` | Ferramentas de diagnóstico |
| `forceIHD` | `true` | Força `LIBVA_DRIVER_NAME = "iHD"` |
| `legacyVaapi.enable` | `false` | Driver VA-API legado (só se necessário) |
| `videoDrivers` | `[ "modesetting" ]` | Drivers Xorg/Wayland |

## Quando usar `legacyVaapi.enable`

Apenas em GPUs Intel muito antigas (Sandy Bridge, Ivy Bridge, Haswell
anteriores ao Broadwell) que não são suportadas pelo driver `intel-media-driver`
moderno (`iHD`).

```nix
kryonix.features.gpu.intel = {
  enable = true;
  legacyVaapi.enable = true;
};
```

## Quando usar `compute.enable`

Apenas se precisar de OpenCL/Compute em GPU Intel para cargas de trabalho
específicas (machine learning, processamento de imagem, etc.).

```nix
kryonix.features.gpu.intel = {
  enable = true;
  compute.enable = true;
};
```

Isso adiciona `intel-compute-runtime` ao build, que puxa dependências pesadas.

## Comandos de validação

```bash
# Verificar aceleração VA-API
vainfo

# Monitorar uso da GPU em tempo real
sudo intel_gpu_top

# Ver informações do OpenGL
glxinfo -B

# Ver informações do Vulkan
vulkaninfo --summary

# Validar flake (upstream)
cd /home/rocha/kryonix/kryonix-dev/repos/kryonix
nix flake check --keep-going

# Build do host afetado (downstream)
cd /home/rocha/kryonix/kryonix-dev/repos/kryonixos
nix build .#nixosConfigurations.inspiron.config.system.build.toplevel --no-link -L
```

## Rollback

1. Desabilitar a feature:
   ```nix
   kryonix.features.gpu.intel.enable = false;
   ```
2. Rebuild:
   ```bash
   kryonix switch <host>
   ```
3. Reverter o commit se necessário:
   ```bash
   git revert HEAD
   ```

## Links relacionados

- [[VAULT_INDEX]]
- [[02-Areas/Kryonix/canonical/UPSTREAM_DOWNSTREAM_FEATURE_ARCHITECTURE_PLAN]]
- [[02-Areas/Kryonix/canonical/FEATURE_REGISTRY]]
