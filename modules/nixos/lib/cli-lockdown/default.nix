{ lib, config, pkgs, ... }:
let
  cfg = config.kryonix.security.cliLockdown;

  # Script wrapper que imprime o erro do Kryonix Guard.
  guardScript = binName: ''
    #!${pkgs.bash}/bin/bash
    echo -e "\033[1;31m[Kryonix Guard]\033[0m O comando '\033[1m${binName}\033[0m' foi bloqueado."
    echo -e "Use o ecossistema \033[1;32mkryx\033[0m para gerenciar o sistema."
    echo -e "Exemplo: \033[36mkryx switch\033[0m  —  \033[36mkryx update\033[0m"
    echo -e "Consulte \033[36mkryx --help\033[0m para a lista completa de comandos."
    exit 1
  '';
in
{
  options.kryonix.security.cliLockdown = {
    enable = lib.mkEnableOption ''
      Kryonix Guard — bloqueia acesso direto a binários Nix/NH/NixOS
      no PATH interativo do usuário.

      Quando ativo, wrappers de erro são instalados no PROFILE DO USUÁRIO
      (via `home.packages`, não em `environment.systemPackages`),
      mascarando os binários nativos APENAS no shell interativo.

      CRÍTICO: Os wrappers NÃO devem ir para `/run/current-system/sw/bin/`,
      porque isso sobrescreveria os binários reais do Nix Store e quebraria
      o `kryx` (que chama `nh` via caminho absoluto) e `nh` (que invoca `nix`
      via `.nh-wrapped`).

      O binário `kryx` (e qualquer ferramenta usando caminhos absolutos
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
      description = ''
        Lista de binários a serem bloqueados no PATH interativo do usuário.
        Esses wrappers só aparecem em sessões shell interativas, não em
        chamadas de subprocessos do sistema (que continuam funcionando).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Pacote contendo APENAS os wrappers (não instalado no system profile).
    # O home-manager vai puxar via `home.packages`.
    #
    # Por que NÃO `environment.systemPackages`:
    # - Sobrescreveria `/run/current-system/sw/bin/{nix,nh,nixos-rebuild}`
    #   com os wrappers, quebrando o kryx daemon e o nh-wrapped.
    # - Bloquearia o root de usar esses binários, impedindo recovery.
    #
    # Por que `home.packages`:
    # - Wrappers vão pro `~/.nix-profile/bin` do usuário
    # - `~/.nix-profile/bin` vem ANTES de `/run/current-system/sw/bin` no $PATH
    #   do shell interativo
    # - Subprocessos herdam o PATH explicitamente, então kryx ainda usa o real
    home-manager.sharedModules = [
      ({ pkgs, ... }: {
        home.packages = let
          makeWrapper = binName:
            pkgs.writeShellScriptBin binName (guardScript binName);
        in builtins.map makeWrapper cfg.blockedCommands;
      })
    ];
  };
}