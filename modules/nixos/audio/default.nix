{
  lib,
  pkgs,
  hostname,
  ...
}:
{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    wireplumber = {
      enable = true;
      extraConfig.bluetoothEnhancements = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
          "bluez5.enable-msbc" = true;
          "bluez5.enable-hw-volume" = true;
          "bluez5.roles" = [
            "a2dp_source"
            "hsp_hs"
            "hsp_ag"
            "hfp_hf"
            "hfp_ag"
          ];
        };
      };

      # Qualquer dispositivo bluez_card — garante perfil headset (mSBC) e
      # auto-connect com microfone. Regex (~) é mais robusto que MAC fixo.
      extraConfig.jblWaveBuds = {
        "monitor.bluez.rules" = [
          {
            matches = [ { "device.name" = "~bluez_card.*"; } ];
            actions."update-props" = {
              "bluez5.auto-connect" = [
                "hfp_hf"
                "hsp_hs"
                "a2dp_sink"
              ];
              "bluez5.roles" = [
                "hfp_hf"
                "hsp_hs"
                "a2dp_sink"
              ];
              "bluez5.profile" = "headset-head-unit-msbc";
            };
          }
        ];
      };
    };

    extraConfig = {
      pipewire."92-low-latency" = {
        context.properties = {
          default.clock.rate = 48000;
          default.clock.quantum = 128;
          default.clock.min-quantum = 64;
          default.clock.max-quantum = 2048;
        };
      };

      pipewire."95-audio-quality" = {
        context.properties = {
          default.clock.allowed-rates = [
            44100
            48000
            96000
          ];
          resample.quality = 10;
        };
      };

      pipewire-pulse."95-pulse-headroom" = {
        stream.properties = {
          pulse.min.quantum = 64;
        };
        context.properties = {
          pulse.min.req = 64;
          pulse.default.req = 128;
        };
      };
    };
  };

  # =========================
  # Bluetooth (Stable Baseline)
  # =========================
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Name = hostname;
        # Experimental desabilitado: evita "Hardware error 0x0c" em Intel BT
        Experimental = false;
        # FastConnectable pode causar instabilidade de sinal
        FastConnectable = false;
        JustWorksRepairing = "always";
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  services.blueman.enable = true;

  # BlueZ utilities and audio debuggers
  environment.systemPackages = with pkgs; [
    pavucontrol
    pamixer
    playerctl
    bluez
    bluez-tools
    wireplumber
    crosspipe
    qpwgraph
    portaudio  # PortAudio library for voice/STT/TTS (e.g., Hermes agent)
  ];

  # =========================
  # Resilience (Standard)
  # =========================
  # Removemos os serviços de força bruta bluetooth-power-on e bluetooth-unblock
  # para evitar o loop de "ligar e desligar" quando o driver/hardware falha.
  # O fallback padrão do driver e a config acima são suficientes.

  # Ensure blueman-applet runs correctly in the user session
  systemd.user.services.blueman-applet = {
    serviceConfig.ExecStart = lib.mkForce [
      ""
      "${pkgs.blueman}/bin/blueman-applet"
    ];
  };
}
