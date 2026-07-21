/*
  Runtime persistente do host instalado.

  O estado real do host vive fora da arvore Git operacional:
  - `/var/lib/node/runtime/params.nix`
  - `/var/lib/node/runtime/hardware-configuration.nix`

  Fallbacks rastreados no repositório:
  - `params.example.nix`
  - `hardware-configuration.example.nix`

  O fallback continua existindo apenas para contextos controlados
  (ex.: ISO/installer, documentação e avaliações locais que não sejam o host real).
  O host `srv-rag` adiciona guardrails explícitos e não pode usar esse fallback
  silenciosamente.
*/
let
  # Durante a instalacao o runtime real vive sob /mnt; permitir override
  # explicito evita depender de paths do live system na avaliacao do flake.
  envRuntimeRoot = builtins.getEnv "NODE_RUNTIME_ROOT";
  runtimeRoot = if envRuntimeRoot != "" then envRuntimeRoot else "/var/lib/node/runtime";
  mkAbsPath = path: /. + path;

  paramsPath = mkAbsPath "${runtimeRoot}/params.nix";
  hardwarePath = mkAbsPath "${runtimeRoot}/hardware-configuration.nix";
  clientUsersPath = mkAbsPath "${runtimeRoot}/client-users.json";

  paramsExamplePath = ./params.example.nix;
  hardwareExamplePath = ./hardware-configuration.example.nix;
  clientUsersExamplePath = ./client-users.example.json;

  readJsonObjectOr =
    path: fallbackPath:
    let
      raw = builtins.readFile (if builtins.pathExists path then path else fallbackPath);
      sanitized = if builtins.match "[[:space:]\n\r\t]*" raw != null then "{}" else raw;
    in
    builtins.fromJSON sanitized;

  runtimeParamsPresent = builtins.pathExists paramsPath;
  runtimeHardwarePresent = builtins.pathExists hardwarePath;
  runtimeClientUsersPresent = builtins.pathExists clientUsersPath;
  runtimeSourceKind =
    if runtimeParamsPresent && runtimeHardwarePresent then
      "runtime"
    else if !runtimeParamsPresent && !runtimeHardwarePresent then
      "example"
    else
      "partial";
  importedParams = import (if runtimeParamsPresent then paramsPath else paramsExamplePath);
  importedClientUsers = readJsonObjectOr clientUsersPath clientUsersExamplePath;
in
{
  inherit
    runtimeRoot
    paramsPath
    hardwarePath
    clientUsersPath
    runtimeSourceKind
    runtimeParamsPresent
    runtimeHardwarePresent
    runtimeClientUsersPresent
    ;

  paramsPresent = runtimeParamsPresent;
  hardwarePresent = runtimeHardwarePresent;
  clientUsersPresent = runtimeClientUsersPresent;
  runtimeIsPlaceholder = runtimeSourceKind != "runtime";

  usingPlaceholderParams = runtimeSourceKind != "runtime";
  usingPlaceholderHardware = runtimeSourceKind != "runtime";

  placeholderBootDevices = [
    "/dev/disk/by-label/ESP"
    "/dev/disk/by-label/nixos"
  ];

  params = importedParams // {
    runtimeSource = runtimeSourceKind;
    runtimeRoot = runtimeRoot;
    clientUsers = importedClientUsers;
  };

  clientUsers = importedClientUsers;
  hardwareModule = if runtimeHardwarePresent then hardwarePath else hardwareExamplePath;
}
