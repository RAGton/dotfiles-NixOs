{ lib }:

let
  allowedBootMethods = [
    "ipxe"
    "uefi-http"
    "uefi-https"
  ];
  allowedChannels = [
    "generic"
    "lab"
    "rescue"
  ];
  allowedReleaseTracks = [
    "stable"
    "pilot"
    "rescue"
  ];
  allowedProfiles = [
    "desktop-generic"
    "desktop-lab"
    "hyperv-debug"
    "rescue-minimal"
  ];
  allowedClientProfiles = [
    "workstation"
    "lab-workstation"
    "hyperv-debug"
    "rescue"
  ];
  allowedHardwareClasses = [
    "physical-generic"
    "physical-lab"
    "hyperv"
    "rescue"
  ];
  defaultBootMethod = "ipxe";
  defaultChannel = "generic";

  channelToReleaseTrackMap = {
    generic = "stable";
    lab = "pilot";
    rescue = "rescue";
  };

  releaseTrackToChannelMap = {
    stable = "generic";
    pilot = "lab";
    rescue = "rescue";
  };

  profileToClientProfileMap = {
    desktop-generic = "workstation";
    desktop-lab = "lab-workstation";
    hyperv-debug = "hyperv-debug";
    rescue-minimal = "rescue";
  };

  clientProfileToProfileMap = {
    workstation = "desktop-generic";
    lab-workstation = "desktop-lab";
    hyperv-debug = "hyperv-debug";
    rescue = "rescue-minimal";
  };

  profileToHardwareClassMap = {
    desktop-generic = "physical-generic";
    desktop-lab = "physical-lab";
    hyperv-debug = "hyperv";
    rescue-minimal = "rescue";
  };

  defaultProfileForChannelMap = {
    generic = "desktop-generic";
    lab = "desktop-lab";
    rescue = "rescue-minimal";
  };

  defaultHardwareClassForChannelMap = {
    generic = "physical-generic";
    lab = "physical-lab";
    rescue = "rescue";
  };

  attrStringOrNull =
    client: name:
    let
      value = lib.attrByPath [ name ] null client;
    in
    if builtins.isString value && value != "" then value else null;

  profileForChannelAndHardware =
    channel: hardwareClass:
    if channel == "generic" && hardwareClass == "physical-generic" then
      "desktop-generic"
    else if channel == "lab" && hardwareClass == "physical-lab" then
      "desktop-lab"
    else if channel == "lab" && hardwareClass == "hyperv" then
      "hyperv-debug"
    else if channel == "rescue" && hardwareClass == "rescue" then
      "rescue-minimal"
    else
      null;

  clientChannel =
    client:
    let
      channelValue = attrStringOrNull client "channel";
      releaseTrackValue = attrStringOrNull client "releaseTrack";
    in
    if channelValue != null && builtins.elem channelValue allowedChannels then
      channelValue
    else if releaseTrackValue != null && builtins.elem releaseTrackValue allowedReleaseTracks then
      releaseTrackToChannelMap.${releaseTrackValue}
    else
      defaultChannel;

  clientReleaseTrack =
    client:
    let
      releaseTrackValue = attrStringOrNull client "releaseTrack";
      channel = clientChannel client;
    in
    if releaseTrackValue != null && builtins.elem releaseTrackValue allowedReleaseTracks then
      releaseTrackValue
    else
      channelToReleaseTrackMap.${channel};

  clientProfile =
    client:
    let
      profileValue = attrStringOrNull client "profile";
      clientProfileValue = attrStringOrNull client "clientProfile";
      channel = clientChannel client;
      explicitHardwareClass = attrStringOrNull client "hardwareClass";
      resolvedHardwareClass =
        if explicitHardwareClass != null && builtins.elem explicitHardwareClass allowedHardwareClasses then
          explicitHardwareClass
        else
          defaultHardwareClassForChannelMap.${channel};
    in
    if profileValue != null && builtins.elem profileValue allowedProfiles then
      profileValue
    else if clientProfileValue != null && builtins.elem clientProfileValue allowedClientProfiles then
      clientProfileToProfileMap.${clientProfileValue}
    else
      let
        derivedProfile = profileForChannelAndHardware channel resolvedHardwareClass;
      in
      if derivedProfile != null then derivedProfile else defaultProfileForChannelMap.${channel};

  clientClientProfile =
    client:
    let
      clientProfileValue = attrStringOrNull client "clientProfile";
      profile = clientProfile client;
    in
    if clientProfileValue != null && builtins.elem clientProfileValue allowedClientProfiles then
      clientProfileValue
    else
      profileToClientProfileMap.${profile};

  clientHardwareClass =
    client:
    let
      hardwareClassValue = attrStringOrNull client "hardwareClass";
      profile = clientProfile client;
    in
    if hardwareClassValue != null && builtins.elem hardwareClassValue allowedHardwareClasses then
      hardwareClassValue
    else
      profileToHardwareClassMap.${profile};

  clientBootMethod =
    client:
    let
      bootMethodValue = attrStringOrNull client "bootMethod";
    in
    if bootMethodValue != null && builtins.elem bootMethodValue allowedBootMethods then
      bootMethodValue
    else
      defaultBootMethod;

  normalizeClient =
    client:
    let
      channel = clientChannel client;
      releaseTrack = clientReleaseTrack client;
      profile = clientProfile client;
      clientProfileValue = clientClientProfile client;
      hardwareClass = clientHardwareClass client;
      bootMethod = clientBootMethod client;
    in
    client
    // {
      inherit
        channel
        releaseTrack
        profile
        hardwareClass
        bootMethod
        ;
      clientProfile = clientProfileValue;
      bootEndpoint = "${channel}.ipxe";
    };

  normalizeInventory = inventory: map normalizeClient inventory;

  duplicatesOf =
    values:
    lib.unique (
      builtins.filter (
        value: builtins.length (builtins.filter (candidate: candidate == value) values) > 1
      ) values
    );

  validateInventory =
    inventory:
    let
      normalizedClients = normalizeInventory inventory;
      macs = map (client: client.mac) inventory;
      hostnames = map (client: client.hostname) inventory;
      ips = map (client: client.ip) inventory;
      invalidChannelTrackClients = map (client: "${client.hostname} (${client.mac})") (
        builtins.filter (
          client:
          let
            channelValue = attrStringOrNull client "channel";
            releaseTrackValue = attrStringOrNull client "releaseTrack";
          in
          channelValue != null
          && releaseTrackValue != null
          && builtins.elem channelValue allowedChannels
          && builtins.elem releaseTrackValue allowedReleaseTracks
          && channelToReleaseTrackMap.${channelValue} != releaseTrackValue
        ) inventory
      );
      invalidProfileAliasClients = map (client: "${client.hostname} (${client.mac})") (
        builtins.filter (
          client:
          let
            profileValue = attrStringOrNull client "profile";
            clientProfileValue = attrStringOrNull client "clientProfile";
          in
          profileValue != null
          && clientProfileValue != null
          && builtins.elem profileValue allowedProfiles
          && builtins.elem clientProfileValue allowedClientProfiles
          && profileToClientProfileMap.${profileValue} != clientProfileValue
        ) inventory
      );
      invalidResolvedCombos =
        map
          (
            client:
            "${client.hostname} (${client.mac}): channel=${client.channel}, profile=${client.profile}, hardwareClass=${client.hardwareClass}"
          )
          (
            builtins.filter (
              client: profileForChannelAndHardware client.channel client.hardwareClass != client.profile
            ) normalizedClients
          );
      reservedBootMethods = map (client: "${client.hostname} (${client.mac})") (
        builtins.filter (client: client.bootMethod == "uefi-https") normalizedClients
      );

      duplicateMacs = duplicatesOf macs;
      duplicateHostnames = duplicatesOf hostnames;
      duplicateIps = duplicatesOf ips;
    in
    {
      assertions = [
        {
          assertion = builtins.all (
            client:
            client ? mac
            && client.mac != ""
            && client ? hostname
            && client.hostname != ""
            && client ? ip
            && client.ip != ""
          ) inventory;
          message = "NODE: cada cliente do inventario precisa declarar mac, hostname e ip.";
        }
        {
          assertion = builtins.all (
            client: (!client ? channel) || builtins.elem client.channel allowedChannels
          ) inventory;
          message = "NODE: channel invalido no inventario (permitidos: generic, lab, rescue).";
        }
        {
          assertion = builtins.all (
            client: (!client ? releaseTrack) || builtins.elem client.releaseTrack allowedReleaseTracks
          ) inventory;
          message = "NODE: releaseTrack invalido no inventario (permitidos: stable, pilot, rescue).";
        }
        {
          assertion = invalidChannelTrackClients == [ ];
          message = "NODE: channel e releaseTrack incoerentes no inventario: ${lib.concatStringsSep ", " invalidChannelTrackClients}";
        }
        {
          assertion = builtins.all (
            client: (!client ? profile) || builtins.elem client.profile allowedProfiles
          ) inventory;
          message = "NODE: profile invalido no inventario (permitidos: desktop-generic, desktop-lab, hyperv-debug, rescue-minimal).";
        }
        {
          assertion = builtins.all (
            client: (!client ? clientProfile) || builtins.elem client.clientProfile allowedClientProfiles
          ) inventory;
          message = "NODE: clientProfile invalido no inventario (permitidos: workstation, lab-workstation, hyperv-debug, rescue).";
        }
        {
          assertion = invalidProfileAliasClients == [ ];
          message = "NODE: profile e clientProfile incoerentes no inventario: ${lib.concatStringsSep ", " invalidProfileAliasClients}";
        }
        {
          assertion = builtins.all (
            client: (!client ? bootMethod) || builtins.elem client.bootMethod allowedBootMethods
          ) inventory;
          message = "NODE: bootMethod invalido no inventario (permitidos: ipxe, uefi-http, uefi-https).";
        }
        {
          assertion = reservedBootMethods == [ ];
          message = "NODE: bootMethod=uefi-https ainda e reservado/futuro e nao pode ser usado sem prova real do caminho: ${lib.concatStringsSep ", " reservedBootMethods}";
        }
        {
          assertion = builtins.all (
            client: (!client ? hardwareClass) || builtins.elem client.hardwareClass allowedHardwareClasses
          ) inventory;
          message = "NODE: hardwareClass invalido no inventario (permitidos: physical-generic, physical-lab, hyperv, rescue).";
        }
        {
          assertion = invalidResolvedCombos == [ ];
          message = "NODE: combinacao invalida entre channel/releaseTrack, profile/clientProfile e hardwareClass: ${lib.concatStringsSep "; " invalidResolvedCombos}";
        }
        {
          assertion = duplicateMacs == [ ];
          message = "NODE: inventario invalido - MAC duplicado: ${lib.concatStringsSep ", " duplicateMacs}";
        }
        {
          assertion = duplicateHostnames == [ ];
          message = "NODE: inventario invalido - hostname duplicado: ${lib.concatStringsSep ", " duplicateHostnames}";
        }
        {
          assertion = duplicateIps == [ ];
          message = "NODE: inventario invalido - IP duplicado: ${lib.concatStringsSep ", " duplicateIps}";
        }
      ];

      dhcpHosts = map (
        client:
        "${client.mac},set:known,set:chan-${client.channel},set:hw-${client.hardwareClass},${client.hostname},${client.ip},infinite"
      ) normalizedClients;

      ipxeRoutes = map (
        client:
        let
          channel = client.channel;
          hardwareClass = client.hardwareClass;
        in
        {
          mac = lib.toLower client.mac;
          inherit channel hardwareClass;
          releaseTrack = client.releaseTrack;
          profile = client.profile;
          clientProfile = client.clientProfile;
          bootMethod = client.bootMethod;
          hostname = client.hostname;
          ip = client.ip;
          bootEndpoint = client.bootEndpoint;
        }
      ) normalizedClients;

      resolvedClients = normalizedClients;
    };

  validateInventoryWithPolicy =
    {
      inventory,
      requireNonEmpty ? true,
    }:
    let
      validated = validateInventory inventory;
      nonEmptyAssertion = {
        assertion = (!requireNonEmpty) || inventory != [ ];
        message = "NODE: inventario externo vazio - recuse inventario vazio por padrao ou desabilite essa protecao explicitamente.";
      };
    in
    validated
    // {
      assertions = validated.assertions ++ [ nonEmptyAssertion ];
    };
in
{
  inherit normalizeClient;
  inherit normalizeInventory;
  inherit validateInventory;
  inherit validateInventoryWithPolicy;
}
