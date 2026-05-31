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
    # VERSION PINS — altere aqui para mudar versões
    # ===========================================================================
    # nixpkgs (rolling/unstable)  → nixos-unstable  (sempre o mais recente)
    # nixpkgs-stable               → nixos-25.05     (última LTS estável)
    # nix-flatpak                  → v0.7.0          (última tag)
    # ===========================================================================

    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";          # rolling release
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";      # LTS estável

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Módulos de hardware do NixOS (nixos-hardware)
    hardware.url = "github:nixos/nixos-hardware";

    # Gerenciador declarativo de Flatpak
    nix-flatpak.url = "github:gmodena/nix-flatpak?ref=v0.7.0";   # pin de tag

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
      users = import ./flake/data/users.nix;
      lib = import ./flake/lib.nix { inherit inputs users; };
    in
    {
      nixosConfigurations = import ./flake/data/hosts.nix { inherit inputs lib; };
      homeConfigurations = import ./flake/home.nix { inherit inputs lib; };
      packages = import ./flake/packages.nix { inherit inputs lib; };
      devShells = import ./flake/shells.nix { inherit inputs lib; };
      formatter = import ./flake/formatter.nix { inherit inputs lib; };
      checks = import ./flake/checks.nix { inherit inputs lib; };
      overlays = import ./overlays { inherit inputs; };

      # Exports upstream
      nixosModules = (import ./flake/modules.nix { inherit self inputs; }).nixosModules;
      homeManagerModules = (import ./flake/modules.nix { inherit self inputs; }).homeManagerModules;
    };
}
