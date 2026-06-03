# =============================================================================
# Módulo: kryonix.services.hermes
#
# O que é:
# - Instala o Hermes Agent (NousResearch) de forma DECLARATIVA num NixOS,
#   sem o instalador imperativo (curl|bash + apt/pip-node/symlinks).
# - Fonte pinada via input de flake (inputs.hermes-agent); deps Python
#   resolvidas por `uv` num venv gravável no stateDir (mesmo padrão do brain.nix).
#
# Por quê:
# - O instalador upstream baixa node pré-compilado e usa apt/dnf/pacman — nada
#   disso funciona/roda em NixOS e deixa estado fora de geração. Aqui tudo é
#   reproduzível e reversível por geração.
#
# Modelo distribuído:
# - role = "server" (glacier): habilita o serviço systemd do gateway (mensageria),
#   além do comando `hermes`.
# - role = "client" (inspiron, temporário): só o comando `hermes` (TUI/CLI),
#   sem daemon no boot.
#
# Riscos:
# - O primeiro start do hermes-install.service baixa wheels do PyPI (rede).
# - browserTools (Playwright/Chromium) é pesado e pode exigir ajuste fino.
# - environmentFile (/etc/kryonix/hermes.env, gitignored, modo 600) deve conter
#   GEMINI_API_KEY/GOOGLE_API_KEY antes do switch. NUNCA versionar.
# =============================================================================
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  cfg = config.kryonix.services.hermes;

  src = inputs.hermes-agent;

  # Extras efetivos: base + ferramentas de navegador quando habilitadas.
  effectiveExtras = lib.unique (
    cfg.extras ++ lib.optionals cfg.browserTools [ "web" "computer-use" ]
  );
  extrasSpec = optionalString (effectiveExtras != [ ]) "[${concatStringsSep "," effectiveExtras}]";

  venvDir = "${cfg.stateDir}/venv";
  hermesBin = "${venvDir}/bin/hermes";

  # Libs nativas exigidas em runtime pelos wheels (pydantic-core, ruamel, etc.).
  runtimeLibPath = lib.makeLibraryPath (
    [
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
      pkgs.libffi
      pkgs.openssl
    ]
    ++ lib.optionals cfg.browserTools [
      pkgs.glib
      pkgs.nss
      pkgs.nspr
    ]
  );

  # Toolchain disponível para o `uv` (build de eventuais sdists nativos).
  buildPath = lib.makeBinPath (
    [
      pkgs.uv
      pkgs.python311
      pkgs.gcc
      pkgs.gnumake
      pkgs.pkg-config
      pkgs.git
      pkgs.cargo
      pkgs.rustc
    ]
  );

  # Programas que o agente espera encontrar no PATH em runtime.
  runtimePath = lib.makeBinPath (
    [
      pkgs.uv
      pkgs.python311
      pkgs.git
      pkgs.ripgrep
      pkgs.ffmpeg
      pkgs.nodejs_22
      pkgs.coreutils
    ]
    ++ lib.optionals cfg.browserTools [ pkgs.chromium ]
    ++ cfg.extraPackages
  );

  playwrightEnv = optionalAttrs cfg.browserTools {
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "1";
  };

  commonEnv = {
    LD_LIBRARY_PATH = runtimeLibPath;
    UV_NO_CONFIG = "1";
    # venv compartilhado e fixo: não tenta recriar por usuário.
    HERMES_AGENT_VENV = venvDir;
  }
  // playwrightEnv;

  # Instalação idempotente do venv. Marca o stamp com (src + extras); só
  # reinstala quando a fonte pinada ou os extras mudam.
  installScript = pkgs.writeShellScript "hermes-install" ''
    set -euo pipefail
    export PATH="${buildPath}:$PATH"
    export LD_LIBRARY_PATH="${runtimeLibPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export UV_NO_CONFIG=1

    STAMP="${venvDir}/.kryonix-stamp"
    WANT="${src}${extrasSpec}"

    if [ -x "${hermesBin}" ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$WANT" ]; then
      echo "hermes-install: venv já atualizado para $WANT — pulando."
      exit 0
    fi

    echo "hermes-install: (re)criando venv em ${venvDir} para $WANT"
    rm -rf "${venvDir}"
    ${pkgs.uv}/bin/uv venv --python ${pkgs.python311}/bin/python3.11 "${venvDir}"
    VIRTUAL_ENV="${venvDir}" ${pkgs.uv}/bin/uv pip install \
      --python "${venvDir}/bin/python" \
      "${src}${extrasSpec}"

    printf '%s' "$WANT" > "$STAMP"
    echo "hermes-install: concluído."
  '';

  # Wrapper `hermes` para uso interativo (TUI/CLI). Carrega secrets do
  # environmentFile quando legível e injeta provider/modelo padrão.
  hermesWrapper = pkgs.writeShellApplication {
    name = "hermes";
    excludeShellChecks = [ "SC1090" "SC1091" ];
    runtimeInputs = [
      pkgs.uv
      pkgs.python311
      pkgs.git
      pkgs.ripgrep
      pkgs.ffmpeg
      pkgs.nodejs_22
    ]
    ++ lib.optionals cfg.browserTools [ pkgs.chromium ];
    text = ''
      export LD_LIBRARY_PATH="${runtimeLibPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      export UV_NO_CONFIG=1
      ${optionalString cfg.browserTools ''
        export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
        export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
      ''}

      # Carrega secrets (GEMINI_API_KEY/GOOGLE_API_KEY) se o arquivo for legível.
      if [ -r "${cfg.environmentFile}" ]; then
        set -a
        # shellcheck disable=SC1090,SC1091
        source "${cfg.environmentFile}"
        set +a
      fi

      if [ ! -x "${hermesBin}" ]; then
        echo "hermes: venv não encontrado em ${venvDir}." >&2
        echo "       Rode: sudo systemctl start hermes-install.service" >&2
        exit 1
      fi

      exec "${hermesBin}" --provider "${cfg.provider}" -m "${cfg.model}" "$@"
    '';
  };

in
{
  options.kryonix.services.hermes = {
    enable = mkEnableOption "Hermes Agent (NousResearch) declarativo via uv";

    role = mkOption {
      type = types.enum [
        "server"
        "client"
      ];
      default = "client";
      description = "server (glacier): daemon gateway + comando; client (inspiron): só o comando hermes.";
    };

    provider = mkOption {
      type = types.str;
      default = "google";
      description = "Provider de LLM padrão passado ao hermes (--provider).";
    };

    model = mkOption {
      type = types.str;
      default = "gemini-2.5-flash";
      description = "Modelo padrão passado ao hermes (-m). Ex.: gemini-2.5-flash, gemini-2.5-pro.";
    };

    extras = mkOption {
      type = types.listOf types.str;
      default = [ "google" ];
      description = "Extras Python do hermes-agent a instalar (ex.: google, mcp, cli).";
    };

    browserTools = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Habilita ferramentas de navegador/computer-use (Playwright + Chromium do Nix).
        Adiciona os extras 'web' e 'computer-use' e configura PLAYWRIGHT_BROWSERS_PATH.
        Pesado — evite no inspiron se quiser build leve.
      '';
    };

    gateway = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Sobe o daemon do gateway de mensageria (systemd) no boot (apenas role=server).
          Requer tokens das plataformas no environmentFile. Default false: o serviço
          existe mas não autostarta até você ligar com tokens configurados.
        '';
      };

      args = mkOption {
        type = types.listOf types.str;
        default = [ "gateway" ];
        description = "Argumentos passados ao hermes para subir o gateway (ex.: [ \"gateway\" \"run\" ]).";
      };
    };

    environmentFile = mkOption {
      type = types.str;
      default = "/etc/kryonix/hermes.env";
      description = ''
        Arquivo de secrets (GEMINI_API_KEY/GOOGLE_API_KEY e tokens de plataformas).
        Modo 600, gitignored. NUNCA versionar.
      '';
    };

    stateDir = mkOption {
      type = types.path;
      default = "/var/lib/kryonix/hermes";
      description = "Diretório de estado: venv compartilhado + HERMES_HOME do daemon.";
    };

    user = mkOption {
      type = types.str;
      default = "hermes";
      description = "Usuário de sistema do daemon Hermes.";
    };

    group = mkOption {
      type = types.str;
      default = "hermes";
      description = "Grupo de sistema do daemon Hermes.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Pacotes extras adicionados ao PATH do agente em runtime.";
    };
  };

  config = mkIf cfg.enable {

    # Comando `hermes` disponível em todos os hosts que habilitam o módulo.
    environment.systemPackages = [ hermesWrapper ];

    # Usuário/grupo de sistema dedicados (evita colisão com kryonix do brain.nix).
    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "Hermes Agent service user";
      home = cfg.stateDir;
      createHome = true;
    };

    # stateDir world-readable/executable: o venv não contém secrets (esses ficam
    # no environmentFile), então usuários humanos podem executar o `hermes`.
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 ${cfg.user} ${cfg.group} - -"
    ];

    # Instalação do venv (oneshot, idempotente). Precisa de rede no primeiro run.
    systemd.services.hermes-install = {
      description = "Hermes Agent — instalação/atualização do venv (uv)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = commonEnv;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = installScript;
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        TimeoutStartSec = "1800";
      };
    };

    # Daemon do gateway de mensageria (apenas server).
    systemd.services.hermes-gateway = mkIf (cfg.role == "server") {
      description = "Hermes Agent — Messaging Gateway";
      after = [
        "network-online.target"
        "hermes-install.service"
      ];
      wants = [ "network-online.target" ];
      requires = [ "hermes-install.service" ];
      # Só autostarta quando gateway.enable = true (tokens configurados).
      wantedBy = mkForce (optionals cfg.gateway.enable [ "multi-user.target" ]);
      environment = commonEnv // {
        HERMES_HOME = cfg.stateDir;
      };
      serviceConfig = {
        ExecStart = "${hermesBin} --provider ${cfg.provider} -m ${cfg.model} ${concatStringsSep " " cfg.gateway.args}";
        EnvironmentFile = "-${cfg.environmentFile}";
        WorkingDirectory = cfg.stateDir;
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "10";
      };
    };
  };
}
