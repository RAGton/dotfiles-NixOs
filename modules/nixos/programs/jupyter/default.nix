# NixOS: Jupyter (system-level) + kernels (Python/Rust/C++/Node)
#
# Objetivo
# - Disponibilizar Jupyter no sistema (em /run/current-system/sw) e garantir kernels.
# - Oferecer um "pip mutável" *seguro* via venv por usuário (fora do /nix/store).
#
# Nota importante
# - Em Nix, `pip` não deve instalar coisas no Python do sistema (imutável).
# - Por isso, este módulo instala o Python/Jupyter do sistema e cria um venv
#   em ~/.local/share/jupyter/venvs/default para pacotes mutáveis.
{
  config,
  lib,
  pkgs,
  userConfig,
  ...
}:

let
  cfg = config.programs.jupyter;

  python = pkgs.python3;

  # Em channels novos, nodePackages pode existir mas lançar erro ao acessar attrs.
  # Preferimos o pacote top-level quando disponível.
  ijavascriptEval =
    if pkgs ? ijavascript then
      builtins.tryEval pkgs.ijavascript
    else
      {
        success = false;
        value = null;
      };
  hasIjavascript = ijavascriptEval.success;
  ijavascriptPkg = if hasIjavascript then ijavascriptEval.value else null;

  # Usuário(s) alvo do host.
  defaultUser = userConfig.name;
  users = if cfg.users != null then cfg.users else [ defaultUser ];

  # Resolve HOME do usuário. Nem sempre `users.users.<name>.home` é definido explicitamente.
  getHome = u: (config.users.users.${u}.home or "/home/${u}");

  mkBootstrap =
    username:
    let
      userHome = getHome username;
      venvDir = "${userHome}/.local/share/jupyter/venvs/default";
      venvPython = "${venvDir}/bin/python";
      venvPip = "${venvDir}/bin/pip";
    in
    pkgs.writeShellScript "jupyter-system-bootstrap-${username}" ''
      set -euo pipefail

      export HOME="${userHome}"
      # Garante que binários do pip (como zmq/cryptography) encontrem libs do sistema
      export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:${pkgs.libffi}/lib:${pkgs.openssl}/lib:$LD_LIBRARY_PATH"

      mkdir -p "$HOME/.local/share"

      if [ ! -x "${venvPython}" ]; then
        ${python}/bin/python -m venv "${venvDir}"
      fi

      "${venvPip}" install --upgrade pip setuptools wheel

      # Garante tooling de notebook/lab no venv (mutável).
      "${venvPip}" install --upgrade jupyterlab

      if [ "${lib.boolToString cfg.kernels.python}" = "true" ]; then
        "${venvPip}" install --upgrade ipykernel
        "${venvPython}" -m ipykernel install --user --name python-venv --display-name "Python (venv)"
      fi

      if [ "${lib.boolToString cfg.kernels.rust}" = "true" ]; then
        ${pkgs.evcxr}/bin/evcxr_jupyter --install
      fi

      if [ "${lib.boolToString cfg.kernels.cpp}" = "true" ]; then
        for k in xcpp11-jupyter-kernel xcpp14-jupyter-kernel xcpp17-jupyter-kernel; do
          if [ -x "${pkgs.xeus-cling}/bin/$k" ]; then
            "${pkgs.xeus-cling}/bin/$k" install --user
          fi
        done
      fi

      if [ "${lib.boolToString cfg.kernels.node}" = "true" ]; then
        if [ "${lib.boolToString hasIjavascript}" = "true" ]; then
          ${lib.optionalString hasIjavascript "${ijavascriptPkg}/bin/ijsinstall --user"}
          :
        else
          echo "kernel Node (ijavascript) não disponível neste nixpkgs" >&2
          exit 1
        fi
      fi
    '';

in
{
  options.programs.jupyter = {
    enable = lib.mkEnableOption "Jupyter no sistema com kernels Python/Rust/C++/Node e venv mutável por usuário";

    users = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = [ "rag" ];
      description = ''
        Lista de usuários que receberão o bootstrap do venv (pip mutável) e o registro dos kernels.
        Se null, usa o usuário principal definido em `userConfig.name`.
      '';
    };

    kernels = {
      python = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita kernel Python (ipykernel) dentro do venv mutável";
      };

      rust = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita kernel Rust (evcxr_jupyter)";
      };

      cpp = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita kernel C++ (xeus-cling). Desativado por padrão pois o xeus-cling frequentemente quebra build em alguns canais (falhas em testes/kernels durante o build).";
      };

      node = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita kernel Node.js (ijavascript)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      python
      pkgs.jupyter
    ]
    ++ lib.optionals cfg.kernels.rust [ pkgs.evcxr ]
    ++ lib.optionals cfg.kernels.cpp [
      pkgs.xeus-cling
      pkgs.gcc
    ]
    ++ lib.optionals (cfg.kernels.node && hasIjavascript) [
      pkgs.nodejs
      ijavascriptPkg
    ];

    # Bootstrapa o venv e registra kernels na ativação do sistema.
    system.activationScripts.jupyterBootstrap = {
      text = ''
        ${lib.concatStringsSep "\n" (
          map (u: ''
            if [ -d ${lib.escapeShellArg (getHome u)} ]; then
              echo "[jupyter] bootstrapping user venv/kernels for ${u}" > /dev/null
              ${pkgs.su}/bin/su - ${u} -c ${lib.escapeShellArg (mkBootstrap u)}
            fi
          '') users
        )}
      '';
    };
  };
}
