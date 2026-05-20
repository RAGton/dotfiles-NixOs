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
        # Route PortAudio/ALSA through PipeWire's virtual device instead of
        # probing raw hardware devices (which PipeWire holds exclusively).
        # Without this, PortAudio gets -9999 (paUnanticipatedHostError) when
        # enumerating hw:X,X devices that PipeWire has already locked.
        ALSA_PCM_PLUGIN = "pipewire";
        PA_ALSA_PLUGHW = "1";
        # Explicit PipeWire socket path; %t expands to /run/user/<UID> in
        # systemd user-service context so the client always finds the server.
        PIPEWIRE_RUNTIME_DIR = "%t";
      };
      # Add PipeWire binaries (pw-cli, pw-dump, etc.) to the service PATH so
      # any runtime PipeWire interaction works without absolute paths.
      path = [ pkgs.pipewire ];
      serviceConfig = {
        Type = "simple";
        # Aguarda handshake Bluetooth antes de abrir o microfone.
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
        ExecStart = "${pkgs.kora}/bin/kora /voice daemon run";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };
  };
}
