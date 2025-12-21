/*
 Autor: RAGton
 Descrição: Módulo NixOS para habilitar virtualização KVM/QEMU/libvirt com suporte a IOMMU, integração com virt-manager e práticas recomendadas. Comentários e opções em PT-BR.
*/

{ config, pkgs, lib, ... }:
{
  /*
    Este módulo ativa virtualização completa no NixOS:
    - KVM/QEMU/libvirt com suporte a IOMMU (Intel/AMD)
    - Integração com virt-manager (gerenciamento gráfico)
    - Práticas recomendadas para estabilidade e segurança
    - Comentários e opções em PT-BR
  */

  # Serviços de virtualização
  virtualisation = {
    libvirtd.enable = true; # Libvirt para gerenciamento de VMs
    kvmgt.enable = lib.mkDefault true; # KVM para Intel GVT-g (opcional)
    spiceUSBRedirection.enable = true; # Redirecionamento USB para VMs
    qemu = {
      package = pkgs.qemu_kvm; # QEMU otimizado para KVM
      runAsRoot = false;       # Segurança: não rodar QEMU como root
      swtpm.enable = true;     # TPM virtual para VMs modernas
    };
  };

  # Adiciona usuário root ao grupo libvirtd (ajuste para multiusuário conforme necessário)
  users.users.${config.users.users.root.name}.extraGroups = [ "libvirtd" ];

  # Suporte a IOMMU (Intel/AMD): necessário para PCI passthrough
  boot.kernelParams = lib.mkMerge [
    (lib.mkIf (config.hardware.cpu.intel.enable or false) [ "intel_iommu=on" ])
    (lib.mkIf (config.hardware.cpu.amd.enable or false) [ "amd_iommu=on" ])
  ];

  # Instala virt-manager para gerenciamento gráfico de VMs
  environment.systemPackages = with pkgs; [ virt-manager ];

  # Sugestão: permitir override de grupos ou usuários via option
  # (exemplo para ambientes multiusuário)
  # options.kvm.extraGroups = lib.mkOption {
  #   type = lib.types.listOf lib.types.str;
  #   default = [];
  #   description = "Grupos extras para acesso ao libvirt/KVM.";
  # };

  # Metadados e documentação
  meta = {
    description = "Módulo NixOS para virtualização KVM/QEMU/libvirt com IOMMU e integração gráfica. Comentários em PT-BR.";
    maintainers = [ "RAGton" ];
    homepage = "https://libvirt.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
