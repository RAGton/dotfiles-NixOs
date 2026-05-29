# Configurações Declarativas de Sistema (Units do Systemd)

Módulos criados para carregar e controlar os daemons residentes em background de forma limpa via gerenciamento de estado do NixOS.

---

## 1. Módulo Systemd do Smart Filer (Rust)
Caminho alvo: `modules/home-manager/services/kryonix-home.nix`

```nix
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.kryonix.services.smart-filer;
in {
  options.kryonix.services.smart-filer = {
    enable = mkEnableOption "Daemon de Organização Semântica de Arquivos";
    watchPaths = mkOption {
      type = types.listOf types.str;
      default = [ "/home/rocha/Downloads" "/home/rocha/Inbox_IA" ];
      description = "Diretórios monitorados pelo Smart Filer.";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.kryonix-home = {
      Unit = {
        Description = "Kryonix Home Context-Aware File Watchdog";
        After = [ "network.target" "tailscaled.service" ];
      };
      Service = {
        ExecStart = "${pkgs.kryonix-home}/bin/kryonix-home --watch";
        EnvironmentFile = "/etc/kryonix/brain.env";
        Restart = "on-failure";
        RestartSec = "15";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
```

---

## 2. Módulo Systemd do RAM Optimizer (Python)

Caminho alvo: `modules/home-manager/services/kryonix-optimizer.nix`

```nix
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.kryonix.services.ram-optimizer;
in {
  options.kryonix.services.ram-optimizer = {
    enable = mkEnableOption "Otimizador Vivo de Recursos do Sistema por IA";
    checkInterval = mkOption {
      type = types.str;
      default = "minutely";
      description = "Intervalo de checagem da telemetria de RAM.";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.kryonix-optimizer = {
      Unit = {
        Description = "Kryonix Live Memory and Process Optimizer Daemon";
        After = [ "network.target" ];
      };
      Service = {
        ExecStart = "${pkgs.kryonix-optimizer}/bin/kryonix-optimizer-run";
        EnvironmentFile = "/etc/kryonix/brain.env";
        Restart = "on-failure";
        RestartSec = "30";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
```
