# Hardware Features Audit

## Status

Data: 2026-06-24

Este documento resume o estado das features declarativas de hardware do Kryonix.

## Features implementadas

### CPU

| Feature | Status | Default | Observação |
|---|---|---|---|
| kryonix.features.cpu.intel.enable | implementada | false | microcode + diagnóstico |
| kryonix.features.cpu.intel.thermald.enable | implementada | false | opt-in |
| kryonix.features.cpu.amd.enable | implementada | false | microcode + diagnóstico |
| kryonix.features.cpu.amd.pstate.enable | implementada | false | opt-in |

### GPU

| Feature | Status | Default | Observação |
|---|---|---|---|
| kryonix.features.gpu.intel.enable | implementada | false | Intel iGPU, VA-API, Quick Sync |
| kryonix.features.gpu.nvidia.enable | implementada | false | NVIDIA driver |
| kryonix.features.gpu.cuda.enable | implementada | false | exige NVIDIA |
| kryonix.features.gpu.amd.enable | implementada | false | AMDGPU/Mesa/RADV |

## Hosts downstream

| Host | CPU | GPU | Estado |
|---|---|---|---|
| Glacier | AMD CPU | NVIDIA RTX 4060 + AMD iGPU | declarativo |
| Inspiron | Intel CPU | Intel iGPU | declarativo |
| Inspiron Nina | Intel CPU | Intel iGPU legacy VAAPI | declarativo |

## Glacier

Configuração esperada:

```nix
kryonix.features.cpu.amd.enable = true;

kryonix.features.gpu.nvidia = {
  enable = true;
  open = false;
  package = "stable";
  modesetting.enable = true;
};

kryonix.features.gpu.amd = {
  enable = true;
  opencl.enable = false;
  rocmSupport.enable = false;
  amdvlk.enable = false;
  legacySupport.enable = false;
};
```

Resultado esperado:

```json
["nvidia", "amdgpu", "nvidia"]
```

A duplicata `nvidia` vem de `nixos-hardware/common-gpu-nvidia`, não do Kryonix. É funcionalmente inócua.

## Próximos passos recomendados

1. Migrar o glacier-base restante (SSH, Tailscale, Fail2Ban, firewall) para features correspondentes.
2. Implementar feature `gpu.prime` para suporte a configurações PRIME/hybrid GPU.
3. Avaliar a implementação de `kernel-zen` (já declarada no schema).
4. Avaliar features de rede: `network.tailscale`, `network.bridge`, `remote.ssh`.
5. Avaliar feature de armazenamento: `storage.srvData`, `storage.aiModels`.
6. Avaliar feature de IA: `ai.brain.client` e `ai.brain.server` (se ainda não existentes).