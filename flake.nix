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
    # nixpkgs          → nixos-unstable (latest stable, KDE 6.2.x+)
    # nixpkgs-stable   → nixos-26.05  (branch estável para referências)
    # home-manager     → master (latest, alinhado com nixos-unstable)
    # ===========================================================================

    # Nixpkgs — unstable (latest, KDE mais novo)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    # Home Manager — master alinha com nixos-unstable
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Plasma Manager — configuração declarativa do KDE Plasma 6 (Home Manager)
    # Usado pelo módulo de desktop "kde" (homeManagerModules.kde).
    plasma-manager = {
      url = "github:AlexNabokikh/plasma-manager/trunk";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # macOS Tahoe Liquid Theme — pacote externo opt-in (v0.47.2 LTS)
    # Empacotado por packages/macos-tahoe-liquid.nix (derivação Kryonix).
    # Ativado apenas quando kryonix.desktop.kde.theme.preset = "tahoe-liquid".
    # NÃO é parte da stack padrão (opt-in por design).
    macos-tahoe-liquid-kde = {
      url = "github:lestercorderomurillo/macos-tahoe-liquid-kde/v0.47.2";
      flake = false;
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
    # binário via overlay `kryxd-tools`.
    # Usa git+https em vez do shorthand `github:` para não depender da API
    # REST do GitHub (que apresentou 504 intermitente logo após o repo
    # virar público); o protocolo git é mais robusto e o lock pina o rev.
    # Migrado de `git+file:///home/rocha/kryonix-dev/repos/kryxd` para
    # `git+https://github.com/RAGton/kryxd.git`: a amarração a path local
    # quebra portabilidade entre hosts e autodestrói o rebuild se o
    # workspace for movido. SSOT remoto via clone git, mesmo protocolo
    # usado em `kryx-cli`/`kryonix-assets` (git+ vs API REST).
    # Pinned em `v0.2.2` (tag semver) para garantir `nix flake update` traz
    # sempre o kryxd com capability-driven UI consolidada (PR #12 + AGENTS.md
    # skill ref do V25a) + capability `virtualization.incus` (P1/V58b).
    # Historico:
    #   v0.2.0 (c544d41) = release de codigo com P1
    #   v0.2.1 (75b24a6) = bump manifestos (Cargo.toml + ui/package.json)
    #   v0.2.2 (efd57ba) = fix package.nix version hardcoded
    # Sem v0.2.2, buildRustPackage gera derivacao kryxd-0.1.0 fantasma.
    # Refs: V36b, V58b, V66b, V69a.
    # Sintaxe `refs/tags/` explicita porque o formato `git+https://`
    # assume `refs/heads/` por padrao (V37a).
    kryxd = {
      url = "git+https://github.com/RAGton/kryxd.git?ref=refs/tags/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Novo CLI em Rust (standalone)
    # Pinned em `v0.2.0` (tag semver) para garantir que `nix flake update`
    # sempre traga o kryx-cli COM o bypass de lockdown (`discover_real_nix_dir`
    # em `modules.rs`) + subcomando `check` para flake validation (t_aa0e609b,
    # commit 9284336), nunca revertendo para o rev pré-fix `5ab75997`
    # (que tem o problema do chicken-and-egg com o cli-lockdown wrapper).
    # Refs: V22b (semver), V34a (kryx-cli semver stabilization), V36b (check).
    kryx-cli = {
      url = "github:RAGton/kryx-cli/v0.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Kryonix Assets (SSOT visual: logos, wallpapers, sddm themes)
    # Migrado de `git+file:///home/rocha/kryonix-dev/repos/kryonix-assets`
    # para `git+https://github.com/RAGton/kryonix-assets.git`: mesma
    # justificativa de `kryxd` acima (portabilidade entre hosts + git
    # puro vs API REST). Coordenada com `kryxd` no mesmo commit.
    # Pinned em `v0.1.0` tag semver (V36b). Sintaxe `refs/tags/`
    # explicita porque `git+https://` assume `refs/heads/` (V37a).
    kryonix-assets = {
      url = "git+https://github.com/RAGton/kryonix-assets.git?ref=refs/tags/v0.1.0";
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
          kryxd-tools
          kryonix-themes
          ;
      };
    };
}
