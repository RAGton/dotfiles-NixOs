# CPU Feature — Kryonix

## O que faz

As features `kryonix.features.cpu.intel` e `kryonix.features.cpu.amd`
configuram microcode, diagnóstico e opções de tuning seguras para CPUs
Intel e AMD no Kryonix.

## Como habilitar

### Intel

```nix
kryonix.features.cpu.intel.enable = true;
```

### AMD

```nix
kryonix.features.cpu.amd.enable = true;
```

## Subopções

### Intel

| Opção | Default | Descrição |
|---|---|---|
| `enable` | `false` | Liga/desliga toda a feature Intel CPU |
| `microcode.enable` | `true` | Microcode updates Intel |
| `thermald.enable` | `false` | Thermal daemon (desligado por padrão) |
| `diagnostics.enable` | `true` | Ferramentas de diagnóstico CPU |

### AMD

| Opção | Default | Descrição |
|---|---|---|
| `enable` | `false` | Liga/desliga toda a feature AMD CPU |
| `microcode.enable` | `true` | Microcode updates AMD |
| `pstate.enable` | `false` | AMD P-State (desligado por padrão) |
| `pstate.mode` | `"active"` | Modo P-State: active, passive, guided |
| `diagnostics.enable` | `true` | Ferramentas de diagnóstico CPU |

## Por que microcode fica ligado por padrão

Microcode corrige bugs de hardware e vulnerabilidades de segurança
( Spectre, Meltdown, etc.) em CPUs Intel e AMD. É seguro e recomendado
manter ligado. A opção existe apenas para casos de debugging.

## Por que AMD P-State fica desligado por padrão

AMD P-State é um driver de scaling de frequência moderno, mas seu
comportamento depende da combinação específica de CPU, kernel e BIOS.
Em alguns sistemas pode causar instabilidade ou performance reduzida.
Ative apenas após testar no hardware alvo.

## Por que thermald fica desligado por padrão

Thermald (Intel Thermal Daemon) gerencia temperaturas da CPU, mas pode
conflitar com políticas de energia definidas pelo host, pelo perfil laptop
ou pelo kernel. Ative apenas em laptops Intel com problemas térmicos
conhecidos.

## Comandos de validação

```bash
# Informações da CPU
lscpu

# Verificar microcode carregado
dmesg | grep -i microcode

# Verificar frequência e scaling driver
cpupower frequency-info

# Verificar scaling driver atual
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver

# Validar flake (upstream)
cd /home/rocha/kryonix/kryonix-dev/repos/kryonix
nix flake check --keep-going

# Build do host afetado (downstream)
cd /home/rocha/kryonix/kryonix-dev/repos/kryonixos
nix build .#nixosConfigurations.inspiron.config.system.build.toplevel --no-link -L
nix build .#nixosConfigurations.glacier.config.system.build.toplevel --no-link -L
```

## Rollback

```nix
kryonix.features.cpu.intel.enable = false;
kryonix.features.cpu.amd.enable = false;
```

Rebuild e reboot se necessário.

## Links relacionados

- [[VAULT_INDEX]]
- [[02-Areas/Kryonix/canonical/UPSTREAM_DOWNSTREAM_FEATURE_ARCHITECTURE_PLAN]]