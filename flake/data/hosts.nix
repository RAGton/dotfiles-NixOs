{ inputs, lib }:
{
  iso = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      outputs = inputs.self.outputs;
      hostname = "iso";
      isDarwin = false;
      offlineMode = false;
      nixosModules = "${inputs.self}/modules/nixos";
    };
    modules = [ ../../hosts/iso ];
  };

  iso-e2e = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      outputs = inputs.self.outputs;
      hostname = "iso";
      isDarwin = false;
      offlineMode = false;
      nixosModules = "${inputs.self}/modules/nixos";
    };
    modules = [
      ../../hosts/iso
      ({ lib, ... }: {
        # E2E Remote API override: binds to 0.0.0.0 for external testing
        kryonix.installer.kiosk.listenAddress = lib.mkForce "0.0.0.0";
        systemd.services.kryonix-installer-backend.environment = {
          KRYONIX_ALLOW_REMOTE_BIND = "1";
        };
      })
    ];
  };
}
