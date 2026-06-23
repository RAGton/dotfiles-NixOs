# =============================================================================
# Module: Kernel features (kryonix.features.kernel.*)
# Autor: Gabriel Rocha (ragton) + Aura
# Data: 2026-06-23
#
# O que é:
# - Features de kernel: Zen, Hardened, Low-Latency.
# - Cada feature é opt-in (default = false) e ativa boot.kernelPackages.
#
# Por quê:
# - Kernel afeta boot e estabilidade; nada deve ser ativado sem decisão explícita.
# - Compatibilidade com o módulo kernelZen existente (modules/kernel/zen.nix).
#
# Como:
# - A feature kryonix.features.kernel.zen.enable = true ativa linuxPackages_zen.
# - O módulo kernelZen (legado) continua funcionando em paralelo.
#
# Riscos:
# - Trocar kernelPackages pode quebrar drivers (NVIDIA, ZFS, VirtualBox).
# - Validar com nix flake check antes de aplicar em runtime.
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.features.kernel;
in
{
  options.kryonix.features.kernel = {
    zen = {
      enable = lib.mkEnableOption ''
        Linux Zen kernel (linuxPackages_zen). Otimizado para desktop e gaming,
        com foco em baixa latência e melhor throughput interativo.

        Compatível com o módulo kernelZen (modules/kernel/zen.nix) que oferece
        opções avançadas (XanMod, LLVM stdenv, mitigations, etc).
      '';
    };
  };

  config = lib.mkMerge [
    # Linux Zen kernel
    (lib.mkIf cfg.zen.enable {
      boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_zen;
    })
  ];
}
