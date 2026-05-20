# =============================================================================
# Feature: F5-TTS Server (zero-shot voice cloning)
#
# O que é:
# - Servidor REST de síntese de voz com clonagem zero-shot via F5-TTS.
# - Roda no glacier (RTX 4060) e é consumido pela Kora no inspiron via Tailscale.
# - Provider primário da cadeia F5TTS→Piper→EdgeTTS→spd-say.
#
# Por quê:
# - Latência-alvo <2.5s vs ~3s do Piper atual.
# - Voz clonada a partir de ~15s de áudio de referência (zero-shot).
# - Inferência GPU elimina lentidão de CPU-only do Piper.
#
# Como usar:
#   1. kryonix.features.f5tts.enable = true  (em hosts/glacier/default.nix)
#   2. sudo bash /etc/kryonix/features/f5-tts-server/setup.sh
#   3. systemctl start f5-tts-server
#
# Segurança:
# - Bind 0.0.0.0, mas firewall restringe a tailscale0 e br0.
# - Processo isolado em usuário f5tts sem privilégios.
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg     = config.kryonix.features.f5tts;
  dataDir = "/var/lib/f5-tts";

  preStartCheck = pkgs.writeShellScript "f5tts-prestart" ''
    if [ ! -f "${dataDir}/venv/bin/python" ]; then
      echo "F5-TTS venv não configurado. Execute:" >&2
      echo "  sudo bash /etc/kryonix/features/f5-tts-server/setup.sh" >&2
      exit 1
    fi
    if [ ! -f "${dataDir}/voices/kora.wav" ]; then
      echo "AVISO: Áudio de referência ausente: ${dataDir}/voices/kora.wav" >&2
      echo "  Execute: bash /etc/kryonix/scripts/record_voice_reference.sh" >&2
    fi
  '';
in
{
  options.kryonix.features.f5tts = {
    enable = mkEnableOption "F5-TTS Server — síntese de voz zero-shot (glacier)";

    port = mkOption {
      type    = types.port;
      default = 7860;
      description = "Porta de escuta do servidor F5-TTS.";
    };
  };

  config = mkIf cfg.enable {

    users.users.f5tts = {
      isSystemUser = true;
      group        = "f5tts";
      home         = dataDir;
      description  = "F5-TTS inference server";
    };
    users.groups.f5tts = {};

    systemd.services.f5-tts-server = {
      description = "F5-TTS Zero-Shot Voice Synthesis Server";
      after       = [ "network.target" ];

      serviceConfig = {
        Type              = "simple";
        User              = "f5tts";
        Group             = "f5tts";
        StateDirectory    = "f5-tts";
        StateDirectoryMode = "0750";
        ExecStartPre      = preStartCheck;
        ExecStart         = "${dataDir}/venv/bin/python /etc/kryonix/features/f5-tts-server/api_server.py";
        Restart           = "on-failure";
        RestartSec        = "10s";
        MemoryMax         = "8G";
        WorkingDirectory  = dataDir;
        Environment       = [
          "HOME=${dataDir}"
          "HF_HOME=${dataDir}/hf-cache"
          "PYTHONUNBUFFERED=1"
          # libcuda.so + libstdc++.so.6 — pip packages não encontram estas no NixOS
          "LD_LIBRARY_PATH=/run/opengl-driver/lib:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib"
          "F5TTS_PORT=${toString cfg.port}"
        ];
      };
    };

    # Expõe o servidor apenas em Tailscale e LAN interna (br0)
    networking.firewall.interfaces = {
      tailscale0.allowedTCPPorts = [ cfg.port ];
      br0.allowedTCPPorts        = [ cfg.port ];
    };
  };
}
