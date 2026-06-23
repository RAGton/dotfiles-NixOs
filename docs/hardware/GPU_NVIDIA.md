# NVIDIA GPU and CUDA Feature — Kryonix

## O que `gpu.nvidia` faz

A feature `kryonix.features.gpu.nvidia` configura o driver NVIDIA proprietário,
modesetting, nvidia-settings e ferramentas de diagnóstico. Suporta GPUs NVIDIA
desde a série GTX 900 até RTX 4000 (incluindo RTX 4060 do Glacier).

## O que `gpu.cuda` faz

A feature `kryonix.features.gpu.cuda` ativa suporte a CUDA compute, incluindo
toolkit, cache binário NixOS CUDA e `cudaSupport` global. **Requer NVIDIA
habilitado** (`kryonix.features.gpu.nvidia.enable = true`).

## Diferença entre NVIDIA driver e CUDA

| Aspecto | NVIDIA Driver | CUDA |
|---|---|---|
| Função | Driver gráfico (display, OpenGL, Vulkan) | Compute (ML, GPGPU, AI) |
| Necessário para | Desktop, gaming, X11/Wayland | Ollama, PyTorch, TensorFlow |
| Tamanho | Médio | Pesado (toolkit é grande) |
| `cudaSupport` global | Não | Opcional e desligado por padrão |

## Como habilitar NVIDIA

```nix
kryonix.features.gpu.nvidia.enable = true;
```

Isso ativa:
- `services.xserver.videoDrivers = [ "nvidia" ]`
- `hardware.nvidia.open = true` (open kernel module para RTX 20+)
- `hardware.nvidia.modesetting.enable = true`
- `nvidia-settings`
- `nvtop` (versão NVIDIA), `vulkan-tools`, `mesa-demos`, `pciutils`
- `services.xserver.enable = true`

## Como habilitar CUDA

```nix
kryonix.features.gpu.nvidia.enable = true;
kryonix.features.gpu.cuda.enable = true;
```

Para instalar o CUDA toolkit adicionalmente:

```nix
kryonix.features.gpu.cuda.toolkit.enable = true;
```

## Subopções NVIDIA

| Opção | Default | Descrição |
|---|---|---|
| `enable` | `false` | Liga/desliga driver NVIDIA |
| `open` | `true` | Usar kernel module open (RTX 20+) |
| `modesetting.enable` | `true` | Kernel modesetting (Wayland) |
| `powerManagement.enable` | `false` | Power management (desligado) |
| `powerManagement.finegrained` | `false` | Fine-grained PM (laptop) |
| `nvidiaSettings.enable` | `true` | nvidia-settings GUI |
| `persistenced.enable` | `false` | nvidia-persistenced (compute) |
| `package` | `"default"` | Branch: default, stable, production, beta |
| `diagnostics.enable` | `true` | Ferramentas de diagnóstico |

## Subopções CUDA

| Opção | Default | Descrição |
|---|---|---|
| `enable` | `false` | Liga/desliga CUDA |
| `toolkit.enable` | `false` | Instala CUDA toolkit (pesado) |
| `cudaSupport.enable` | `false` | `nixpkgs.config.cudaSupport` global |
| `binaryCache.enable` | `true` | Cache NixOS CUDA (evita builds locais) |
| `diagnostics.enable` | `true` | Ferramentas de validação |

## Por que CUDA toolkit fica desligado por padrão

O CUDA toolkit (nvcc, cudart, etc.) adiciona **centenas de megabytes** ao
closure do sistema. A maioria dos hosts não precisa compilar código CUDA
diretamente. A recomendação é ativar apenas em máquinas de desenvolvimento
ou servidores AI que compilam kernels CUDA.

## Por que `cudaSupport` global fica desligado por padrão

Ativar `nixpkgs.config.cudaSupport` globalmente faz com que **todos os
pacotes do nixpkgs que suportam CUDA sejam rebuildados com CUDA**. Isso
inclui OpenCV, PyTorch, TensorFlow, LLVM, etc. O rebuild é caro em tempo
e armazenamento.

A abordagem recomendada do Kryonix é usar **per-package CUDA overrides**
(como `pkgs.llama-cpp.override { cudaSupport = true; }`) em vez do global.
O `glacier-ai` profile e `server-ai` profile já fazem isso.

## Por que PRIME/hybrid fica fora deste PR

PRIME (NVIDIA + Intel/AMD iGPU) é um caso específico que exije configuração
adicional de `hardware.nvidia.prime.*`. Será implementado em PR futuro,
quando houver hardware para testar.

## Observações para Wayland/KDE/Hyprland

- NVIDIA com `modesetting.enable = true` funciona com KDE Plasma 6 Wayland.
- `open = true` requer RTX 20/GTX 16 ou mais novo. Para GPUs mais antigas,
  usar `open = false`.
- Se usar Hyprland, pode ser necessário configurar `env = WLR_NO_HARDWARE_CURSORS`.
- Para KDE, o driver NVIDIA proprietário com modesetting é o caminho recomendado.

## Observações para RTX 4060 / Glacier

O Glacier (RTX 4060) usa:
- `hardware.nvidia.open = false` (RTX 4060 é Turing/Ampere — open modules
  são suportados, mas o profile glacier-base atualmente usa `false`)
- `package = "stable"` (nvidiaPackages.stable)

A feature `kryonix.features.gpu.nvidia` com defaults atende o Glacier com
pequenos ajustes (`open = false`, `package = "stable"`).

## Comandos de validação

```bash
# Verificar driver NVIDIA
nvidia-smi

# Verificar versão CUDA
nvidia-smi | grep CUDA

# Verificar módulos carregados
lsmod | grep nvidia

# Informações OpenGL
glxinfo -B

# Informações Vulkan
vulkaninfo --summary

# Monitor GPU
nvtop

# Validar flake (upstream)
cd /home/rocha/kryonix/kryonix-dev/repos/kryonix
nix flake check --keep-going

# Build do Glacier
cd /home/rocha/kryonix/kryonix-dev/repos/kryonixos
nix build .#nixosConfigurations.glacier.config.system.build.toplevel --show-trace
```

## Rollback

```nix
kryonix.features.gpu.nvidia.enable = false;
kryonix.features.gpu.cuda.enable = false;
```

Rebuild e reboot podem ser necessários para voltar ao driver de vídeo anterior.

## Links relacionados

- [[VAULT_INDEX]]
- [[02-Areas/Kryonix/canonical/UPSTREAM_DOWNSTREAM_FEATURE_ARCHITECTURE_PLAN]]
- [[docs/hardware/GPU_INTEL]]