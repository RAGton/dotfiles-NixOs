# Helpers do flake para propagar `specialArgs` estáveis pela árvore canônica.
{ ragosParams, check }:
let
  brandingAssets = ragosParams.brandingAssets or (import ./branding-assets.nix);
in
{
  mkSpecialArgs = builtins.seq check {
    ragosBrandingAssets = brandingAssets;
    ragosServerIp = ragosParams.serverIp;
    ragosHttpPort = ragosParams.httpPort;
    ragosClientGuest = ragosParams.clientGuest or "physical";
    ragosClientBootVerbose = ragosParams.clientBootVerbose or false;
    ragosClientPrimaryNicMac = ragosParams.clientPrimaryNicMac or "";
    ragosClientDefaultChannel = ragosParams.clientDefaultChannel or "generic";
    ragosInventoryDir = ragosParams.inventoryDir or "/etc/ragos-inventory";
    ragosInventoryRequireNonEmpty = ragosParams.inventoryRequireNonEmpty or false;
    ragosRuntimeSource = ragosParams.runtimeSource or "defaults";
    ragosRuntimeIsPlaceholder = (ragosParams.runtimeSource or "defaults") != "runtime";
    ragosClientUsers = ragosParams.clientUsers or { };

    ragosHostName = ragosParams.hostName;
    ragosTimeZone = ragosParams.timeZone;
    ragosLocale = ragosParams.locale;
    ragosKeyMap = ragosParams.keyMap;

    ragosMgmtInterface = ragosParams.mgmtInterface;
    ragosMgmtBondMode = ragosParams.mgmtBondMode or "";
    ragosMgmtBondMembers = ragosParams.mgmtBondMembers or [ ];
    ragosMgmtPrefixLength = ragosParams.mgmtPrefixLength;
    ragosMgmtGateway = ragosParams.mgmtGateway;
    ragosMgmtDns = ragosParams.mgmtDns;
    ragosWanInterface = ragosParams.wanInterface or "";
    ragosWanMode = ragosParams.wanMode or "dhcp";
    ragosWanAddress = ragosParams.wanAddress or "";
    ragosWanPrefixLength = ragosParams.wanPrefixLength or 24;
    ragosWanGateway = ragosParams.wanGateway or "";
    ragosWanDns = ragosParams.wanDns or [ ];
    ragosWanPppoeUser = ragosParams.wanPppoeUser or "";

    ragosAdminUser = ragosParams.adminUser;
    ragosAdminUid = ragosParams.adminUid;
    ragosAdminEmail = ragosParams.adminEmail;
    ragosAdminHashedPassword = ragosParams.adminHashedPassword;
    ragosAdminAuthorizedKeys = ragosParams.adminAuthorizedKeys;
    ragosDataDisk = ragosParams.dataDisk;
    ragosDataFsType = ragosParams.dataFsType or "btrfs";
    ragosRootRaid = ragosParams.rootRaid or false;
  };
}
