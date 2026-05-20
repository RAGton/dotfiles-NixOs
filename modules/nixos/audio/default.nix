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

      # JBL Wave Buds — força perfil headset (mSBC) para ativar microfone.
      # Sem essa regra o WirePlumber seleciona A2DP (só saída) por padrão.
      # MAC: 50:5E:5C:97:6A:61 → nome do dispositivo com underscores.
      extraConfig.jblWaveBuds = {
        "monitor.bluez.rules" = [
          {
            matches = [ { "device.name" = "bluez_card.50_5E_5C_97_6A_61"; } ];
            actions."update-props" = {
              "bluez5.auto-connect" = [ "hfp_hf" "hsp_hs" "a2dp_sink" ];
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
  # Bluetooth (Robust Config)
  # =========================
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Name = hostname;
        Experimental = true;
        FastConnectable = true;
        JustWorksRepairing = "always";
        MultiProfile = "multiple";
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
  ];

  # =========================
  # Systemd Resilience Services
  # =========================
  systemd.services = {
    # Garante que o Bluetooth não volte "soft blocked" por causa do estado salvo do rfkill.
    bluetooth-unblock = {
      description = "Unblock Bluetooth adapter before bluetoothd";
      wantedBy = [ "multi-user.target" ];
      wants = [ "systemd-rfkill.service" ];
      after = [ "systemd-rfkill.service" ];
      before = [ "bluetooth.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        ${pkgs.util-linux}/bin/rfkill unblock bluetooth || true
      '';
    };

    bluetooth-power-on = {
      description = "Power on Bluetooth adapter after bluetoothd";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "bluetooth.service"
        "bluetooth-unblock.service"
      ];
      after = [
        "bluetooth.service"
        "bluetooth-unblock.service"
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        ${pkgs.bluez}/bin/bluetoothctl power on || true
      '';
    };
  };

  # Reset rfkill state during activation to force unblocked state
  system.activationScripts.bluetoothRfkillReset.text = ''
    for state in /var/lib/systemd/rfkill/*bluetooth*; do
      [ -e "$state" ] || continue
      echo 0 > "$state" || true
    done
  '';

  # Ensure blueman-applet runs correctly in the user session
  systemd.user.services.blueman-applet = {
    serviceConfig.ExecStart = lib.mkForce [
      ""
      "${pkgs.blueman}/bin/blueman-applet"
    ];
  };
}
