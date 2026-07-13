# Parâmetros consumidos pelo flake durante `nixos-install`.
# O instalador (Live ISO) deve sobrescrever este arquivo no sistema alvo.
#
# IMPORTANTE: mantenha os campos e tipos estáveis.
{
  serverIp = "192.168.100.2";
  httpPort = 8080;

  # Identidade do host
  hostName = "srv-rag";
  timeZone = "America/Cuiaba";
  locale = "pt_BR.UTF-8";
  keyMap = "br-abnt2";

  # Rede de gerenciamento (systemd-networkd)
  mgmtInterface = "enp1s0";
  mgmtPrefixLength = 24;
  mgmtGateway = "192.168.100.1";
  mgmtDns = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  # WAN/Uplink opcional. Quando informado, habilita rota padrão e NAT.
  wanInterface = "";
  wanMode = "dhcp";
  wanAddress = "";
  wanPrefixLength = 24;
  wanGateway = "";
  wanDns = [ ];
  wanPppoeUser = "";

  adminUser = "rag";
  adminUid = 1000;

  # Opcional: usado para notificações (se você configurar e-mail depois)
  adminEmail = "admin@localhost";

  # Gerar: `mkpasswd -m sha-512`
  adminHashedPassword = "$6$X7UWQwAjaccKtoGa$W2PYKbzuPU6IXoAzVH2x/cL6LqO2ctiD1YdDkt/RbSZvlUeJHjW/LsKvY/FiB8uCjrmkJzG9NTigB9c6d6mCI1";

  # Chaves públicas SSH do admin (opcional)
  adminAuthorizedKeys = [ ];

  # Partição/dispositivo BTRFS onde ficam homes/imagens/snapshots.
  # Use um identificador estável, preferindo /dev/disk/by-label/...
  # e usando /dev/disk/by-uuid/... como fallback.
  dataDisk = "/dev/disk/by-label/ragos-data";

  # Tipo de filesystem do disco de dados.
  # - "btrfs" (recomendado): habilita subvolumes e snapshots
  # - "ext4"/"xfs": monta /srv/data como um único filesystem (sem subvolumes)
  dataFsType = "btrfs";

  # Habilita suporte de boot para RAID por software somente quando a raiz foi instalada em /dev/md.
  rootRaid = false;
}
