# =============================================================================
# Módulo: kryonix.services.aura
#
# O que é:
# - Empacota o script `aura` (packages/aura/aura.sh) como wrapper shell e o
#   coloca no PATH do sistema quando habilitado.
#
# Por quê:
# - Aura é a camada de roteamento (provider primary/fallbacks) da assistente
#   Kryonix. Ela permanece declarativa mesmo após a remoção do Hermes, para
#   que o usuário possa religá-la a um novo backend (Hermes reconfigurado ou
#   outro motor) sem perder a UX/atalhos.
#
# Observações:
# - O script `aura.sh` invoca o comando `hermes` em runtime. Sem um backend
#   no PATH, `aura` reportará erro — esperado até o usuário reconfigurar o
#   motor.
# - Secrets continuam fora do /nix/store: HERMES_ENV aponta para
#   /etc/kryonix/hermes.env (modo 600, gitignored).
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kryonix.services.aura;

  auraWrapper = pkgs.writeShellApplication {
    name = "aura";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    excludeShellChecks = [
      "SC1090"
      "SC1091"
    ];
    text = builtins.readFile ../../../packages/aura/aura.sh;
  };
in
{
  options.kryonix.services.aura = {
    enable = lib.mkEnableOption "Camada Aura (roteamento de providers da assistente Kryonix)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ auraWrapper ];
  };
}
