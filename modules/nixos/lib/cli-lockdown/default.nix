{ lib, config, pkgs, ... }:
let
  cfg = config.kryonix.security.cliLockdown;
in
{
  options.kryonix.security.cliLockdown = {
    enable = lib.mkEnableOption ''
      Kryonix Guard — bloqueia acesso direto a binários Nix/NH/NixOS.

      Quando ativo, wrappers de erro são inseridos em `environment.systemPackages`
      com prioridade alta (`lib.hiPrio`), mascarando os binários nativos.
      O binário `kryx` (e qualquer ferramenta que use caminhos absolutos
      da Nix Store) continua funcionando normalmente.
    '';

    blockedCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "nixos-rebuild"
        "nix"
        "nix-shell"
        "nh"
      ];
      description = "Lista de binários a serem bloqueados com Kryonix Guard.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      let
        makeGuard = bin:
          let
            binName = baseNameOf bin;
          in
          pkgs.writeScriptBin binName ''
            #!${pkgs.bash}/bin/bash
            echo -e "\033[1;31m[Kryonix Guard]\033[0m O comando '\033[1m${binName}\033[0m' foi bloqueado."
            echo -e "Use o ecossistema \033[1;32mkryx\033[0m para gerenciar o sistema."
            echo -e "Exemplo: \033[36mkryx switch\033[0m  —  \033[36mkryx update\033[0m"
            echo -e "Consulte \033[36mkryx --help\033[0m para a lista completa de comandos."
            exit 1
          '';
      in
      builtins.map makeGuard cfg.blockedCommands;
  };
}
