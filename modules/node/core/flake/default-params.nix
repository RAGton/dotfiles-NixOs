# Parametros declarativos para avaliacao generica do flake.
#
# Este arquivo e a base dos outputs genericos (cliente, knyc, ISO) quando
# o runtime persistente do host nao esta disponivel. Ele NAO representa o
# runtime do servidor instalado e NAO deve ser editado como se fosse estado.
{
  runtimeSource = "defaults";
  brandingAssets = import ./branding-assets.nix;

  serverIp = "192.168.100.2";
  httpPort = 8080;

  clientGuest = "physical";
  clientBootVerbose = false;
  clientPrimaryNicMac = "";
  clientDefaultChannel = "generic";

  inventoryDir = "/etc/node-inventory";
  inventoryRequireNonEmpty = false;

  hostName = "srv-rag";
  timeZone = "America/Cuiaba";
  locale = "pt_BR.UTF-8";
  keyMap = "br-abnt2";

  # ─────────────────────────────────────────────────────────────────────────────
  # MANAGEMENT INTERFACE — LAN/PXE dos clientes
  # No lab KVM: primeira NIC libvirt (net-ragthink) → eth0
  # ─────────────────────────────────────────────────────────────────────────────
  mgmtInterface = "eth0";
  mgmtPrefixLength = 24;
  mgmtGateway = "192.168.100.1";
  mgmtDns = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  # ─────────────────────────────────────────────────────────────────────────────
  # WAN INTERFACE — Uplink para internet
  # No lab KVM: segunda NIC libvirt (default/NAT) → eth1
  # CRÍTICO: Se vazio (""), NAT é desabilitado e srv-rag NÃO funciona como gateway!
  # ─────────────────────────────────────────────────────────────────────────────
  wanInterface = "eth1"; # ← CORREÇÃO: Era vazio, agora aponta para WAN
  wanMode = "dhcp"; # ← Usar DHCP da rede NAT libvirt
  wanAddress = ""; # ← Deixar vazio para DHCP
  wanPrefixLength = 24;
  wanGateway = ""; # ← Deixar vazio para o DHCP descobrir
  wanDns = [ ]; # ← Deixar vazio para o DHCP descobrir
  wanPppoeUser = "";

  # ─────────────────────────────────────────────────────────────────────────────
  # ADMIN USER — Customizável durante instalação
  # IMPORTANTE: O instalador PERGUNTA pelo nome do admin. Não é mais hardcoded "rag"
  # Se deixar vazio (""), o cliente usa defaults para dev/testes
  # ─────────────────────────────────────────────────────────────────────────────
  adminUser = "rag"; # ← DEFAULT para dev/testes. Mudar durante instalação CLI
  adminUid = 1000; # ← UID fixo (primeiro usuário normal)
  adminEmail = "admin@localhost";
  # Senha padrão dev: "node123" (MUDE EM PRODUÇÃO!)
  adminHashedPassword = "$6$X7UWQwAjaccKtoGa$W2PYKbzuPU6IXoAzVH2x/cL6LqO2ctiD1YdDkt/RbSZvlUeJHjW/LsKvY/FiB8uCjrmkJzG9NTigB9c6d6mCI1";
  adminAuthorizedKeys = [ ];

  dataDisk = "/dev/disk/by-label/node-data";
  dataFsType = "btrfs";
  rootRaid = false;
}
