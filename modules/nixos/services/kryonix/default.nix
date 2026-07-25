# Wrapper categorizador para modulos kryonix.* (servicos opt-in)
# Mantem o services/kryxd (servico core) separado do services/kryonix (features opt-in).

{ lib, ... }:
{
  imports = [
    ./kcp
  ];

  # Nenhuma opcao default aqui: kryonix.kcp.enable continua opt-in (default = false).
}
