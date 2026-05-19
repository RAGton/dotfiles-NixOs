{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.kryonix.services.kora.voice;
in
{
  options.kryonix.services.kora.voice = {
    enable = mkEnableOption "Kora Voice Listener background service";

    alwaysOn = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to start the voice listener on login automatically.
        Even when true, wake-word requires a custom model; without it
        the service runs in PTT-ready mode only.
      '';
    };

    wakeword = mkOption {
      type = types.str;
      default = "kora";
      description = "Target wake-word (requires custom model for real activation).";
    };
  };

  config = mkIf cfg.enable {
    # ── systemd --user unit for Kora Voice Listener ──────────────────────────
    # Manage via:
    #   kora voice service enable|disable|start|stop|status|logs
    # Wake-word status: ready=false until custom model is deployed.
    systemd.user.services.kora-voice-listener = {
      description = "Kora Voice Listener Daemon";
      documentation = [ "https://github.com/RAGton/kryonix/docs/kora/VOICE_IDENTITY.md" ];
      after = [
        "pipewire.service"
        "wireplumber.service"
        "sound.target"
      ];
      wantedBy = mkIf cfg.alwaysOn [ "default.target" ];
      environment = {
        KORA_VOICE_ALWAYS_ON = "1";
        KORA_WAKE_WORD = cfg.wakeword;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kora}/bin/kora /voice daemon run";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };
  };
}
