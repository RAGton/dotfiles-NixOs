# AMD GPU Feature — Kryonix

## O que `kryonix.features.gpu.amd` faz

Configura o driver AMDGPU open-source (Mesa/RADV), suporte 32-bit,
ferramentas de diagnóstico e opções avançadas (OpenCL, ROCm, AMDVLK).

## Como habilitar

```nix
kryonix.features.gpu.amd.enable = true;
```

Isso ativa com defaults seguros:
- `services.xserver.videoDrivers = [ "amdgpu" ]`
- `hardware.graphics.enable = true` e `enable32Bit = true`
- Diagnóstico (`radeontop`, `clinfo`, `vulkan-tools`, `mesa-demos`)

## Como usar junto com NVIDIA no Glacier

O Glacier tem Ryzen 7 9700X (iGPU AMD Radeon) + RTX 4060.
Quando ambas as features estão habilitadas, cada uma tenta definir
`services.xserver.videoDrivers` com `mkDefault`. Para resolver o conflito,
o host deve definir explicitamente:

```nix
services.xserver.videoDrivers = [ "nvidia" "amdgpu" ];
```

## Subopções

| Opção | Default | Descrição |
|---|---|---|
| `enable` | `false` | Liga/desliga toda a feature AMD GPU |
| `enable32Bit` | `true` | Suporte 32-bit (Steam/Wine) |
| `videoDrivers` | `[ "amdgpu" ]` | Drivers Xorg/Wayland |
| `initrd.enable` | `false` | Carregar amdgpu no initrd |
| `opencl.enable` | `false` | AMD OpenCL (desligado) |
| `rocmSupport.enable` | `false` | ROCm global (pesado, desligado) |
| `legacySupport.enable` | `false` | Legacy SI/CIK (desligado) |
| `amdvlk.enable` | `false` | AMDVLK Vulkan (desligado) |
| `diagnostics.enable` | `true` | Ferramentas de diagnóstico |

## Por que `hardware.graphics` fica ligado

O stack gráfico Mesa/RADV fornece aceleração OpenGL e Vulkan para GPUs AMD.
Tanto `enable` quanto `enable32Bit` são necessários para compatibilidade com
Steam, Wine e a maioria dos aplicativos gráficos.

## Por que OpenCL fica desligado por padrão

OpenCL AMD (via `hardware.amdgpu.opencl.enable`) adiciona dependências do
runtime ROCm ao sistema. A maioria dos usuários não precisa de OpenCL em GPU
AMD — Vulkan compute cobre a maior parte dos casos. Ative apenas se tiver
aplicações que exijam OpenCL.

## Por que ROCm fica desligado por padrão

`nixpkgs.config.rocmSupport` global faz com que vários pacotes do nixpkgs
sejam rebuildados com suporte a ROCm. Isso é caro em tempo de build e
armazenamento. Prefira overrides por pacote quando possível.

## Por que AMDVLK fica desligado por padrão

AMDVLK é o driver Vulkan oficial da AMD, mas o driver RADV (Mesa) é o padrão
recomendado no Linux por ser mais estável, atualizado e com melhor desempenho
em jogos. AMDVLK é útil apenas para validação ou workloads específicos.

## Por que legacySupport fica desligado por padrão

`hardware.amdgpu.legacySupport` ativa suporte para GPUs AMD antigas
(Southern Islands / Sea Islands). GPUs modernas (GCN 4+ / RDNA) não precisam.

## Comandos de validação

```bash
# Verificar hardware AMD
lspci -k | grep -EA3 'VGA|Display|3D'

# Verificar módulo amdgpu carregado
lsmod | grep amdgpu

# Informações OpenGL
glxinfo -B

# Informações Vulkan
vulkaninfo --summary

# Informações OpenCL (se habilitado)
clinfo

# Monitor GPU
radeontop

# Ver videoDrivers ativo
nixos-option services.xserver.videoDrivers

# Validar flake
cd /home/rocha/kryonix/kryonix-dev/repos/kryonix
nix flake check --keep-going
```

## Rollback

```nix
kryonix.features.gpu.amd.enable = false;
```

Rebuild e reboot se necessário.

## Links relacionados

- [[VAULT_INDEX]]
- [[02-Areas/Kryonix/canonical/UPSTREAM_DOWNSTREAM_FEATURE_ARCHITECTURE_PLAN]]
- [[docs/hardware/GPU_INTEL]]
- [[docs/hardware/GPU_NVIDIA]]