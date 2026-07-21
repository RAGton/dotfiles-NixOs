# Validações centrais dos parâmetros do NODE antes da composição NixOS.
nodeParams:
if nodeParams.serverIp == "" then
  builtins.throw "NODE: nodeParams.serverIp não pode ser vazio"
else if !(builtins.isInt nodeParams.httpPort) then
  builtins.throw "NODE: nodeParams.httpPort deve ser um número inteiro"
else if (nodeParams.hostName or "") == "" then
  builtins.throw "NODE: nodeParams.hostName não pode ser vazio"
else if (nodeParams.timeZone or "") == "" then
  builtins.throw "NODE: nodeParams.timeZone não pode ser vazio"
else if (nodeParams.locale or "") == "" then
  builtins.throw "NODE: nodeParams.locale não pode ser vazio"
else if (nodeParams.keyMap or "") == "" then
  builtins.throw "NODE: nodeParams.keyMap não pode ser vazio"
else if !(builtins.isString (nodeParams.clientPrimaryNicMac or "")) then
  builtins.throw "NODE: nodeParams.clientPrimaryNicMac deve ser string"
else if
  !builtins.elem (nodeParams.clientDefaultChannel or "generic") [
    "generic"
    "lab"
  ]
then
  builtins.throw "NODE: nodeParams.clientDefaultChannel invalido (generic|lab)"
else if (nodeParams.runtimeSource or "runtime") == "placeholder" then
  builtins.throw "NODE: nodeParams.runtimeSource=placeholder não é aceito"
else if
  !builtins.elem (nodeParams.runtimeSource or "runtime") [
    "runtime"
    "defaults"
    "example"
  ]
then
  builtins.throw "NODE: nodeParams.runtimeSource inválido (runtime|defaults|example)"
else if (nodeParams.mgmtInterface or "") == "" then
  builtins.throw "NODE: nodeParams.mgmtInterface não pode ser vazio"
else if
  (nodeParams.mgmtBondMode or "") != ""
  && !builtins.elem (nodeParams.mgmtBondMode or "") [ "active-backup" ]
then
  builtins.throw "NODE: nodeParams.mgmtBondMode inválido (active-backup)"
else if
  (nodeParams.mgmtBondMode or "") != "" && !(builtins.isList (nodeParams.mgmtBondMembers or [ ]))
then
  builtins.throw "NODE: nodeParams.mgmtBondMembers deve ser uma lista"
else if
  (nodeParams.mgmtBondMode or "") != "" && builtins.length (nodeParams.mgmtBondMembers or [ ]) < 2
then
  builtins.throw "NODE: nodeParams.mgmtBondMembers exige pelo menos 2 interfaces"
else if
  (nodeParams.mgmtBondMode or "") != ""
  && builtins.any (member: member == (nodeParams.mgmtInterface or "")) (
    nodeParams.mgmtBondMembers or [ ]
  )
then
  builtins.throw "NODE: nodeParams.mgmtInterface deve ser o bond lógico, não uma porta membro"
else if !(builtins.isInt (nodeParams.mgmtPrefixLength or 24)) then
  builtins.throw "NODE: nodeParams.mgmtPrefixLength deve ser inteiro (ex: 24)"
else if (nodeParams.mgmtGateway or "") == "" then
  builtins.throw "NODE: nodeParams.mgmtGateway não pode ser vazio"
else if (nodeParams.inventoryDir or "/etc/node-inventory") == "" then
  builtins.throw "NODE: nodeParams.inventoryDir não pode ser vazio"
else if !(builtins.isBool (nodeParams.inventoryRequireNonEmpty or false)) then
  builtins.throw "NODE: nodeParams.inventoryRequireNonEmpty deve ser booleano"
else if !(builtins.isList (nodeParams.mgmtDns or [ ])) then
  builtins.throw "NODE: nodeParams.mgmtDns deve ser uma lista de strings"
else if
  !builtins.elem (nodeParams.wanMode or "dhcp") [
    "dhcp"
    "static"
    "pppoe"
  ]
then
  builtins.throw "NODE: nodeParams.wanMode inválido (dhcp|static|pppoe)"
else if
  (nodeParams.wanInterface or "") != ""
  && (nodeParams.wanInterface or "") == (nodeParams.mgmtInterface or "")
then
  builtins.throw "NODE: nodeParams.wanInterface não pode ser igual a nodeParams.mgmtInterface"
else if
  (nodeParams.wanInterface or "") != ""
  && builtins.any (member: member == (nodeParams.wanInterface or "")) (
    nodeParams.mgmtBondMembers or [ ]
  )
then
  builtins.throw "NODE: nodeParams.wanInterface não pode pertencer ao bond LAN"
else if
  (nodeParams.wanInterface or "") != ""
  && (nodeParams.wanMode or "dhcp") == "static"
  && (nodeParams.wanAddress or "") == ""
then
  builtins.throw "NODE: nodeParams.wanAddress não pode ser vazio quando wanMode=static"
else if
  (nodeParams.wanInterface or "") != ""
  && (nodeParams.wanMode or "dhcp") == "static"
  && !(builtins.isInt (nodeParams.wanPrefixLength or 24))
then
  builtins.throw "NODE: nodeParams.wanPrefixLength deve ser inteiro quando wanMode=static"
else if
  (nodeParams.wanInterface or "") != ""
  && (nodeParams.wanMode or "dhcp") == "static"
  && (nodeParams.wanGateway or "") == ""
then
  builtins.throw "NODE: nodeParams.wanGateway não pode ser vazio quando wanMode=static"
else if
  (nodeParams.wanInterface or "") != ""
  && (nodeParams.wanMode or "dhcp") == "static"
  && !(builtins.isList (nodeParams.wanDns or [ ]))
then
  builtins.throw "NODE: nodeParams.wanDns deve ser uma lista de strings quando wanMode=static"
else if
  (nodeParams.wanInterface or "") != ""
  && (nodeParams.wanMode or "dhcp") == "pppoe"
  && (nodeParams.wanPppoeUser or "") == ""
then
  builtins.throw "NODE: nodeParams.wanPppoeUser não pode ser vazio quando wanMode=pppoe"
else if nodeParams.adminUser == "" then
  builtins.throw "NODE: nodeParams.adminUser não pode ser vazio"
else if nodeParams.adminHashedPassword == "" then
  builtins.throw "NODE: nodeParams.adminHashedPassword não pode ser vazio — use: mkpasswd -m sha-512"
else if nodeParams.dataDisk == "" then
  builtins.throw "NODE: nodeParams.dataDisk não pode ser vazio — ex: /dev/sdb"
else if
  !builtins.elem (nodeParams.dataFsType or "btrfs") [
    "btrfs"
    "ext4"
    "xfs"
  ]
then
  builtins.throw "NODE: nodeParams.dataFsType inválido (btrfs|ext4|xfs)"
else
  true
