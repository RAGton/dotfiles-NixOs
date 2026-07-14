/*
  Bootstrap/template do inventario externo do NODE.

  Este arquivo nao e mais consumido diretamente pelo srv-rag.
  Ele existe para migracao/bootstrap do inventario externo persistente
  em /etc/node-inventory/clients.nix.
  Quando copiado para /etc/node-inventory/clients.nix, passa a ser a
  fonte canonica e ativa do inventario de clientes.
*/
[
  {
    # MAC real da placa do cliente.
    mac = "52:54:00:64:10:11";

    # Hostname entregue por DHCP/PXE para o cliente.
    hostname = "tc-01";

    # IP fixo dentro da LAN/PXE do srv-rag.
    ip = "192.168.100.110";

    # Contrato atual do inventario ainda usa channel + hardwareClass.
    channel = "generic";

    # Camada compativel da semantica nova.
    releaseTrack = "stable";
    clientProfile = "workstation";
    bootMethod = "ipxe";

    hardwareClass = "physical-generic";
  }

  {
    mac = "52:54:00:64:10:12";
    hostname = "tc-02";
    ip = "192.168.100.111";
    channel = "lab";
    releaseTrack = "pilot";
    clientProfile = "lab-workstation";
    bootMethod = "ipxe";
    hardwareClass = "physical-lab";
  }
]
