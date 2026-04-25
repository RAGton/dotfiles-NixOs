# Flake principal do repo
# Autor: rag
#
# O que é
# - Fonte única de verdade para hosts NixOS e perfis Home Manager.
# - Centraliza inputs, overlays e outputs públicos do projeto.
#
# Por quê
# - Reprodutibilidade: mesmos inputs -> mesmo resultado.
# - Portabilidade: módulos compartilhados e outputs públicos consistentes.
# - Manutenção: entradas e saídas claras num único lugar.
#
# Como
# - Inputs: nixpkgs (unstable + stable), Home Manager, hardware e integrações auxiliares.
# - Outputs: hosts NixOS, perfis Home Manager, overlays, formatter e checks.
#
# Riscos
# - Atualizar pins (nixpkgs/home-manager) pode introduzir regressões; prefira atualizar de forma incremental.
{
  description = "Kryonix: plataforma NixOS pessoal para workstation, gaming, virtualizacao, desenvolvimento e futuras ISOs.";

  # =============================
  # Inputs (flakes externos)
  # =============================
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Módulos de hardware do NixOS (nixos-hardware)
    hardware.url = "github:nixos/nixos-hardware";

    # Gerenciador declarativo de Flatpak
    nix-flatpak.url = "github:gmodena/nix-flatpak?ref=v0.6.0";

    # Nix Darwin (para máquinas macOS)
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Particionamento declarativo (usado na ISO instaladora)
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # DankMaterialShell (DMS) - Rice para Hyprland (assets/configs)
    # Repo: https://github.com/AvengeMedia/DankMaterialShell
    # Obs.: flake=false porque é um repositório de dotfiles/configs, não um flake Nix.
    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      flake = false;
    };

    # DankMaterialShell (DMS) como flake (para acessar packages/modules upstream)
    dms-flake = {
      url = "github:AvengeMedia/DankMaterialShell";
      flake = true;
    };

    # Caelestia Shell
    # Fonte padrão: GitHub pinado no lock do flake.
    # Desenvolvimento local: use `--override-input caelestia-shell path:../caelestia-shell`
    # a partir do diretório do checkout que contém este flake.
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # OpenAI Codex CLI (coding agent que roda localmente)
    codex = {
      url = "github:openai/codex";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # =============================
  # Outputs (sistemas, usuários, overlays)
  # =============================
  outputs =
    {
      self,
      home-manager,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      repoOverlays = import ./overlays { inherit inputs; };

      formatterFor = system: (import nixpkgs { inherit system; }).nixfmt;
      stripContext = builtins.unsafeDiscardStringContext;

      mkHomePkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            repoOverlays.stable-packages
            repoOverlays.atlauncher-api-user-agent-workaround
            repoOverlays.xeus-cling-no-checks
          ];
          config.allowUnfree = true;
        };

      checkPkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };

      devShellsFor =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          latexShell = pkgs.mkShell {
            packages = with pkgs; [
              texlive.combined.scheme-full
              texlivePackages.latexmk
              texlab
              biber
              texlivePackages.chktex
              ghostscript
              perl
            ];
          };
        in
        {
          default = latexShell;
          latex = latexShell;
        };

      formattingCheck =
        checkPkgs.runCommand "nixfmt-check"
          {
            nativeBuildInputs = [
              checkPkgs.findutils
              checkPkgs.nixfmt
            ];
            src = ./.;
          }
          ''
            cd "$src"
            ${checkPkgs.findutils}/bin/find . -type f -name '*.nix' -print0 \
              | ${checkPkgs.findutils}/bin/xargs -0 ${checkPkgs.nixfmt}/bin/nixfmt --check
            mkdir -p "$out"
          '';

      # =============================
      # Usuários declarados (multi-user ready)
      # =============================
      users = {
        rocha = {
          avatar = ./files/avatar/ragton.jpeg;
          email = "gabriel.rag@proton.me";
          gitKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGIlk6EkcD7aTDYYmZVr636Jo1Vz9zDqUWiwzEpBgmMY gabriel.rag@proton.me";
          gitSigningKeyPath = ".ssh/id_ed25519_git_signing";
          fullName = "Gabriel Rocha";
          name = "rocha";
        };
        nina = {
          avatar = ./files/avatar/ragton.jpeg;
          email = "nicoly.canteiro@local";
          gitKey = "";
          fullName = "Nicoly Canteiro";
          name = "nina";
        };
        # Adicione outros usuários aqui
      };

      # =============================
      # Funções helpers para sistemas e home
      # =============================
      mkNixosConfiguration =
        hostname: username:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs hostname;
            isDarwin = false;
            userConfig = users.${username};
            nixosModules = "${self}/modules/nixos";
          };
          modules = [
            ./hosts/${hostname}
            ./hosts/common
          ];
        };

      mkHomeConfiguration =
        system: username: hostname:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkHomePkgs system;
          extraSpecialArgs = {
            inherit inputs outputs;
            userConfig = users.${username};
            nhModules = "${self}/modules/home-manager";
            dmsPkgs = if inputs ? dms-flake then inputs.dms-flake.packages.${system} else { };
          };
          modules = [ ./home/${username}/${hostname} ];
        };

    in
    {
      # =============================
      # Sistemas NixOS (multi-host)
      # =============================
      nixosConfigurations = {
        inspiron = mkNixosConfiguration "inspiron" "rocha";
        inspiron-nina = mkNixosConfiguration "inspiron-nina" "nina";
        glacier = mkNixosConfiguration "glacier" "rocha";
        iso = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs outputs;
            hostname = "iso";
            isDarwin = false;
            nixosModules = "${self}/modules/nixos";
          };
          modules = [ ./hosts/iso ];
        };
      };

      # =============================
      # Home Manager (multi-user, multi-host)
      # =============================
      homeConfigurations = {
        "rocha@inspiron" =
          let
            cfg = mkHomeConfiguration "x86_64-linux" "rocha" "inspiron";
          in
          cfg // { type = "homeManagerConfiguration"; };
        "rocha@glacier" =
          let
            cfg = mkHomeConfiguration "x86_64-linux" "rocha" "glacier";
          in
          cfg // { type = "homeManagerConfiguration"; };
        "nina@inspiron-nina" =
          let
            cfg = mkHomeConfiguration "x86_64-linux" "nina" "inspiron-nina";
          in
          cfg // { type = "homeManagerConfiguration"; };
        # Adicione outros usuários/hosts aqui
      };

      formatter = forAllSystems formatterFor;
      devShells = forAllSystems devShellsFor;
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        rec {
          kryonix = import ./packages/kryonix-cli.nix { inherit pkgs; };
          default = kryonix;
        }
      );

      checks.x86_64-linux = {
        formatting = formattingCheck;
        "nixos-inspiron-eval" =
          checkPkgs.writeText "nixos-inspiron-drvpath" "${stripContext self.nixosConfigurations.inspiron.config.system.build.toplevel.drvPath}\n";
        "nixos-inspiron-nina-eval" =
          checkPkgs.writeText "nixos-inspiron-nina-drvpath" "${stripContext self.nixosConfigurations.inspiron-nina.config.system.build.toplevel.drvPath}\n";
        "nixos-glacier-eval" =
          checkPkgs.writeText "nixos-glacier-drvpath" "${stripContext self.nixosConfigurations.glacier.config.system.build.toplevel.drvPath}\n";
        "nixos-iso-eval" =
          checkPkgs.writeText "nixos-iso-drvpath" "${stripContext self.nixosConfigurations.iso.config.system.build.toplevel.drvPath}\n";
        "home-rocha-inspiron-eval" = checkPkgs.writeText "home-rocha-inspiron-drvpath" "${
          stripContext self.homeConfigurations."rocha@inspiron".activationPackage.drvPath
        }\n";
        "home-rocha-glacier-eval" = checkPkgs.writeText "home-rocha-glacier-drvpath" "${
          stripContext self.homeConfigurations."rocha@glacier".activationPackage.drvPath
        }\n";
        "home-nina-inspiron-nina-eval" = checkPkgs.writeText "home-nina-inspiron-nina-drvpath" "${
          stripContext self.homeConfigurations."nina@inspiron-nina".activationPackage.drvPath
        }\n";
      };

      # =============================
      # Overlays (modular, multi-overlay)
      # =============================
      overlays = repoOverlays;
    };
}
