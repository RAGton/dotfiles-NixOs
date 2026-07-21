{
  lib,
  nodeTimeZone,
  nodeKeyMap,
  nodeClientPrimaryNicMac ? "",
  ...
}:

{
  options.node.profile.name = lib.mkOption {
    type = lib.types.str;
    default = "desktop-generic";
    description = "Nome semântico do profile ativo do cliente NODE.";
  };

  options.node.profile.guest = lib.mkOption {
    type = lib.types.enum [
      "hyperv"
      "physical"
    ];
    default = "physical";
    description = "Classe de hardware/virtualizacao do profile do cliente.";
  };

  options.node.profile.bootVerbose = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Controla verbosidade do boot e do initrd para o profile do cliente.";
  };

  options.node.boot.primaryNicMac = lib.mkOption {
    type = lib.types.str;
    default = "";
    example = "52:54:00:64:10:11";
    description = "MAC preferencial da NIC de boot no cliente. Vazio habilita DHCP em todas as interfaces cabeadas.";
  };

  config = {
    time.timeZone = lib.mkDefault nodeTimeZone;
    console.keyMap = lib.mkDefault nodeKeyMap;
    node.boot.primaryNicMac = lib.mkDefault nodeClientPrimaryNicMac;
  };
}
