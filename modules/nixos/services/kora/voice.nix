{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.kryonix.services.kora.voice;

  edresson-model = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR/edresson/low/pt_BR-edresson-low.onnx";
    sha256 = "116dj64xnw18fnkcc0ppglvhr7ym0pv7lcwa6ykb22xk73pfqk6y";
  };

  edresson-config = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR/edresson/low/pt_BR-edresson-low.onnx.json";
    sha256 = "0mkca3m3nnvng04z5g618brv01s368nlrcdvl0x1wzbp5qnrjf7i";
  };
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
        # Explicit PipeWire socket path; %t expands to /run/user/<UID> in
        # systemd user-service context so pw-record always finds the server.
        PIPEWIRE_RUNTIME_DIR = "%t";
        # Apontando para o modelo feminino edresson declarativo do Nix store
        KORA_PIPER_MODEL = "${edresson-model}";
        KORA_PIPER_CONFIG = "${edresson-config}";
        KORA_DEFAULT_VOICE_PRESET = "edresson";
      };
      path = [ pkgs.pipewire ];
      serviceConfig = {
        Type = "simple";
        # Aguarda handshake Bluetooth antes de abrir o microfone.
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
        # pw-record captura o áudio diretamente via PipeWire e envia PCM
        # bruto para o daemon via pipe, eliminando PyAudio/PortAudio do processo.
        # kora-admin é o entrypoint correto para "voice daemon run"
        # (kora.sh usa kora-admin voice daemon, não o wrapper kora).
        ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.pipewire}/bin/pw-record --channels 1 --rate 48000 --format s16 --raw - | ${pkgs.kora}/bin/kora-admin voice daemon run'";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };
  };
}
