{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kryonix.installer.kiosk;
in
{
  options.kryonix.installer.kiosk = {
    enable = lib.mkEnableOption "Kiosk web do instalador (Cage + Chromium)";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Endereço de bind do backend. O default local-only evita expor o instalador na LAN.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:${toString cfg.port}";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      startInstallerBackend = pkgs.writeShellScriptBin "start-installer-backend" ''
        if grep -qw 'kryonix.installer.mode=remote' /proc/cmdline; then
          export KRYONIX_INSTALLER_BIND="0.0.0.0:${toString cfg.port}"
        else
          export KRYONIX_INSTALLER_BIND="${cfg.listenAddress}:${toString cfg.port}"
        fi

        exec ${pkgs.kryonix-installer}/bin/kryonix-installer
      '';
      startKiosk =
        (pkgs.writeShellScriptBin "start-kiosk" ''
          # Cage (Wayland) needs XDG_RUNTIME_DIR — getty autologin does not set it
          export XDG_RUNTIME_DIR="/run/user/$(id -u)"
          mkdir -p "$XDG_RUNTIME_DIR"
          chmod 0700 "$XDG_RUNTIME_DIR"

          # Required in QEMU/VM: virtio-gpu does not expose hardware cursors
          # pixman renderer is slower but much more compatible with virtual GPUs
          export WLR_NO_HARDWARE_CURSORS=1
          export WLR_RENDERER=pixman
          export LIBSEAT_BACKEND=seatd
          export XDG_SESSION_TYPE=wayland

          # Wait up to 90s for the backend (/health) before opening the browser.
          # Full store path avoids relying on PATH being set up during autologin.
          echo "Waiting for installer backend on port ${toString cfg.port}..."
          for i in $(seq 1 90); do
            if ${pkgs.curl}/bin/curl -sf "http://127.0.0.1:${toString cfg.port}/health" >/dev/null 2>&1; then
              echo "Backend is UP"
              break
            fi
            sleep 1
          done

          if grep -q "kryonix.installer.mode=remote" /proc/cmdline; then
            echo -e "\n======================================================="
            echo -e "        KRYONIX OS - REMOTE INSTALLER MODE             "
            echo -e "=======================================================\n"
            echo -e "O instalador está rodando no modo remoto.\n"

            IP_ADDR=$(${pkgs.iproute2}/bin/ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n 1)
            if [ -z "$IP_ADDR" ]; then
                IP_ADDR="<aguardando-rede>"
            fi

            echo -e "\nPara instalar, acesse de outro computador na rede:"
            echo -e "\n  ->  http://$IP_ADDR:${toString cfg.port}"
            echo -e "\n======================================================="

            exec ${pkgs.bash}/bin/bash
          fi

          # --app=URL forces app mode: no tab bar, no address bar, no browser chrome.
          # --kiosk alone is insufficient on many Chromium builds inside Cage.
          echo "Starting cage + chromium..."
          exec ${pkgs.cage}/bin/cage -s -- \
            ${pkgs.chromium}/bin/chromium \
              --app="${cfg.url}" \
              --no-sandbox \
              --test-type \
              --autoplay-policy=no-user-gesture-required \
              --no-first-run \
              --noerrdialogs \
              --disable-dev-shm-usage \
              --disable-gpu-sandbox \
              --disable-infobars \
              --disable-translate \
              --disable-extensions \
              --disable-pinch \
              --overscroll-history-navigation=0 \
              --disable-features=TranslateUI,OverscrollHistoryNavigation \
              --disable-background-networking \
              --disable-sync \
              --window-position=0,0 \
              --window-size=1280,720
        '').overrideAttrs
          (_: {
            passthru.shellPath = "/bin/start-kiosk";
          });
    in
    {

      users.users.installer = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "disk"
          "video"
          "input"
          "drm"
          "seat"
        ];
        password = "";
        shell = startKiosk;
      };

      environment.shells = [ startKiosk ];

      # Autologin direto no TTY1
      services.getty.autologinUser = lib.mkForce "installer";

      # seatd: necessário para cage acessar DRM/seat sem root
      services.seatd.enable = true;
      security.polkit.enable = true;

      # Web Terminal (ttyd) para modo Manual
      systemd.services.kryonix-installer-terminal = {
        description = "Kryonix Installer Web Terminal";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.ttyd}/bin/ttyd -p 8081 -i 127.0.0.1 -W /bin/sh";
          Restart = "on-failure";
          User = "root";
        };
      };

      # Backend do instalador — roda como root para poder chamar disko/nixos-install
      systemd.services.kryonix-installer-backend = {
        description = "Kryonix Installer Backend";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        before = [ "getty@tty1.service" ];
        # Utilitários que o backend chama por nome (sem caminho absoluto).
        # systemd services NÃO herdam /run/current-system/sw/bin, então cada
        # binário precisa estar explícito aqui — senão os safety checks (que
        # rodam `which disko`/`which nixos-install`) recusam a instalação com
        # "Safety checks falharam".
        # - util-linux: lsblk/findmnt (disk.rs) — senão GET /api/disks dá 500;
        # - networkmanager: nmcli (network.rs) — senão a etapa Rede mostra
        #   "0 interfaces detectadas" e bloqueia o wizard;
        # - which: safety.rs usa Command::new("which") — sem ele TODO check falha;
        # - curl: safety.rs check_network_for_nix (cache.nixos.org);
        # - disko: safety + executor (disko --mode disko);
        # - nixos-install-tools: executor (nixos-install);
        # - nix: nixos-install precisa do nix no PATH para avaliar o flake.
        path = [
          pkgs.util-linux
          pkgs.networkmanager
          pkgs.which
          pkgs.curl
          pkgs.disko
          pkgs.nixos-install-tools
          pkgs.iproute2
          config.nix.package
        ];
        serviceConfig = {
          ExecStart = "${startInstallerBackend}/bin/start-installer-backend";
          Restart = "on-failure";
          User = "root";
        };
        environment = {
          KRYONIX_INSTALLER_FLAKE = "${inputs.self.outPath}";
          KRYONIX_ENGINE_SOURCE = "/etc/kryonix";
          KRYONIX_HARDWARE_PROBE = "${pkgs.kryonix-hardware-probe}/bin/kryonix-hardware-probe";
          # O CLI do disko (disko --mode disko <config.nix>) avalia
          # `import <nixpkgs>` em cli.nix; sem NIX_PATH o particionamento falha
          # com "file 'nixpkgs' was not found in the Nix search path".
          NIX_PATH = "nixpkgs=${pkgs.path}";
        };
      };

      # Sudo sem senha para o usuário installer (operações manuais via terminal)
      # O backend já roda como root e não precisa de sudo
      security.sudo.extraRules = [
        {
          users = [ "installer" ];
          commands = [
            {
              command = "${pkgs.gptfdisk}/bin/sgdisk";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.parted}/bin/partprobe";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.dosfstools}/bin/mkfs.fat";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.btrfs-progs}/bin/mkfs.btrfs";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.btrfs-progs}/bin/btrfs";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.util-linux}/bin/mount";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.util-linux}/bin/umount";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.nixos-install-tools}/bin/nixos-install";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

      # Ignorar power/suspend/lid para não interromper o kiosk
      services.logind.settings.Login = {
        HandlePowerKey = "ignore";
        HandleSuspendKey = "ignore";
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
      };

      # Suprimir cursor piscante no TTY
      boot.kernelParams = [ "vt.global_cursor_default=0" ];

      # disko e nixos-install-tools: necessários para os safety checks do executor
      # (check_disko_available, check_nixos_install_available)
      environment.systemPackages = with pkgs; [
        cage
        chromium
        curl
        kryonix-hardware-probe
        kryonix-installer
        disko
        nixos-install-tools
      ];

      # O backend controla internamente o bind (127.0.0.1 vs 0.0.0.0) baseado no modo remoto,
      # então sempre abrimos a porta no firewall.
      networking.firewall.allowedTCPPorts = [
        cfg.port
      ];

      hardware.graphics.enable = lib.mkDefault true;

      # Fontes do kiosk: a base installation-cd não traz fontes GUI, então o
      # Chromium renderiza apenas caixas/fallback. enableDefaultPackages cobre o
      # baseline (dejavu/liberation/noto-emoji); inter = UI sans; jetbrains-mono
      # = mono/branding (mesmas fontes do desktop Kryonix).
      fonts = {
        enableDefaultPackages = true;
        fontconfig.enable = true;
        packages = with pkgs; [
          inter
          nerd-fonts.jetbrains-mono
        ];
      };

      # Copia o source do engine para /etc/kryonix para que o instalador
      # tenha um caminho gravável e relativo a usar como input do target
      # flake v2 (path:./engine). Sem isto, o engine só existiria em
      # /nix/store, o que ressuscita o vazamento de pure-eval.
      #
      # IMPORTANTE: o flake.lock é PRESERVADO. Ele pina nixpkgs/home-manager/
      # plasma-manager nos mesmos SRI hashes que já estão no store da ISO
      # — o que permite `nix flake metadata --offline` no preflight e o
      # nixos-install offline. Apagar o lock força re-fetch via internet e
      # derruba a UI com "Failed to fetch" antes do install começar.
      system.activationScripts.kryonix-engine-source = {
        text = ''
          mkdir -p /etc/kryonix
          cp -r ${inputs.self.outPath}/. /etc/kryonix/
        '';
        deps = [ "etc" ];
      };
    }
  );
}
