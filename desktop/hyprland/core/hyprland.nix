# =============================================================================
# core/hyprland.nix — Configuração base do WM (Home Manager)
#
# Habilita o Hyprland via HM e aponta para o hyprland.conf versionado.
# CRÍTICO: configType="hyprlang" — não mudar para "lua".
# CRÍTICO: systemd.enable=false — UWSM gerencia a sessão systemd-user.
# =============================================================================
{ lib, ... }:
{
  services.kanshi.enable = lib.mkForce false;

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    systemd.enable = false;
    extraConfig = builtins.readFile ../hyprland.conf;
  };

  # Remove arquivo regular e backup stale antes de checkLinkTargets.
  # Necessário porque HM não sobrescreve arquivos regulares se .hm-backup já existe,
  # deixando o symlink sem ser criado e o Hyprland gerando um stub autogenerado.
  home.activation.cleanHyprlandConf = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    _conf="$HOME/.config/hypr/hyprland.conf"
    rm -f "$_conf.hm-backup"
    if [[ -e "$_conf" && ! -L "$_conf" ]]; then
      rm -f "$_conf"
    fi
  '';
}
