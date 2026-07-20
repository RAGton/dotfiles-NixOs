# Flake principal do repo
# Autor: Gabriel Aguiar Rocha (RAGton)
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

  nixConfig = {
    extra-substituters = [ "https://kryonix.cachix.org" ];
    extra-trusted-public-keys = [ "kryonix.cachix.org-1:xZvvORDyajjx/DFv20/LQxNejZgJucRLbIsyFlmCmSk=" ];
  };

  # =============================
  # Inputs (flakes externos)
  # =============================
  inputs = {
    # ===========================================================================
    # VERSION PINS — tudo fixo em 26.05 estável
    # ===========================================================================
    # nixpkgs          → nixos-26.05  (release estável maio 2026)
    # nixpkgs-stable   → nixos-26.05  (mesma branch — sem divergência)
    # home-manager     → release-26.05 (alinhado com nixpkgs)
    # ===========================================================================

    # Nixpkgs — estável 26.05
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    # Home Manager — release-26.05 alinha com nixpkgs
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Plasma Manager — configuração declarativa do KDE Plasma 6 (Home Manager)
    # Usado pelo módulo de desktop "kde" (homeManagerModules.kde).
    plasma-manager = {
      url = "github:AlexNabokikh/plasma-manager/trunk";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Módulos de hardware do NixOS (nixos-hardware)
    hardware.url = "github:nixos/nixos-hardware";

    # Gerenciador declarativo de Flatpak
    nix-flatpak.url = "github:gmodena/nix-flatpak?ref=v0.7.0"; # pin de tag

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

    # Google Antigravity (pacote Nix mantido em repositório externo)
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
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

    # Hermes Agent (Nous Research)
    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v2026.7.7.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Kryonix Home Brain (scanner determinístico)
    kryonix-home = {
      url = "github:RAGton/KRYONIX-HOME";
      flake = false;
    };

    # Kryonix Brain LightRAG (RAG engine)
    # Fonte pinada no lock do flake.
    kryonix-brain-lightrag = {
      url = "github:RAGEnterprise/kryonix-brain-lightrag";
      flake = false;
    };

    # Kryonix Installer — backend Axum (Rust) + web UI (Vite/React).
    # Repo standalone: o source vive fora do motor para não vazar para o
    # sistema instalado (ver target_tree.rs). Consumido aqui apenas como
    # binário via overlay `kryonix-installer-tools`.
    # Usa git+https em vez do shorthand `github:` para não depender da API
    # REST do GitHub (que apresentou 504 intermitente logo após o repo
    # virar público); o protocolo git é mais robusto e o lock pina o rev.
    kryonix-installer = {
      url = "git+https://github.com/RAGton/kryonix-installer";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Kernel CachyOS de terceiros (zfs e LTO alinhados)
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel";
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
      # Sem usuários pessoais no upstream; downstream traz os seus próprios via kryonix.lib.mkLib
      lib = import ./flake/lib.nix {
        inherit inputs;
        users = { };
      };
    in
    {
      nixosConfigurations = import ./flake/data/hosts.nix { inherit inputs lib; };
      packages = import ./flake/packages.nix { inherit inputs lib; };
      devShells = import ./flake/shells.nix { inherit inputs lib; };
      formatter = import ./flake/formatter.nix { inherit inputs lib; };
      checks = import ./flake/checks.nix { inherit inputs lib; };
      overlays = import ./overlays { inherit inputs; };

      # Exports upstream — consumíveis por repositórios downstream
      nixosModules = (import ./flake/modules.nix { inherit self inputs; }).nixosModules;
      homeManagerModules = (import ./flake/modules.nix { inherit self inputs; }).homeManagerModules;

      # lib: factory para criar configurações downstream
      # Uso: kryonix.lib.mkLib { inherit inputs; users = ./meus-users.nix; }
      lib = {
        mkLib = { inputs, users }: import ./flake/lib.nix { inherit inputs users; };

        # Overlays prontos para uso em nixpkgs.overlays
        inherit (import ./overlays { inherit inputs; })
          stable-packages
          atlauncher-api-user-agent-workaround
          xeus-cling-no-checks
          codex-overlay
          kryonix-installer-tools
          kryonix-themes
          ;
      };
    };
}
