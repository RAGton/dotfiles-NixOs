{ lib, ... }:

{
  imports = [
    (lib.mkRemovedOptionModule [ "kryonix" "features" "cpu" "intel" "enable" ]
      "Use native host hardware modules for now. The canonical gpu/cpu feature tree is not fully implemented yet."
    )

    (lib.mkRemovedOptionModule [ "kryonix" "features" "cpu" "amd" "enable" ]
      "Use native host hardware modules for now. The canonical gpu/cpu feature tree is not fully implemented yet."
    )

    (lib.mkRemovedOptionModule [ "kryonix" "features" "openrgb" "enable" ]
      "OpenRGB is not available in the canonical feature tree. Move this to a dedicated host/profile module if still needed."
    )

    (lib.mkRemovedOptionModule [ "kryonix" "features" "ai" "codex" "enable" ]
      "Codex is not available in the canonical feature tree. Remove this option or implement a real feature module first."
    )

    (lib.mkRemovedOptionModule [ "kryonix" "features" "remoteDesktop" "client" "enable" ]
      "Use kryonix.features.remote.desktop.client.enable when it has a real implementation. Do not use the legacy remoteDesktop namespace."
    )

    (lib.mkRemovedOptionModule [ "kryonix" "features" "remoteDesktop" "server" "enable" ]
      "Use kryonix.features.remote.desktop.server.enable when it has a real implementation. Do not use the legacy remoteDesktop namespace."
    )

    (lib.mkRemovedOptionModule [ "kryonix" "features" "ai" "brain" "enable" ]
      "Use kryonix.features.ai.brain.client.enable or kryonix.features.ai.brain.server.enable only after those modules have runtime implementation."
    )

    (lib.mkRemovedOptionModule [ "kryonix" "features" "ai" "brain" "role" ]
      "The old ai.brain.role option was removed. Use explicit client/server feature modules after implementation."
    )

    (lib.mkRemovedOptionModule [ "kryonix" "features" "ai" "brain" "serverHost" ]
      "The old ai.brain.serverHost option was removed. Do not set endpoint options until a real Brain client module consumes them."
    )

    (lib.mkRemovedOptionModule [ "kryonix" "features" "gpu" "intel" "legacyVaapi" "enable" ]
      "legacyVaapi was removed. Configure Intel VAAPI through the host hardware module or implement gpu.intel properly first."
    )
  ];
}
