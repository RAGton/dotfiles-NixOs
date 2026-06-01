# =============================================================================
# kryonix-krdp — Servidor RDP do Plasma (KRDP) para acesso remoto headless
#
# O que é:
# - Serviço systemd-user que roda `krdpserver` (kdePackages.krdp) dentro da
#   sessão Plasma Wayland, expondo um monitor virtual via RDP em 127.0.0.1:3389.
#
# Por quê:
# - Substitui o kryonix-wayvnc no ambiente KDE: wayvnc só funciona com
#   compositores wlroots (Hyprland/Sway) e é incompatível com o KWin/Plasma.
#   O KRDP é a solução nativa de desktop remoto do Plasma 6.
#
# Como:
# - krdpserver com `--virtual-monitor` (headless) + `--plasma`, ouvindo apenas
#   no loopback (como o wayvnc fazia). Credenciais lidas de um EnvironmentFile
#   (KRDP_USERNAME / KRDP_PASSWORD) — NÃO passamos a senha por argumento.
#
# ⚠️  NÃO VALIDADO em hardware: o caminho headless (sessão Plasma + monitor
#     virtual + RDP) precisa de verificação presencial no glacier. Mantenha
#     acesso por console/SSH ao aplicar. Rollback: reverter o host/usuário para
#     o stack Hyprland + kryonix-wayvnc.
#
# Pré-requisitos (no host):
# - Sessão Plasma Wayland em execução (ex.: SDDM autologin) para o krdpserver
#   anexar/compartilhar.
# - Arquivo de credenciais em ~/.config/kryonix/krdp.env com:
#     KRDP_USERNAME=<usuario>
#     KRDP_PASSWORD=<senha>
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.kryonix-krdp;
in
{
  options.services.kryonix-krdp = {
    enable = lib.mkEnableOption "Kryonix KRDP Server (Plasma RDP, loopback only)";

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Endereço de escuta do krdpserver (apenas loopback por padrão).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3389;
      description = "Porta RDP do krdpserver.";
    };

    virtualMonitor = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080@1";
      description = "Monitor virtual headless (WIDTHxHEIGHT@SCALE).";
    };

    environmentFile = lib.mkOption {
      type = lib.types.str;
      default = "%h/.config/kryonix/krdp.env";
      description = ''
        Arquivo (formato systemd EnvironmentFile) com KRDP_USERNAME e KRDP_PASSWORD.
        `%h` é expandido para o home do usuário pelo systemd.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.kdePackages.krdp ];

    systemd.user.services.kryonix-krdp = {
      Unit = {
        Description = "Kryonix KRDP Server (Plasma RDP, ${cfg.address}:${toString cfg.port})";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        # Credenciais via EnvironmentFile (não expor senha em ps/cmdline).
        EnvironmentFile = cfg.environmentFile;
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.kdePackages.krdp}/bin/krdpserver"
          "--address ${cfg.address}"
          "--port ${toString cfg.port}"
          "--virtual-monitor ${cfg.virtualMonitor}"
          "--plasma"
          "--username \${KRDP_USERNAME}"
          "--password \${KRDP_PASSWORD}"
        ];
        Restart = "always";
        RestartSec = "5";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
