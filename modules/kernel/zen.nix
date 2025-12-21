/*
 Autor: RAGton
 Descrição: Módulo NixOS para habilitar e otimizar o kernel Linux Zen para desktops modernos (x86_64), priorizando desempenho, estabilidade e clareza. Comentários e opções em PT-BR.
*/

{ config, pkgs, lib, ... }:
{
  /*
    Este módulo ativa o kernel Zen e aplica parâmetros recomendados para desktops modernos.
    - Kernel Zen: otimizado para baixa latência e responsividade.
    - Parâmetros: desativa mitigations e watchdog, priorizando desempenho (avaliar riscos de segurança).
    - Modular: pode ser importado em qualquer host NixOS.
  */

  # Kernel Zen como padrão
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Parâmetros de kernel para desktops x86_64
  boot.kernelParams = [
    "mitigations=off" # Desativa mitigations de segurança para máxima performance (riscos: CVEs de Spectre/Meltdown)
    "nowatchdog"      # Desativa watchdog do kernel
    "noibrs" "noibpb" # Desativa proteções extras de branch prediction
    "quiet"           # Menos ruído no boot
  ];

  # Assertiva para garantir uso do kernel correto
  assertions = [
    {
      assertion = config.boot.kernelPackages == pkgs.linuxPackages_zen;
      message = "O kernel Zen deve estar habilitado como padrão. Verifique imports e conflitos.";
    }
  ];

  # Sugestão de extensão: permitir override de parâmetros via option
  # (exemplo para usuários avançados)
  # options.kernelZen.extraKernelParams = lib.mkOption {
  #   type = lib.types.listOf lib.types.str;
  #   default = [];
  #   description = "Parâmetros extras para o kernel Zen.";
  # };

  # Metadados e documentação
  meta = {
    description = "Módulo NixOS para kernel Zen otimizado para desktop x86_64. Comentários em PT-BR.";
    maintainers = [ "RAGton" ];
    homepage = "https://liquorix.net/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
