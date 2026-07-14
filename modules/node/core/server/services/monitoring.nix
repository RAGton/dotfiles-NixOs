{
  config,
  lib,
  pkgs,
  nodeServerIp,
  nodeHttpPort,
  ...
}:

# ─────────────────────────────────────────────────────────────────────────────
# MONITORING — Prometheus + Node Exporter + Grafana
#
# Portas:
#   9090  Prometheus   (métricas internas)
#   9100  Node Exporter (métricas do sistema)
#   3000  Grafana       (dashboards)
#
# Acesso aos dashboards:
#   http://<serverIp>:3000
#   Usuário padrão: admin / admin  (trocar no primeiro acesso)
#
# Adicionar outros exporters conforme necessário:
#   services.prometheus.exporters.nginx.enable  = true;
#   services.prometheus.exporters.nfs.enable    = true;  (via scrape custom)
#
# ─────────────────────────────────────────────────────────────────────────────

let
  tier1MountChecks = [
    "/srv/data/home"
    "/srv/data/images"
    "/srv/data/snapshots"
  ];

  tier1MetricsCheck = pkgs.writeShellScript "node-metrics-tier1-ready" ''
    set -euo pipefail
    ${lib.concatMapStringsSep "\n" (mountPath: ''
      ${pkgs.util-linux}/bin/mountpoint -q ${mountPath}
    '') tier1MountChecks}
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/node_exporter/textfile_collector 0755 root root -"
  ];

  # -----------------------------------------------------------------------
  # Node Exporter — métricas do host (CPU, RAM, disco, rede, NFS)
  # -----------------------------------------------------------------------
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    extraFlags = [ "--collector.textfile.directory=/var/lib/node_exporter/textfile_collector" ];
    enabledCollectors = [
      "systemd"
      "processes"
      "filesystem"
      "netdev"
      "nfs"
      "meminfo"
      "loadavg"
      "cpu"
      "diskstats"
    ];
  };

  systemd.services.node-metrics = {
    description = "NODE operational metrics (textfile collector)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "prometheus-node-exporter.service"
    ];
    wants = [ "network-online.target" ];
    unitConfig = {
      RequiresMountsFor = "/srv/data /srv/data/images /srv/data/home /srv/data/snapshots";
      ConditionPathIsMountPoint = "/srv/data/images";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecCondition = tier1MetricsCheck;
      ExecStart = pkgs.writeShellScript "node-collect-metrics" ''
        set -euo pipefail

        outdir="/var/lib/node_exporter/textfile_collector"
        tmp="$(mktemp -p "$outdir" node.prom.XXXXXX)"
        trap 'rm -f "$tmp"' EXIT
        chmod 0644 "$tmp"

        now="$(date +%s)"
        exec >"$tmp"

        line() {
          printf '%s\n' "$*"
        }

        metric() {
          printf '%s %s\n' "$1" "$2"
        }

        images_root="/srv/data/images"
        snapshots_root="/srv/data/snapshots"
        http_root="/srv/http"

        tier1_ready=0
        if ${
          lib.concatStringsSep " && " (
            map (mountPath: "${pkgs.util-linux}/bin/mountpoint -q ${mountPath}") tier1MountChecks
          )
        }; then
          tier1_ready=1
        fi

        current_ok=0
        if [[ -L "$images_root/current" ]]; then
          cur="$(readlink -f "$images_root/current" 2>/dev/null || true)"
          if [[ -n "$cur" && -f "$cur/bzImage" && -f "$cur/initrd" && -f "$cur/manifest.json" ]]; then
            current_ok=1
          fi
        fi

        previous_ok=0
        if [[ -L "$images_root/previous" ]]; then
          prev="$(readlink -f "$images_root/previous" 2>/dev/null || true)"
          if [[ -n "$prev" && -f "$prev/manifest.json" ]]; then
            previous_ok=1
          fi
        fi

        staged_ok=0
        if [[ -L "$images_root/staged" ]]; then
          stg="$(readlink -f "$images_root/staged" 2>/dev/null || true)"
          if [[ -n "$stg" && -f "$stg/manifest.json" ]]; then
            staged_ok=1
          fi
        fi

        images_bytes=0
        if [[ -d "$images_root" ]]; then
          images_bytes="$(du -sb "$images_root" 2>/dev/null | awk '{print $1}' || echo 0)"
        fi

        images_dirs=0
        if [[ -d "$images_root" ]]; then
          images_dirs="$(find "$images_root" -maxdepth 1 -mindepth 1 -type d -name 'v*' 2>/dev/null | wc -l | tr -d ' ')"
        fi

        active_count=0
        if [[ -d "$images_root" ]]; then
          while IFS= read -r p; do
            [[ -f "$p/manifest.json" ]] || continue
            st="$(awk -F '\"' '/"status"[[:space:]]*:/ { print $4; exit }' "$p/manifest.json" 2>/dev/null || true)"
            [[ "$st" == "active" ]] && active_count=$((active_count + 1)) || true
          done < <(find "$images_root" -maxdepth 1 -mindepth 1 -type d -name 'v*' 2>/dev/null)
        fi

        previous_required=0
        if [[ "$active_count" -ge 2 ]]; then
          previous_required=1
        fi

        snapshots_count=0
        latest_snapshot_age=0
        if [[ -d "$snapshots_root" ]]; then
          snapshots_count="$(find "$snapshots_root" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
          latest_path="$(
            find "$snapshots_root" -maxdepth 1 -mindepth 1 -type d -printf '%T@ %p\n' 2>/dev/null \
              | sort -nr \
              | head -n1 \
              | cut -d' ' -f2- \
              || true
          )"
          if [[ -n "$latest_path" ]]; then
            latest_mtime="$(stat -c %Y "$latest_path" 2>/dev/null || echo 0)"
            if [[ "$latest_mtime" -gt 0 ]]; then
              latest_snapshot_age=$(( now - latest_mtime ))
            fi
          fi
        fi

        http_boot_ok=0
        if curl -fsS "http://127.0.0.1:${toString nodeHttpPort}/boot.ipxe" >/dev/null 2>&1; then
          http_boot_ok=1
        fi

        boot_declared=""
        if [[ -f "$http_root/boot.ipxe" ]]; then
          boot_declared="$(awk '$1 == "set" && $2 == "current_build_id" { print $3; exit }' "$http_root/boot.ipxe" 2>/dev/null || true)"
        fi

        current_ipxe_declared=""
        if [[ -f "$http_root/current.ipxe" ]]; then
          current_ipxe_declared="$(awk '$1 == "set" && $2 == "build_id" { print $3; exit }' "$http_root/current.ipxe" 2>/dev/null || true)"
        fi

        http_manifest_id=""
        if [[ "$http_boot_ok" -eq 1 ]]; then
          http_manifest_id="$(curl -fsS "http://127.0.0.1:${toString nodeHttpPort}/netboot/current/manifest.json" 2>/dev/null | sed -nE 's/.*"id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n1 || true)"
        fi

        current_version=""
        if [[ "$current_ok" -eq 1 ]]; then
          current_version="$(basename "$cur")"
        fi

        boot_path_consistent=0
        if [[ -n "$current_version" \
          && "$boot_declared" == "$current_version" \
          && "$current_ipxe_declared" == "$current_version" \
          && "$http_manifest_id" == "$current_version" ]]; then
          boot_path_consistent=1
        fi

        doctor_failures=1
        knyc_present=0
        knyc_bin="/run/current-system/sw/bin/knyc"
        if [[ -x "$knyc_bin" ]]; then
          knyc_present=1
          if "$knyc_bin" doctor >/dev/null 2>&1; then
            doctor_failures=0
          fi
        fi

        line "# HELP node_images_bytes Disk usage of /srv/data/images in bytes"
        line "# TYPE node_images_bytes gauge"
        metric "node_images_bytes" "$images_bytes"

        line "# HELP node_tier1_ready Tier 1 mount is ready"
        line "# TYPE node_tier1_ready gauge"
        metric "node_tier1_ready" "$tier1_ready"

        line "# HELP node_images_dirs Number of v* directories in /srv/data/images"
        line "# TYPE node_images_dirs gauge"
        metric "node_images_dirs" "$images_dirs"

        line "# HELP node_generation_current_ok current symlink points to a usable generation"
        line "# TYPE node_generation_current_ok gauge"
        metric "node_generation_current_ok" "$current_ok"

        line "# HELP node_generation_previous_ok previous symlink points to a valid generation"
        line "# TYPE node_generation_previous_ok gauge"
        metric "node_generation_previous_ok" "$previous_ok"

        line "# HELP node_generation_staged_ok staged symlink points to a valid generation"
        line "# TYPE node_generation_staged_ok gauge"
        metric "node_generation_staged_ok" "$staged_ok"

        line "# HELP node_generation_active_count Count of generations with manifest status=active"
        line "# TYPE node_generation_active_count gauge"
        metric "node_generation_active_count" "$active_count"

        line "# HELP node_generation_previous_required previous must exist when active_count>=2"
        line "# TYPE node_generation_previous_required gauge"
        metric "node_generation_previous_required" "$previous_required"

        line "# HELP node_snapshots_count Number of snapshots under /srv/data/snapshots"
        line "# TYPE node_snapshots_count gauge"
        metric "node_snapshots_count" "$snapshots_count"

        line "# HELP node_snapshot_latest_age_seconds Age of latest snapshot under /srv/data/snapshots in seconds"
        line "# TYPE node_snapshot_latest_age_seconds gauge"
        metric "node_snapshot_latest_age_seconds" "$latest_snapshot_age"

        line "# HELP node_http_boot_ok HTTP boot endpoint reachable (boot.ipxe)"
        line "# TYPE node_http_boot_ok gauge"
        metric "node_http_boot_ok" "$http_boot_ok"

        line "# HELP node_boot_path_consistent current pointer, boot.ipxe, current.ipxe and HTTP manifest converge"
        line "# TYPE node_boot_path_consistent gauge"
        metric "node_boot_path_consistent" "$boot_path_consistent"

        line "# HELP node_knyc_present knyc binary available on server (1=yes)"
        line "# TYPE node_knyc_present gauge"
        metric "node_knyc_present" "$knyc_present"

        line "# HELP node_doctor_unhealthy knyc doctor reports issues (1=unhealthy)"
        line "# TYPE node_doctor_unhealthy gauge"
        metric "node_doctor_unhealthy" "$doctor_failures"

        mv -f "$tmp" "$outdir/node.prom"
        chmod 0644 "$outdir/node.prom"
        trap - EXIT
      '';
    };
    path = with pkgs; [
      coreutils
      findutils
      gnugrep
      gawk
      util-linux
      curl
    ];
  };

  systemd.timers.node-metrics = {
    description = "NODE operational metrics schedule";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "5m";
      AccuracySec = "30s";
      Unit = "node-metrics.service";
    };
  };

  # -----------------------------------------------------------------------
  # Prometheus — coleta e armazena métricas
  # -----------------------------------------------------------------------
  services.prometheus = {
    enable = true;
    port = 9090;

    retentionTime = "30d";

    scrapeConfigs = [
      {
        job_name = "node";
        scrape_interval = "15s";
        static_configs = [
          {
            targets = [ "localhost:9100" ];
            labels = {
              instance = "srv-rag";
            };
          }
        ];
      }
    ];

    # Alertas básicos
    rules = [
      ''
        groups:
          - name: node
            rules:
              - alert: HostDown
                expr: up == 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "Host {{ $labels.instance }} inacessível"

              - alert: HighMemoryUsage
                expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.90
                for: 5m
                labels:
                  severity: warning
                annotations:
                  summary: "Uso de memória acima de 90% em {{ $labels.instance }}"

              - alert: DiskAlmostFull
                expr: (node_filesystem_size_bytes{mountpoint="/srv/data/images"} - node_filesystem_free_bytes{mountpoint="/srv/data/images"}) / node_filesystem_size_bytes{mountpoint="/srv/data/images"} > 0.85
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: "Disco /srv/data/images acima de 85%"

              - alert: CriticalServiceDown
                expr: |
                  node_systemd_unit_state{name=~"dnsmasq\\.service|nginx\\.service|nfs-server\\.service|prometheus\\.service|grafana\\.service",state="active"} == 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "Serviço {{ $labels.name }} parado"
                  description: "Impacto provável: DHCP/boot/NFS/monitoramento indisponível. Primeira ação: systemctl status {{ $labels.name }}."

              - alert: BootHttpDown
                expr: node_http_boot_ok == 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "HTTP de boot indisponível"
                  description: "Impacto provável: clientes não conseguem baixar boot.ipxe/kernel/initrd. Primeira ação: systemctl status nginx; curl http://127.0.0.1:${toString nodeHttpPort}/boot.ipxe."

              - alert: GenerationCurrentMissingOrBroken
                expr: node_generation_current_ok == 0
                for: 2m
                labels:
                  severity: critical
                annotations:
                  summary: "Geração current ausente ou quebrada"
                  description: "Impacto provável: boot falha. Primeira ação: knyc doctor; verificar /srv/data/images/current e /srv/http/netboot."

              - alert: GenerationPreviousMissing
                expr: node_generation_previous_required == 1 and node_generation_previous_ok == 0
                for: 5m
                labels:
                  severity: warning
                annotations:
                  summary: "previous ausente quando deveria existir"
                  description: "Impacto provável: rollback pode falhar. Primeira ação: knyc list; verificar /srv/data/images/previous."

              - alert: DoctorUnhealthy
                expr: node_doctor_unhealthy > 0
                for: 2m
                labels:
                  severity: warning
                annotations:
                  summary: "knyc doctor detectou estado inseguro"
                  description: "Primeira ação: executar knyc doctor e corrigir itens apontados (serviços, links, boot.ipxe, manifests)."

              - alert: Tier1NotReady
                expr: node_tier1_ready == 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "Tier 1 de storage nao esta pronto"
                  description: "Impacto provável: publish, rollback, snapshots e metricas devem falhar fechados. Primeira ação: verificar mounts de /srv/data."

              - alert: BootPathInconsistent
                expr: node_boot_path_consistent == 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "Coerencia ponta a ponta do boot divergente"
                  description: "Impacto provável: ponteiros, dispatcher e HTTP nao convergem para a mesma geracao. Primeira ação: knyc doctor."

              - alert: SnapshotsGrowingFast
                expr: node_snapshots_count > 30
                for: 30m
                labels:
                  severity: warning
                annotations:
                  summary: "Muitos snapshots acumulados"
                  description: "Impacto provável: consumo excessivo de /srv/data. Primeira ação: revisar política de retenção de snapshots."

              - alert: ImagesGrowingFast
                expr: delta(node_images_bytes[1h]) > 10737418240
                for: 30m
                labels:
                  severity: warning
                annotations:
                  summary: "Crescimento anormal de /srv/data/images"
                  description: "Impacto provável: falta de espaço/GC insuficiente. Primeira ação: knyc gc; revisar snapshots e gerações antigas."
      ''
    ];
  };

  # -----------------------------------------------------------------------
  # Grafana — visualização de dashboards
  # -----------------------------------------------------------------------
  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        domain = nodeServerIp;
      };

      analytics.reporting_enabled = false;
    };

    # Provisiona automaticamente o Prometheus como datasource
    provision.datasources.settings.datasources = [
      {
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9090";
        isDefault = true;
      }
    ];

    provision.dashboards.settings.providers = [
      {
        name = "node";
        type = "file";
        options.path = "${./monitoring/dashboards}";
      }
    ];
  };
}
