# Módulos NixOS

## O que é
A unidade fundamental de composição e reutilização no NixOS. Um módulo permite definir configurações, declarar opções (`options`) e implementar lógica condicional (`config`) para configurar serviços, hardware ou preferências de usuário de forma encapsulada.

## Como funciona
O sistema de módulos do NixOS usa um processo de **merging fix-point**. Quando o sistema é avaliado, todos os módulos são combinados em um único conjunto de configurações.

### Estrutura Anatômica:
```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.kryonix.servicos.exemplo;
in {
  options.kryonix.servicos.exemplo = {
    enable = mkEnableOption "serviço de exemplo";
    porta = mkOption {
      type = types.port;
      default = 8080;
      description = "Porta de escuta do serviço.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.exemplo = {
      description = "Serviço de Exemplo";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.exemplo}/bin/exemplo --port ${toString cfg.porta}";
    };
  };
}
```

## Uso prático
No Kryonix, os módulos são usados para abstrair complexidade e garantir padronização entre hosts (Workstation, Gaming, Server).

### Quando criar um módulo:
- Quando uma configuração é repetida em mais de 2 hosts.
- Quando você precisa de parâmetros variáveis (ex: caminhos de disco, usuários).
- Para agrupar serviços que dependem um do outro (ex: Nginx + PHP-FPM).

## Exemplos
### Módulo de Hardening de SSH
```nix
{ config, lib, ... }:
{
  options.kryonix.security.ssh.hardened = lib.mkEnableOption "SSH hardening features";
  
  config = lib.mkIf config.kryonix.security.ssh.hardened {
    services.openssh = {
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
      };
      extraConfig = ''
        AllowAgentForwarding no
        AllowTcpForwarding no
      '';
    };
  };
}
```

## Problemas comuns
- **Infinite Recursion**: Ocorre quando o valor de uma opção depende de si mesma ou de outra opção que cria um loop circular.
- **Opções não tipadas**: Usar `types.attrs` em vez de `types.submodule` dificulta a validação e o autocompletar.
- **mkForce abusivo**: Sobrescreve configurações de outros módulos sem permitir que o sistema de merge do Nix faça seu trabalho corretamente.

## Boas práticas
- Sempre use `mkEnableOption` para controle booleano.
- Documente cada `option` com `description` e, se possível, `example`.
- Use `assertions` para validar estados impossíveis (ex: habilitar um serviço sem configurar sua chave de API).
- Prefira `lib.mkDefault` para valores que os usuários podem querer mudar.

## Links
- [[01-MOCs/Mapa - NixOS e Infra Declarativa]]
- [NixOS Modules Manual](https://nixos.org/manual/nixos/stable/index.html#sec-writing-modules)
