# Parametros exemplo consumidos pelo flake quando
# `/var/lib/node/runtime/params.nix` ainda nao foi gerado localmente.
#
# O arquivo real `params.nix` vive fora do checkout Git operacional para
# evitar drift entre codigo versionado e estado persistente do host.
{
  runtimeSource = "example";
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

  mgmtInterface = "enp1s0";
  mgmtPrefixLength = 24;
  mgmtGateway = "192.168.100.1";
  mgmtDns = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  wanInterface = "";
  wanMode = "dhcp";
  wanAddress = "";
  wanPrefixLength = 24;
  wanGateway = "";
  wanDns = [ ];
  wanPppoeUser = "";

  adminUser = "rag";
  adminUid = 1000;
  adminEmail = "admin@localhost";
  adminHashedPassword = "$6$X7UWQwAjaccKtoGa$W2PYKbzuPU6IXoAzVH2x/cL6LqO2ctiD1YdDkt/RbSZvlUeJHjW/LsKvY/FiB8uCjrmkJzG9NTigB9c6d6mCI1";
  adminAuthorizedKeys = [ ];

  dataDisk = "/dev/disk/by-label/node-data";
  dataFsType = "btrfs";
  rootRaid = false;
}
