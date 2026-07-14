# ─────────────────────────────────────────────────────────────────────────────
# LOGIN AUDIT — Rastreamento de sessões, login/logout, histórico de acesso
#
# Funcionalidades:
#   - Log de login/logout com timestamp, IP, terminal
#   - Histórico de atividade por usuário
#   - Auditoria de sessões GUI (SDDM/Plasma)
#   - Integração com journalctl e syslog
#   - Consultas via `node user activity <nome>`
#
# Storage:
#   /var/lib/node/audit/login-history.json
#   /var/log/node-login-audit.log
#   journalctl -u sddm
#   journalctl -u pam_mount
#
# ─────────────────────────────────────────────────────────────────────────────

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  auditDir = "/var/lib/node/audit";
  auditHistoryFile = "${auditDir}/login-history.json";

  # Script que loga login/logout no arquivo JSON
  loginAuditScript = pkgs.writeShellApplication {
    name = "node-login-audit";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      action="''${1:-}"
      user="''${2:-}"
      tty="''${3:-unknown}"
      ip="''${4:-unknown}"

      [[ -n "$action" ]] || exit 0
      [[ -n "$user" ]] || exit 0

      audit_file="${auditHistoryFile}"
      mkdir -p "$(dirname "$audit_file")"

      # Inicializa JSON se não existe
      [[ -f "$audit_file" ]] || echo '{}' > "$audit_file"

      timestamp=$(date --iso-8601=seconds)
      sessionid="''${SESSIONID:-unknown}"

      case "$action" in
        login|logout|heartbeat)
          jq \
            --arg user "$user" \
            --arg action "$action" \
            --arg timestamp "$timestamp" \
            --arg tty "$tty" \
            --arg ip "$ip" \
            --arg sessionid "$sessionid" \
            ".sessions |= (. // {})
             | .sessions[\$user] |= (. // [])
             | .sessions[\$user] += [{
                 action: \$action,
                 timestamp: \$timestamp,
                 tty: \$tty,
                 ip: \$ip,
                 sessionid: \$sessionid
               }]
             | .last_update = \$timestamp" \
            "$audit_file" > "$audit_file.tmp"
          mv "$audit_file.tmp" "$audit_file"
          chmod 0640 "$audit_file"
          ;;
      esac
    '';
  };

  pamLoginAuditHook = pkgs.writeShellApplication {
    name = "node-login-audit-pam";
    runtimeInputs = [
      loginAuditScript
      pkgs.coreutils
      pkgs.hostname
    ];
    text = ''
      set -euo pipefail

      case "''${PAM_TYPE:-}" in
        open_session)
          action="login"
          ;;
        close_session)
          action="logout"
          ;;
        *)
          exit 0
          ;;
      esac

      user="''${PAM_USER:-}"
      [[ -n "$user" ]] || exit 0

      tty="''${PAM_TTY:-''${PAM_SERVICE:-unknown}}"
      if [[ "''${PAM_SERVICE:-}" == "sddm" && -z "''${PAM_TTY:-}" ]]; then
        tty="tty000"
      fi

      ip="''${PAM_RHOST:-}"
      if [[ -z "$ip" ]]; then
        ip="$(${pkgs.hostname}/bin/hostname -I 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $1}')"
      fi
      ip="${"ip:-unknown"}"

      exec ${loginAuditScript}/bin/node-login-audit "$action" "$user" "$tty" "$ip"
    '';
  };

  # Script para limpar login history
  cleanLoginHistoryScript = pkgs.writeShellApplication {
    name = "node-audit-clean";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      keeping_days="''${1:-90}"
      audit_file="${auditHistoryFile}"

      [[ -f "$audit_file" ]] || exit 0

      cutoff_epoch=$(date -d "$keeping_days days ago" +%s)

      jq \
        --arg cutoff "$(date -d @"$cutoff_epoch" --iso-8601=seconds)" \
        '.sessions |= with_entries(
          .value |= [
            .[] | select(.timestamp > $cutoff)
          ] | if length > 0 then . else empty end
        )' \
        "$audit_file" > "$audit_file.tmp"
      mv "$audit_file.tmp" "$audit_file"
      chmod 0640 "$audit_file"
    '';
  };

in
{
  options.node.audit = {
    enable = mkEnableOption "NODE login audit tracking";

    retentionDays = mkOption {
      type = types.int;
      default = 90;
      description = "Days to keep login history (cleanup via cron)";
    };
  };

  config = mkIf config.node.audit.enable {
    # -----------------------------------------------------------------------
    # Diretórios e arquivo de auditoria
    # -----------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${auditDir} 0750 root root -"
      "f ${auditHistoryFile} 0640 root root -"
    ];

    # -----------------------------------------------------------------------
    # PAM override para chamar audit script no login/logout
    # -----------------------------------------------------------------------
    security.pam.services.login.rules.session.nodeLoginAudit = {
      order = config.security.pam.services.login.rules.session.systemd.order + 10;
      control = "optional";
      modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
      args = [ "${pamLoginAuditHook}/bin/node-login-audit-pam" ];
    };

    security.pam.services.sddm.rules.session.nodeLoginAudit = {
      order = config.security.pam.services.sddm.rules.session.systemd.order + 10;
      control = "optional";
      modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
      args = [ "${pamLoginAuditHook}/bin/node-login-audit-pam" ];
    };

    # -----------------------------------------------------------------------
    # Limpeza periódica do histórico de login (via systemd timer)
    # -----------------------------------------------------------------------
    systemd.services.node-audit-cleanup = {
      description = "Clean old NODE login audit history";
      script = ''
        ${cleanLoginHistoryScript}/bin/node-audit-clean ${toString config.node.audit.retentionDays}
      '';
    };

    systemd.timers.node-audit-cleanup = {
      description = "Daily cleanup of NODE audit history";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1d";
        Persistent = true;
      };
    };

    # -----------------------------------------------------------------------
    # Exposição de ferramentas de auditoria para `node` CLI
    # -----------------------------------------------------------------------
    environment.systemPackages = [
      loginAuditScript
      pamLoginAuditHook
      cleanLoginHistoryScript
      pkgs.jq
    ];
  };
}
