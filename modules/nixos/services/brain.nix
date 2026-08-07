# =============================================================================
# Módulo: kryonix.services.brain
#
# O que é:
# - Configura Ollama + Brain API + LightRAG como serviços no Glacier.
# - Separação explícita: server (hospeda) vs client (acessa remoto).
#
# Por quê:
# - Ollama sem autostart preserva VRAM para gaming.
# - keep_alive=0 descarrega o modelo imediatamente após uso.
# - kryonix-lightrag aquece o índice antes da Brain API subir.
# - Firewall por interface: apenas LAN e Tailscale (tailscale0).
#
# Riscos:
# - EnvironmentFile com KRYONIX_BRAIN_API_KEY deve existir antes do switch.
#   Criar com: kryonix brain api-key generate
# - packageDir aponta para /etc/kryonix/packages/... (requer repo instalado).
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.kryonix.services.brain;
  runtimeLibPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
    pkgs.libffi
    pkgs.openssl
  ];

  # Script de verificação de VRAM antes de iniciar o Ollama.
  # Protege a RTX 4060 (8 GB) contra OOM ao subir modelos no Glacier.
  vramCheckScript = pkgs.writeShellScript "ollama-vram-check" ''
    set -euo pipefail

    PROFILE="${cfg.vram.profile}"
    REQUIRED_MIB=${toString cfg.vram.minFreeMiB.${cfg.vram.profile}}
    WARN_ONLY=${if cfg.vram.warnOnly then "1" else "0"}

    echo "Kryonix VRAM Check | Perfil: $PROFILE | Mínimo: ''${REQUIRED_MIB}MiB" >&2

    if [ "$PROFILE" = "gaming" ] && [ "${
      if cfg.vram.allowOllamaStopInGaming then "1" else "0"
    }" = "1" ]; then
      echo "PERFIL: gaming — Parando Ollama para liberar GPU total." >&2
      exit 1
    fi

    NVIDIA_SMI="/run/current-system/sw/bin/nvidia-smi"
    if [ ! -x "$NVIDIA_SMI" ]; then
      echo "WARN: nvidia-smi não encontrado, pulando verificação de VRAM" >&2
      exit 0
    fi

    # Coleta VRAM livre e processo mais guloso
    VRAM_FREE=$("$NVIDIA_SMI" --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' \r' || echo "")
    TOP_PROC=$("$NVIDIA_SMI" --query-compute-apps=process_name,used_memory --format=csv,noheader,nounits 2>/dev/null | sort -k2 -rn | head -1 || echo "N/A,0")

    if [ -z "$VRAM_FREE" ] || ! printf '%s' "$VRAM_FREE" | grep -qE '^[0-9]+$'; then
      echo "WARN: Não foi possível ler VRAM (GPU indisponível?), continuando" >&2
      exit 0
    fi

    if [ "$VRAM_FREE" -lt "$REQUIRED_MIB" ]; then
      MSG="ERRO: VRAM insuficiente: ''${VRAM_FREE}MiB livres, ''${REQUIRED_MIB}MiB necessários para perfil $PROFILE."
      echo "$MSG" >&2
      echo "Maior consumidor atual: $TOP_PROC" >&2
      echo "DICA: kryonix brain vram-audit" >&2
      
      if [ "$WARN_ONLY" = "1" ]; then
        echo "WARN: Prosseguindo mesmo assim (warnOnly=true)..." >&2
        exit 0
      else
        exit 1
      fi
    fi

    echo "VRAM OK: ''${VRAM_FREE}MiB livres (perfil: $PROFILE)"
  '';

  # Script de warmup do índice LightRAG.
  # Valida GraphML + aquece VDB antes da Brain API subir.
  lightragWarmupScript = pkgs.writeShellScript "kryonix-lightrag-warmup" ''
    set -euo pipefail
    echo "kryonix-lightrag: iniciando warmup do índice LightRAG..."
    cd "${cfg.packageDir}"
    export LD_LIBRARY_PATH="${runtimeLibPath}:''${LD_LIBRARY_PATH:-}"
    ${pkgs.uv}/bin/uv run python - <<'PYEOF'
    import asyncio, sys

    async def warmup():
        try:
            from kryonix_brain_lightrag import rag
            print("LightRAG: inicializando storages...")
            await rag.get_rag_async()
            print("LightRAG: validando graph...")
            info = await rag.stats()
            status = info.get("consistency_status", "UNKNOWN")
            entities = info.get("entities", 0)
            relations = info.get("relations", 0)
            print(f"LightRAG: {entities} entities, {relations} relations, status={status}")
            err_msg = info.get("error", "Unknown")
            print(f"WARN: LightRAG status={status}: {err_msg}", file=sys.stderr)
        except Exception as e:
            print(f"ERRO no warmup LightRAG: {e}", file=sys.stderr)
            sys.exit(1)

    asyncio.run(warmup())
    PYEOF
    echo "kryonix-lightrag: warmup concluído."
  '';

  # Script de start da Brain API via uv run (sem instalar no Nix store).
  brainApiStartScript = pkgs.writeShellScript "kryonix-brain-api-start" ''
    set -euo pipefail
    cd "${cfg.packageDir}"
    export LD_LIBRARY_PATH="${runtimeLibPath}:''${LD_LIBRARY_PATH:-}"
    exec ${pkgs.uv}/bin/uv run python -m kryonix_brain_lightrag.api
  '';

