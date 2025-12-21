/*
 Autor: RAGton
 Descrição: Guia didático e prático sobre kernel Zen, otimizações de CPU e virtualização KVM/QEMU/libvirt no NixOS. Explicações, exemplos e recomendações em PT-BR.
*/

# Guia Didático: Kernel Zen e Virtualização no NixOS

## 1. Kernel Zen

O kernel Zen é uma versão alternativa do kernel Linux, mantida pela comunidade, com foco em desempenho, baixa latência e responsividade para desktops modernos (x86_64). Ele inclui patches e configurações que melhoram a experiência gráfica e a performance em multitarefa.

### Como usar no NixOS

Basta importar o módulo `modules/kernel/zen.nix` no seu arquivo de configuração do host (ex: `hosts/seu-host/default.nix`):

```nix
imports = [
  ./modules/kernel/zen.nix
];
```

### Otimizações aplicadas

- Kernel Zen como padrão do sistema
- Parâmetros para CPUs x86_64 modernas
- Desativação de mitigations para maior desempenho (avaliar riscos de segurança)
- Comentários e opções em português

## 2. Otimização de CPU

O módulo do kernel já inclui parâmetros para tirar proveito de CPUs modernas, desativando proteções que impactam o desempenho. Use apenas se compreender os riscos de segurança (Spectre/Meltdown).

## 3. Virtualização KVM/QEMU/libvirt

O KVM permite virtualização nativa no Linux, com excelente desempenho e suporte a aceleração por hardware. O módulo criado habilita todos os serviços necessários, incluindo suporte a IOMMU (para passthrough de dispositivos PCI, como placas de vídeo) e integração com o virt-manager para gerenciamento gráfico.

### Como usar no NixOS

Importe o módulo `modules/virtualization/kvm.nix` no seu arquivo do host:

```nix
imports = [
  ./modules/virtualization/kvm.nix
];
```

### Recursos habilitados

- KVM/QEMU/libvirt prontos para uso
- Suporte a IOMMU (Intel e AMD) para PCI passthrough
- virt-manager instalado para gerenciamento gráfico
- Redirecionamento USB e TPM virtual para VMs

## 4. Exemplos de uso

### Exemplo de configuração em `hosts/<seu-host>/default.nix`

```nix
{ ... }:
{
  imports = [
    ../../modules/kernel/zen.nix
    ../../modules/virtualization/kvm.nix
  ];
}
```

## 5. Decisões técnicas

- Separação em módulos para reuso e clareza
- Comentários e documentação em PT-BR
- Uso de práticas recomendadas do NixOS
- Foco em estabilidade, desempenho e reprodutibilidade

## 6. Referências

- [NixOS Manual: Kernel](https://nixos.org/manual/nixos/stable/#sec-kernel)
- [NixOS Manual: Virtualization](https://nixos.org/manual/nixos/stable/#sec-virtualization)
- [Zen Kernel (Liquorix)](https://liquorix.net/)
- [Libvirt](https://libvirt.org/)
- [QEMU](https://www.qemu.org/)
- [Virt-manager](https://virt-manager.org/)
