# =============================================================================
# core/monitors.nix — Hook de monitores por host (Hyprland)
#
# O fallback genérico (monitor=,preferred,auto,1) já vem de nhModules/desktop/monitors.nix.
# Este módulo é o ponto correto para overrides específicos de host — escala,
# refresh, posição — declarados via kryonix.features.monitors ou diretamente
# via wayland.windowManager.hyprland.extraConfig no arquivo de host.
#
# Exemplo de uso em host:
#   wayland.windowManager.hyprland.extraConfig = lib.mkOrder 100 ''
#     monitor=eDP-1,2560x1600@165,0x0,1.6
#   '';
# =============================================================================
{ ... }:
{
  # Sem config aqui: o nhModules já fornece o fallback genérico.
  # Hosts sobrescrevem via mkOrder 100 em seus próprios módulos de desktop.
}
