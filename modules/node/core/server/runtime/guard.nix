{ config, lib, ... }:

let
  runtime = import ./.;
  allowPlaceholderRuntime = builtins.getEnv "NODE_ALLOW_PLACEHOLDER_RUNTIME" == "1";
  enforceGuards = !allowPlaceholderRuntime || builtins.getEnv "NODE_ENFORCE_RUNTIME_GUARDS" == "1";
  bootDevice = if config.fileSystems ? "/boot" then config.fileSystems."/boot".device or "" else "";
in
{
  assertions = lib.optionals enforceGuards [
    {
      assertion = runtime.paramsPresent;
      message = "NODE runtime ausente: srv-rag exige runtime local valido em ${runtime.runtimeRoot} (faltando params.nix)";
    }
    {
      assertion = runtime.hardwarePresent;
      message = "NODE runtime ausente: srv-rag exige runtime local valido em ${runtime.runtimeRoot} (faltando hardware-configuration.nix)";
    }
    {
      assertion = bootDevice != "";
      message = "NODE runtime invalido: /boot nao foi resolvido para o host srv-rag";
    }
    {
      assertion = !(builtins.elem bootDevice runtime.placeholderBootDevices);
      message = "NODE runtime invalido: /boot ainda resolve para placeholder (${bootDevice})";
    }
    {
      assertion = runtime.runtimeSourceKind == "runtime";
      message = "NODE runtime invalido: srv-rag exige runtime persistente real, mas encontrou ${runtime.runtimeSourceKind} em ${runtime.runtimeRoot}";
    }
  ];

  warnings = lib.optionals (!enforceGuards && runtime.runtimeSourceKind != "runtime") [
    "NODE: runtime persistente do host nao foi encontrado em ${runtime.runtimeRoot}; avaliacao usando ${runtime.runtimeSourceKind} do repositorio."
  ];
}
