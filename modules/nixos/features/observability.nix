{ config, lib, pkgs, ... }:
let cfg = config.kryonix.features.observability; in
{
  options.kryonix.features.observability = {
    prometheus.enable = lib.mkEnableOption "Prometheus metrics";
    grafana.enable = lib.mkEnableOption "Grafana dashboards";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.prometheus.enable {
      services.prometheus.enable = true;
      services.prometheus.port = 9090;
    })
    (lib.mkIf cfg.grafana.enable {
      services.grafana.enable = true;
      services.grafana.settings.server.http_port = 3000;
    })
  ];
}
