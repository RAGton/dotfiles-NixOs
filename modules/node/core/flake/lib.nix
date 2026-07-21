# Helpers do flake para propagar `specialArgs` estáveis pela árvore canônica.
{ nodeParams, check }:
let
  brandingAssets = nodeParams.brandingAssets or (import ./branding-assets.nix);
in
{
  mkSpecialArgs = builtins.seq check {
    nodeBrandingAssets = brandingAssets;
    nodeServerIp = nodeParams.serverIp;
    nodeHttpPort = nodeParams.httpPort;
    nodeClientGuest = nodeParams.clientGuest or "physical";
    nodeClientBootVerbose = nodeParams.clientBootVerbose or false;
    nodeClientPrimaryNicMac = nodeParams.clientPrimaryNicMac or "";
    nodeClientDefaultChannel = nodeParams.clientDefaultChannel or "generic";
    nodeInventoryDir = nodeParams.inventoryDir or "/etc/node-inventory";
    nodeInventoryRequireNonEmpty = nodeParams.inventoryRequireNonEmpty or false;
    nodeRuntimeSource = nodeParams.runtimeSource or "defaults";
    nodeRuntimeIsPlaceholder = (nodeParams.runtimeSource or "defaults") != "runtime";
    nodeClientUsers = nodeParams.clientUsers or { };

    nodeHostName = nodeParams.hostName;
    nodeTimeZone = nodeParams.timeZone;
    nodeLocale = nodeParams.locale;
    nodeKeyMap = nodeParams.keyMap;

    nodeMgmtInterface = nodeParams.mgmtInterface;
    nodeMgmtBondMode = nodeParams.mgmtBondMode or "";
    nodeMgmtBondMembers = nodeParams.mgmtBondMembers or [ ];
    nodeMgmtPrefixLength = nodeParams.mgmtPrefixLength;
    nodeMgmtGateway = nodeParams.mgmtGateway;
    nodeMgmtDns = nodeParams.mgmtDns;
    nodeWanInterface = nodeParams.wanInterface or "";
    nodeWanMode = nodeParams.wanMode or "dhcp";
    nodeWanAddress = nodeParams.wanAddress or "";
    nodeWanPrefixLength = nodeParams.wanPrefixLength or 24;
    nodeWanGateway = nodeParams.wanGateway or "";
    nodeWanDns = nodeParams.wanDns or [ ];
    nodeWanPppoeUser = nodeParams.wanPppoeUser or "";

    nodeAdminUser = nodeParams.adminUser;
    nodeAdminUid = nodeParams.adminUid;
    nodeAdminEmail = nodeParams.adminEmail;
    nodeAdminHashedPassword = nodeParams.adminHashedPassword;
    nodeAdminAuthorizedKeys = nodeParams.adminAuthorizedKeys;
    nodeDataDisk = nodeParams.dataDisk;
    nodeDataFsType = nodeParams.dataFsType or "btrfs";
    nodeRootRaid = nodeParams.rootRaid or false;
  };
}
