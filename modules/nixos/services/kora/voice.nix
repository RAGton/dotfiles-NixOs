{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.kryonix.services.kora.voice;
  brainCfg = config.kryonix.features.ai.brain;

  koraOllamaUrl =
    if brainCfg.enable && brainCfg.role == "client" then
      "http://${brainCfg.serverHost}:${toString brainCfg.ollamaPort}"
    else
      "http://127.0.0.1:11434";

  koraBrainUrl =
    if brainCfg.enable && brainCfg.role == "client" then
      "http://${brainCfg.serverHost}:${toString brainCfg.brainPort}"
    else
      "http://127.0.0.1:8000";

  koraApiUrl =
    if brainCfg.enable && brainCfg.role == "client" then
      "http://${brainCfg.serverHost}:8787"
    else
      "http://127.0.0.1:8787";

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

    defaultPreset = mkOption {
      type = types.str;
      default = "kora_f5tts";
      description = "Active voice preset passed as KORA_DEFAULT_VOICE_PRESET.";
    };

    f5ttsEndpoint = mkOption {
      type = types.str;
      default = "http://rve-glacier:7860";
      description = "F5-TTS server endpoint (passed as KORA_F5TTS_ENDPOINT).";
    };

    voiceReference = mkOption {
      type = types.str;
      default = "/var/lib/f5-tts/voices/kora.wav";
      description = "Path to reference WAV on the F5-TTS server (KORA_VOICE_REFERENCE).";
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/cache/kora 0775 rocha users - -"
      "d /var/cache/kora/tts 0775 rocha users - -"
    ];

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
        KORA_DEFAULT_VOICE_PRESET = cfg.defaultPreset;
        KORA_F5TTS_ENDPOINT = cfg.f5ttsEndpoint;
        KORA_VOICE_REFERENCE = cfg.voiceReference;
        KORA_OLLAMA_URL = koraOllamaUrl;
        KORA_BRAIN_URL = koraBrainUrl;
        KORA_API_URL = koraApiUrl;
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
