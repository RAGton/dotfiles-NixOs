{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./schema.nix
    ./removed-options.nix
    ./registry.nix
    ./network.nix
    ./desktop.nix
    ./development.nix
    ./virtualization.nix
    ./gaming.nix
    ./server.nix
    ./ai.nix
    ./storage.nix
    ./security.nix
    ./remote.nix
    ./observability.nix
    ./mcp.nix
    ./browser-automation.nix
    ./etcher.nix
    ./ntfs.nix
  ];

  environment.etc."kryonix/features.json".text = builtins.toJSON {
    features = (builtins.removeAttrs config.kryonix.features [ "cpu" "openrgb" "remoteDesktop" ]) // {
      ai = builtins.removeAttrs config.kryonix.features.ai [ "codex" "brain" ];
      gpu = config.kryonix.features.gpu // {
        intel = builtins.removeAttrs config.kryonix.features.gpu.intel [ "legacyVaapi" ];
      };
      development = config.kryonix.features.development // {
        editors = builtins.removeAttrs config.kryonix.features.development.editors [ "vscode" ];
      };
    };
  };
}
