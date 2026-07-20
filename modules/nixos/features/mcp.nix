{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.features.mcp;

  commonSandboxArgs = ''
    sandbox_args=(
      --die-with-parent
      --new-session
      --unshare-all
      --clearenv
      --ro-bind /nix/store /nix/store
      --proc /proc
      --dev /dev
      --tmpfs /tmp
      --dir /tmp/home
      --setenv HOME /tmp/home
      --setenv XDG_CACHE_HOME /tmp/cache
      --setenv LANG C.UTF-8
    )

    declare -A sandbox_dirs=()
    add_parent_dirs() {
      local path="$1"
      local parent current part
      parent="$(dirname "$path")"
      current=""
      IFS='/' read -r -a parts <<< "''${parent#/}"
      for part in "''${parts[@]}"; do
        [ -n "$part" ] || continue
        current="$current/$part"
        if [ -z "''${sandbox_dirs[$current]+present}" ]; then
          sandbox_args+=(--dir "$current")
          sandbox_dirs[$current]=1
        fi
      done
    }
  '';

  filesystemRoots = map lib.escapeShellArg cfg.filesystem.roots;
  filesystemWrapper = pkgs.writeShellApplication {
    name = "kryonix-mcp-filesystem-readonly";
    runtimeInputs = [
      pkgs.bubblewrap
      pkgs.coreutils
    ];
    text = ''
      ${commonSandboxArgs}

      roots=(${lib.concatStringsSep " " filesystemRoots})
      for root in "''${roots[@]}"; do
        if [ ! -d "$root" ]; then
          echo "kryonix-mcp-filesystem-readonly: raiz ausente: $root" >&2
          exit 66
        fi
        add_parent_dirs "$root"
        sandbox_args+=(--ro-bind "$root" "$root")
      done

      exec ${lib.getExe pkgs.bubblewrap} "''${sandbox_args[@]}" \
        --setenv PATH ${lib.escapeShellArg (lib.makeBinPath [ pkgs.mcp-server-filesystem ])} \
        ${lib.getExe pkgs.mcp-server-filesystem} "''${roots[@]}"
    '';
  };

  gitRepositories = map lib.escapeShellArg cfg.git.repositories;
  gitWrapper = pkgs.writeShellApplication {
    name = "kryonix-mcp-git-readonly";
    runtimeInputs = [
      pkgs.bubblewrap
      pkgs.coreutils
      pkgs.gitMinimal
    ];
    text = ''
      if [ "$#" -ne 1 ]; then
        echo "uso: kryonix-mcp-git-readonly /caminho/absoluto/do/repo" >&2
        exit 64
      fi

      requested="$(realpath -e "$1")" || exit 66
      allowed=0
      repositories=(${lib.concatStringsSep " " gitRepositories})
      for repository in "''${repositories[@]}"; do
        if [ -d "$repository" ] && [ "$requested" = "$(realpath -e "$repository")" ]; then
          allowed=1
          break
        fi
      done

      if [ "$allowed" -ne 1 ]; then
        echo "kryonix-mcp-git-readonly: repositório fora da allowlist: $requested" >&2
        exit 77
      fi

      git_dir="$(${lib.getExe pkgs.gitMinimal} -C "$requested" rev-parse --absolute-git-dir)" || {
        echo "kryonix-mcp-git-readonly: caminho não é um repositório Git: $requested" >&2
        exit 65
      }
      common_dir="$(${lib.getExe pkgs.gitMinimal} -C "$requested" rev-parse --git-common-dir)"
      if [[ "$common_dir" != /* ]]; then
        common_dir="$(realpath -e "$requested/$common_dir")" || exit 66
      else
        common_dir="$(realpath -e "$common_dir")" || exit 66
      fi

      ${commonSandboxArgs}
      add_parent_dirs "$requested"
      sandbox_args+=(--ro-bind "$requested" "$requested")
      for metadata_dir in "$git_dir" "$common_dir"; do
        case "$metadata_dir" in
          "$requested"|"$requested"/*) ;;
          *)
            add_parent_dirs "$metadata_dir"
            sandbox_args+=(--ro-bind "$metadata_dir" "$metadata_dir")
            ;;
        esac
      done

      exec ${lib.getExe pkgs.bubblewrap} "''${sandbox_args[@]}" \
        --setenv PATH ${lib.escapeShellArg (lib.makeBinPath [ pkgs.mcp-server-git ])} \
        ${lib.getExe pkgs.mcp-server-git} --repository "$requested"
    '';
  };

  sequentialThinkingWrapper = pkgs.writeShellApplication {
    name = "kryonix-mcp-sequential-thinking";
    runtimeInputs = [ pkgs.bubblewrap ];
    text = ''
      sandbox_args=(
        --die-with-parent
        --new-session
        --unshare-all
        --clearenv
        --ro-bind /nix/store /nix/store
        --proc /proc
        --dev /dev
        --tmpfs /tmp
        --dir /tmp/home
        --setenv HOME /tmp/home
        --setenv XDG_CACHE_HOME /tmp/cache
        --setenv LANG C.UTF-8
        --setenv DISABLE_THOUGHT_LOGGING true
        --setenv PATH ${lib.escapeShellArg (lib.makeBinPath [ pkgs.mcp-server-sequential-thinking ])}
      )

      exec ${lib.getExe pkgs.bubblewrap} "''${sandbox_args[@]}" \
        ${lib.getExe pkgs.mcp-server-sequential-thinking}
    '';
  };

  nixosDocsWrapper = pkgs.writeShellApplication {
    name = "kryonix-mcp-nixos";
    runtimeInputs = [ pkgs.bubblewrap ];
    text = ''
      sandbox_args=(
        --die-with-parent
        --new-session
        --unshare-all
        --share-net
        --clearenv
        --ro-bind /nix/store /nix/store
        --proc /proc
        --dev /dev
        --tmpfs /tmp
        --dir /tmp/home
        --setenv HOME /tmp/home
        --setenv XDG_CACHE_HOME /tmp/cache
        --setenv LANG C.UTF-8
        --setenv SSL_CERT_FILE ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        --setenv PATH ${lib.escapeShellArg (lib.makeBinPath [ pkgs.mcp-nixos ])}
      )

      exec ${lib.getExe pkgs.bubblewrap} "''${sandbox_args[@]}" \
        ${lib.getExe pkgs.mcp-nixos}
    '';
  };

  absoluteSafePath = path: lib.hasPrefix "/" path && path != "/";
in
{
  options.kryonix.features.mcp = {
    filesystem = {
      enable = lib.mkEnableOption "MCP de filesystem isolado e efetivamente read-only";
      roots = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "/home/rocha/kryonix/kryonix-dev/repos/kryonix"
          "/home/rocha/kryonix/kryonix-dev/repos/kryonix-vault"
        ];
        description = ''
          Diretórios absolutos expostos ao servidor em mounts read-only. O
          wrapper bloqueia escrita no kernel mesmo que o servidor upstream
          anuncie ferramentas mutantes.
        '';
      };
    };

    git = {
      enable = lib.mkEnableOption "MCP Git isolado com repositórios montados read-only";
      repositories = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "/home/rocha/kryonix/kryonix-dev/repos/kryonix" ];
        description = ''
          Allowlist de repositórios absolutos aceitos pelo dispatcher
          kryonix-mcp-git-readonly. Cada execução enxerga somente o repositório
          selecionado, /nix/store e diretórios temporários efêmeros.
        '';
      };
    };

    sequentialThinking.enable = lib.mkEnableOption "MCP sequential-thinking isolado, sem rede e sem acesso ao host";

    nixos.enable = lib.mkEnableOption "MCP de documentação NixOS isolado, com rede e sem acesso ao host";

    # Mantidos para compatibilidade com o catálogo existente. Continuam sem
    # implementação até existir um contrato seguro e validado para cada um.
    github.enable = lib.mkEnableOption "GitHub MCP integration";
    neo4j.enable = lib.mkEnableOption "Neo4j MCP integration";
    ollama.enable = lib.mkEnableOption "Ollama MCP integration";
  };

  config = {
    assertions = [
      {
        assertion = !cfg.filesystem.enable || cfg.filesystem.roots != [ ];
        message = "kryonix.features.mcp.filesystem.roots não pode ser vazio quando habilitado";
      }
      {
        assertion = lib.all absoluteSafePath cfg.filesystem.roots;
        message = "raízes do MCP filesystem devem ser absolutas e não podem ser /";
      }
      {
        assertion = !cfg.git.enable || cfg.git.repositories != [ ];
        message = "kryonix.features.mcp.git.repositories não pode ser vazio quando habilitado";
      }
      {
        assertion = lib.all absoluteSafePath cfg.git.repositories;
        message = "repositórios do MCP Git devem ser absolutos e não podem ser /";
      }
    ];

    warnings = lib.optional cfg.github.enable ''
      kryonix.features.mcp.github.enable ainda não possui implementação segura;
      nenhum servidor GitHub foi instalado.
    '';

    environment.systemPackages =
      lib.optional cfg.filesystem.enable filesystemWrapper
      ++ lib.optional cfg.git.enable gitWrapper
      ++ lib.optional cfg.sequentialThinking.enable sequentialThinkingWrapper
      ++ lib.optional cfg.nixos.enable nixosDocsWrapper;
  };
}