in
{
  options.kryonix.services.brain = {
    enable = mkEnableOption "Kryonix Brain AI services";

    role = mkOption {
      type = types.enum [
        "server"
        "client"
      ];
      default = "client";
      description = "Papel do host: server hospeda Ollama/LightRAG; client acessa remoto.";
    };

    serverHost = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "IP/Host do servidor Brain (usado pelo client).";
    };

    bindHost = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "IP/Host de escuta (bind) do servidor Brain (apenas server).";
    };

    port = mkOption {
      type = types.port;
      default = 8000;
      description = "Porta da Brain API (FastAPI HTTP).";
    };

    environmentFile = mkOption {
      type = types.str;
      default = "/etc/kryonix/brain.env";
      description = ''
        Arquivo de variáveis de ambiente para Brain API e LightRAG.
        Deve conter KRYONIX_BRAIN_API_KEY e variáveis LIGHTRAG_*.
        NUNCA versionar este arquivo — contém secrets.
        Criar com: kryonix brain api-key generate
      '';
    };

    neo4jEnvironmentFile = mkOption {
      type = types.str;
      default = "/etc/kryonix/neo4j.env";
      description = ''
        Arquivo privado com credenciais do Neo4j (ex.: NEO4J_AUTH=neo4j/<senha>).
        Lido pelo systemd como root e injetado no ambiente do serviço da Brain API.
      '';
    };

    repoPath = mkOption {
      type = types.str;
      default = "/etc/kryonix";
      description = "Caminho raiz do repositório Kryonix.";
    };

    packageDir = mkOption {
      type = types.str;
      default = "/etc/kryonix/packages/kryonix-brain-lightrag";
      description = "Diretório do pacote Python kryonix-brain-lightrag (usado pelo uv run).";
    };

    ollamaAutoStart = mkOption {
      type = types.bool;
      default = false;
      description = "Habilita o daemon do Ollama no boot.";
    };

    modelWarmupOnBoot = mkOption {
      type = types.bool;
      default = false;
      description = "Se true, faz o warmup do LightRAG (o que carrega os modelos no Ollama) no boot.";
    };

    ollama = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Habilita o servidor Ollama localmente.";
      };

      # Workaround: default não pode referenciar cfg.role aqui por avaliação lazy.
      # Hosts server devem setar ollama.enable = true explicitamente.

      model = mkOption {
        type = types.str;
        default = "qwen2.5-coder:7b";
        description = "Modelo padrão para o Ollama (referência para kryonix ollama run e VRAM check).";
      };

      keepAlive = mkOption {
        type = types.str;
        default = "0";
        description = ''
          Tempo de keep-alive do modelo em VRAM após inatividade.
          "0" = descarrega imediatamente após query (recomendado para Glacier gamer).
          "5m" = mantém por 5 minutos.
        '';
      };

      acceleration = mkOption {
        type = types.nullOr (
          types.enum [
            "cuda"
            "rocm"
          ]
        );
        default = "cuda";
        description = ''
          Aceleração de hardware para o Ollama.
          Mapeia para o pacote correto: cuda→ollama-cuda, rocm→ollama-rocm, null→ollama.
        '';
      };
    };

    llmProvider = mkOption {
      type = types.enum [
        "ollama"
        "llama_cpp"
        "auto"
      ];
      default = "ollama";
      description = "Provider de LLM principal: ollama, llama_cpp ou auto (fallback).";
    };

    llamaCppUrl = mkOption {
      type = types.str;
      default = "http://127.0.0.1:11435";
      description = "URL do servidor llama.cpp sidecar.";
    };

    ollamaUrl = mkOption {
      type = types.str;
      default = "http://127.0.0.1:11434";
      description = "URL do servidor Ollama.";
    };

    llamaCppTimeoutSeconds = mkOption {
      type = types.ints.positive;
      default = 60;
      description = "Timeout em segundos para o llama.cpp.";
    };

    vram = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Habilita a gestão de VRAM e perfis de IA/Gaming.";
      };

      profile = mkOption {
        type = types.enum [
          "ai"
          "balanced"
          "gaming"
        ];
        default = "balanced";
        description = "Perfil ativo: ai (exige VRAM alta), balanced (normal), gaming (prioriza GPU).";
      };

      minFreeMiB = mkOption {
        type = types.attrsOf types.ints.positive;
        default = {
          ai = 4096;
          balanced = 2048;
          gaming = 512;
        };
        description = "Mínimo de VRAM livre (MiB) exigido por perfil para o Ollama subir.";
      };

      allowGraphicalSessionStop = mkOption {
        type = types.bool;
        default = false;
        description = "Permite que a CLI sugira encerramento de sessões gráficas (NUNCA automático via systemd).";
      };

      allowOllamaStopInGaming = mkOption {
        type = types.bool;
        default = true;
        description = "Se true, o perfil 'gaming' para o Ollama para liberar GPU total.";
      };

      warnOnly = mkOption {
        type = types.bool;
        default = false;
        description = "Se true, apenas loga avisos de VRAM baixa em vez de abortar o Ollama.";
      };
    };

    brainHome = mkOption {
      type = types.path;
      default = "/var/lib/kryonix/brain";
      description = "Diretório home do Brain.";
    };

    storagePath = mkOption {
      type = types.path;
      default = "/var/lib/kryonix/brain/storage";
      description = "Caminho para o storage do LightRAG (apenas server).";
    };

    vaultPath = mkOption {
      type = types.path;
      default = "/var/lib/kryonix/vault";
      description = "Caminho para o Vault Obsidian montado/local (apenas server).";
    };

    user = mkOption {
      type = types.str;
      default = "kryonix";
      description = "Usuário que executará os serviços do Brain.";
    };

    group = mkOption {
      type = types.str;
      default = "kryonix";
      description = "Grupo que executará os serviços do Brain.";
    };
  };

  config = mkIf cfg.enable {

    # ── Pacotes comuns ─────────────────────────────────────────────
    environment.systemPackages =
      with pkgs;
      [
        curl
        jq
      ]
      ++ lib.optionals (cfg.role == "server") [
        ollama-cuda
      ];

    # ── Ollama (apenas server) ─────────────────────────────────────
    # NixOS unstable removeu services.ollama.acceleration e listenAddress.
    # Usar .package e .host/.port em vez disso.
    services.ollama = mkIf cfg.ollama.enable (
      let
        ollamaPackages = {
          cuda = pkgs.ollama-cuda;
          rocm = pkgs.ollama-rocm;
        };
      in
      {
        enable = true;
        package =
          if cfg.ollama.acceleration != null && builtins.hasAttr cfg.ollama.acceleration ollamaPackages then
            ollamaPackages.${cfg.ollama.acceleration}
          else
            pkgs.ollama;
        host = "0.0.0.0";
        port = 11434;
        user = "ollama";
        group = "ollama";
        modelsDir = "/var/lib/kryonix/ollama/models";
        # keep_alive=0: modelo descarregado da VRAM imediatamente após uso.
        # Crítico para liberar GPU quando Ollama para (kryonix ollama stop).
        environmentVariables = {
          OLLAMA_KEEP_ALIVE = cfg.ollama.keepAlive;
        };
      }
    );

    # Sem autostart: wantedBy vazio = Ollama não sobe no boot.
    # Start manual: kryonix ollama start  →  systemctl start ollama
    systemd.services.ollama = mkIf cfg.ollama.enable {
      wantedBy = mkForce (if cfg.ollamaAutoStart then [ "multi-user.target" ] else [ ]);
      serviceConfig = {
        ProtectHome = lib.mkForce "read-only";
      };
    };

    # ── VRAM check (oneshot antes do ollama) ───────────────────────
    # Roda apenas quando ollama.service é iniciado manualmente.
    # Aborta se VRAM livre < vramMinGiB * 1024 MiB.
    systemd.services.ollama-vram-check = mkIf cfg.ollama.enable {
      description = "Verifica VRAM disponível antes de iniciar o Ollama";
      before = [ "ollama.service" ];
      requiredBy = [ "ollama.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = vramCheckScript;
        RemainAfterExit = false;
      };
    };

    # ── kryonix-lightrag (warmup oneshot) ──────────────────────────
    # Valida storage + aquece VDB antes da Brain API subir.
    # Type=oneshot + RemainAfterExit=true = considerado "up" após warmup.
    systemd.services.kryonix-lightrag = mkIf (cfg.role == "server") {
      description = "Kryonix LightRAG Index Warmup";
      after = [
        "network.target"
        "ollama.service"
      ];
      requires = [ "ollama.service" ];
      before = [ "kryonix-brain-api.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        LD_LIBRARY_PATH = runtimeLibPath;
        KRYONIX_BRAIN_HOME = "/var/lib/kryonix";
        LIGHTRAG_VAULT_DIR = "${cfg.vaultPath}";
        LIGHTRAG_WORKING_DIR = "${cfg.storagePath}";
        UV_PROJECT_ENVIRONMENT = "${cfg.brainHome}/.venv";
        KRYONIX_LLM_PROVIDER = cfg.llmProvider;
        KRYONIX_LLAMA_CPP_URL = cfg.llamaCppUrl;
        KRYONIX_OLLAMA_URL = cfg.ollamaUrl;
        KRYONIX_LLAMA_CPP_TIMEOUT_SECONDS = toString cfg.llamaCppTimeoutSeconds;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lightragWarmupScript;
        EnvironmentFile = "-${cfg.environmentFile}";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.packageDir;
      };
    };

    # ── kryonix-brain-api (FastAPI HTTP) ──────────────────────────
    # Brain API: /health, /stats, /search, /ingest/*
    # Depende de: ollama + lightrag warmup
    systemd.services.kryonix-brain-api = mkIf (cfg.role == "server") {
      description = "Kryonix Brain API Service (FastAPI HTTP :${toString cfg.port})";
      after = [
        "network.target"
        "ollama.service"
        "kryonix-lightrag.service"
      ];
      requires = [
        "ollama.service"
        "kryonix-lightrag.service"
      ];
      # wantedBy é mkForce [] no glacier/default.nix até o switch ser validado.
      # Remover o mkForce [] para que suba automaticamente após ollama+lightrag.
      wantedBy = [ "multi-user.target" ];
      environment = {
        LD_LIBRARY_PATH = runtimeLibPath;
        KRYONIX_BRAIN_HOME = "/var/lib/kryonix";
        LIGHTRAG_VAULT_DIR = "${cfg.vaultPath}";
        LIGHTRAG_WORKING_DIR = "${cfg.storagePath}";
        KRYONIX_NEO4J_URI = "bolt://127.0.0.1:7687";
        KRYONIX_NEO4J_HTTP_URL = "http://127.0.0.1:7474";
        KRYONIX_BRAIN_API_HOST = cfg.bindHost;
        KRYONIX_BRAIN_API_PORT = "${toString cfg.port}";
        UV_PROJECT_ENVIRONMENT = "${cfg.brainHome}/.venv";
        KRYONIX_LLM_PROVIDER = cfg.llmProvider;
        KRYONIX_LLAMA_CPP_URL = cfg.llamaCppUrl;
        KRYONIX_OLLAMA_URL = cfg.ollamaUrl;
        KRYONIX_LLAMA_CPP_TIMEOUT_SECONDS = toString cfg.llamaCppTimeoutSeconds;
      };
      serviceConfig = {
        ExecStart = brainApiStartScript;
        WorkingDirectory = cfg.packageDir;
        EnvironmentFile = [
          "-${cfg.environmentFile}"
          "-${cfg.neo4jEnvironmentFile}"
        ];
        Restart = "on-failure";
        RestartSec = "10";
        User = cfg.user;
        Group = cfg.group;
      };
    };

    # ── Usuário de sistema do Brain ────────────────────────────────
    users.groups.kryonix = { };
    users.users.kryonix = {
      isSystemUser = true;
      group = "kryonix";
      # users group needed: Z /var/lib/kryonix sets rocha:users 0775 recursively;
      # kryonix must be a member of users to retain write access to data dirs.
      extraGroups = [ "users" ];
      description = "Kryonix Brain Service User";
      home = "/var/lib/kryonix/brain";
      createHome = true;
      homeMode = "0770";
    };
    users.users.rocha.extraGroups = [ "kryonix" ];
    users.users.ollama.extraGroups = mkIf cfg.ollama.enable [ "kryonix" ];

    # Brain API e Ollama só acessíveis via LAN e Tailscale (tailscale0).
    # NÃO usar allowedTCPPorts (abre para todas as interfaces).
    networking.firewall.interfaces = mkIf (cfg.role == "server") {
      # Tailscale: acesso remoto Inspiron → Glacier
      tailscale0.allowedTCPPorts = [
        cfg.port # Brain API :8000
        11434 # Ollama
      ];
      # LAN (bridge virtual ou física): acesso local na rede
      "${config.kryonix.features.network.bridge.name}".allowedTCPPorts = [
        cfg.port
        11434
      ];
    };
  };
}
