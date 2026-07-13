# Validações centrais dos parâmetros do RAGOS antes da composição NixOS.
ragosParams:
if ragosParams.serverIp == "" then
  builtins.throw "RAGOS: ragosParams.serverIp não pode ser vazio"
else if !(builtins.isInt ragosParams.httpPort) then
  builtins.throw "RAGOS: ragosParams.httpPort deve ser um número inteiro"
else if (ragosParams.hostName or "") == "" then
  builtins.throw "RAGOS: ragosParams.hostName não pode ser vazio"
else if (ragosParams.timeZone or "") == "" then
  builtins.throw "RAGOS: ragosParams.timeZone não pode ser vazio"
else if (ragosParams.locale or "") == "" then
  builtins.throw "RAGOS: ragosParams.locale não pode ser vazio"
else if (ragosParams.keyMap or "") == "" then
  builtins.throw "RAGOS: ragosParams.keyMap não pode ser vazio"
else if !(builtins.isString (ragosParams.clientPrimaryNicMac or "")) then
  builtins.throw "RAGOS: ragosParams.clientPrimaryNicMac deve ser string"
else if
  !builtins.elem (ragosParams.clientDefaultChannel or "generic") [
    "generic"
    "lab"
  ]
then
  builtins.throw "RAGOS: ragosParams.clientDefaultChannel invalido (generic|lab)"
else if (ragosParams.runtimeSource or "runtime") == "placeholder" then
  builtins.throw "RAGOS: ragosParams.runtimeSource=placeholder não é aceito"
else if
  !builtins.elem (ragosParams.runtimeSource or "runtime") [
    "runtime"
    "defaults"
    "example"
  ]
then
  builtins.throw "RAGOS: ragosParams.runtimeSource inválido (runtime|defaults|example)"
else if (ragosParams.mgmtInterface or "") == "" then
  builtins.throw "RAGOS: ragosParams.mgmtInterface não pode ser vazio"
else if
  (ragosParams.mgmtBondMode or "") != ""
  && !builtins.elem (ragosParams.mgmtBondMode or "") [ "active-backup" ]
then
  builtins.throw "RAGOS: ragosParams.mgmtBondMode inválido (active-backup)"
else if
  (ragosParams.mgmtBondMode or "") != "" && !(builtins.isList (ragosParams.mgmtBondMembers or [ ]))
then
  builtins.throw "RAGOS: ragosParams.mgmtBondMembers deve ser uma lista"
else if
  (ragosParams.mgmtBondMode or "") != "" && builtins.length (ragosParams.mgmtBondMembers or [ ]) < 2
then
  builtins.throw "RAGOS: ragosParams.mgmtBondMembers exige pelo menos 2 interfaces"
else if
  (ragosParams.mgmtBondMode or "") != ""
  && builtins.any (member: member == (ragosParams.mgmtInterface or "")) (
    ragosParams.mgmtBondMembers or [ ]
  )
then
  builtins.throw "RAGOS: ragosParams.mgmtInterface deve ser o bond lógico, não uma porta membro"
else if !(builtins.isInt (ragosParams.mgmtPrefixLength or 24)) then
  builtins.throw "RAGOS: ragosParams.mgmtPrefixLength deve ser inteiro (ex: 24)"
else if (ragosParams.mgmtGateway or "") == "" then
  builtins.throw "RAGOS: ragosParams.mgmtGateway não pode ser vazio"
else if (ragosParams.inventoryDir or "/etc/ragos-inventory") == "" then
  builtins.throw "RAGOS: ragosParams.inventoryDir não pode ser vazio"
else if !(builtins.isBool (ragosParams.inventoryRequireNonEmpty or false)) then
  builtins.throw "RAGOS: ragosParams.inventoryRequireNonEmpty deve ser booleano"
else if !(builtins.isList (ragosParams.mgmtDns or [ ])) then
  builtins.throw "RAGOS: ragosParams.mgmtDns deve ser uma lista de strings"
else if
  !builtins.elem (ragosParams.wanMode or "dhcp") [
    "dhcp"
    "static"
    "pppoe"
  ]
then
  builtins.throw "RAGOS: ragosParams.wanMode inválido (dhcp|static|pppoe)"
else if
  (ragosParams.wanInterface or "") != ""
  && (ragosParams.wanInterface or "") == (ragosParams.mgmtInterface or "")
then
  builtins.throw "RAGOS: ragosParams.wanInterface não pode ser igual a ragosParams.mgmtInterface"
else if
  (ragosParams.wanInterface or "") != ""
  && builtins.any (member: member == (ragosParams.wanInterface or "")) (
    ragosParams.mgmtBondMembers or [ ]
  )
then
  builtins.throw "RAGOS: ragosParams.wanInterface não pode pertencer ao bond LAN"
else if
  (ragosParams.wanInterface or "") != ""
  && (ragosParams.wanMode or "dhcp") == "static"
  && (ragosParams.wanAddress or "") == ""
then
  builtins.throw "RAGOS: ragosParams.wanAddress não pode ser vazio quando wanMode=static"
else if
  (ragosParams.wanInterface or "") != ""
  && (ragosParams.wanMode or "dhcp") == "static"
  && !(builtins.isInt (ragosParams.wanPrefixLength or 24))
then
  builtins.throw "RAGOS: ragosParams.wanPrefixLength deve ser inteiro quando wanMode=static"
else if
  (ragosParams.wanInterface or "") != ""
  && (ragosParams.wanMode or "dhcp") == "static"
  && (ragosParams.wanGateway or "") == ""
then
  builtins.throw "RAGOS: ragosParams.wanGateway não pode ser vazio quando wanMode=static"
else if
  (ragosParams.wanInterface or "") != ""
  && (ragosParams.wanMode or "dhcp") == "static"
  && !(builtins.isList (ragosParams.wanDns or [ ]))
then
  builtins.throw "RAGOS: ragosParams.wanDns deve ser uma lista de strings quando wanMode=static"
else if
  (ragosParams.wanInterface or "") != ""
  && (ragosParams.wanMode or "dhcp") == "pppoe"
  && (ragosParams.wanPppoeUser or "") == ""
then
  builtins.throw "RAGOS: ragosParams.wanPppoeUser não pode ser vazio quando wanMode=pppoe"
else if ragosParams.adminUser == "" then
  builtins.throw "RAGOS: ragosParams.adminUser não pode ser vazio"
else if ragosParams.adminHashedPassword == "" then
  builtins.throw "RAGOS: ragosParams.adminHashedPassword não pode ser vazio — use: mkpasswd -m sha-512"
else if ragosParams.dataDisk == "" then
  builtins.throw "RAGOS: ragosParams.dataDisk não pode ser vazio — ex: /dev/sdb"
else if
  !builtins.elem (ragosParams.dataFsType or "btrfs") [
    "btrfs"
    "ext4"
    "xfs"
  ]
then
  builtins.throw "RAGOS: ragosParams.dataFsType inválido (btrfs|ext4|xfs)"
else
  true
