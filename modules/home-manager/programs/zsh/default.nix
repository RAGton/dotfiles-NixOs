#+#+#+#+####################################################################
# Home Manager: Zsh + Powerlevel10k
# Autor: rag
#
# O que é
# - Define Zsh como shell do usuário com plugins via Nix.
# - Carrega Powerlevel10k e uma configuração P10k versionada no repo.
# - Exibe `fastfetch` no primeiro prompt de cada sessão interativa.
#
# Por quê
# - Padroniza o shell entre hosts.
# - Evita drift: o `.p10k.zsh` vem do Nix store e não depende de arquivos locais não-versionados.
#
# Como
# - Gera `~/.config/zsh/.p10k.zsh` via `home.file`.
# - Inicializa P10k e plugins no `initContent`.
#
# Riscos
# - Se `fastfetch` falhar, ele é ignorado (`|| true`) para não quebrar o shell.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.kryonix.programs.zsh;
in
{
  options.kryonix.programs.zsh.welcomeBanner.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Mostra um welcome banner curto KryonixOS (uma linha) no startup
      do zsh interativo. Sem custo de rede.

      Pode ser suprimido em runtime com `export KRYONIX_NO_WELCOME=1`
      antes do shell, ou desabilitado declarativamente com
      `kryonix.programs.zsh.welcomeBanner.enable = false`.
    '';
  };

  config = {
    home.activation.create-p10k-dir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.config/zsh"
    '';

    home.file.".config/zsh/.p10k.zsh" = {
      # Fonte global compartilhada entre hosts.
      # Importante: este arquivo precisa estar rastreado no Git para flakes enxergarem.
      source = ./.p10k.zsh;
      force = true;
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = false; # usaremos plugin via Nix
      syntaxHighlighting.enable = false;

      oh-my-zsh = {
        enable = true;

        # No setup via Nix, os diretórios de completion podem aparecer com owner
        # imutável do store e disparar falso positivo do compfix.
        extraConfig = ''
          ZSH_DISABLE_COMPFIX=true
        '';

        # Não carregar tema via oh-my-zsh: o Powerlevel10k será carregado via pacote Nix.
        # Isso evita o erro "theme 'powerlevel10k/powerlevel10k' not found".
        theme = "";

        plugins = [
          "git"
          "kubectl"
        ];
      };

      shellAliases = {
        ff = "fastfetch";
        v = "nvim";
        ls = "eza --icons always";
      };

      initContent = ''
        # =========================
        # Welcome cockpit (KryonixOS)
        # =========================
        # Banner sem custo de rede, default-on. Opt-out:
        #   - declarativo: kryonix.programs.zsh.welcomeBanner.enable = false
        #   - runtime:     export KRYONIX_NO_WELCOME=1
        ${lib.optionalString cfg.welcomeBanner.enable ''
          if [[ -o interactive ]] && [[ -t 1 ]] \
              && [[ -z "''${KRYONIX_NO_WELCOME-}" ]] \
              && [[ -z "''${KRYONIX_WELCOME_DONE-}" ]]; then
            export KRYONIX_WELCOME_DONE=1

            _kryonix_hostname="$(hostname -s 2>/dev/null || echo localhost)"
            _kryonix_kernel="$(uname -r 2>/dev/null || echo unknown)"
            _kryonix_uptime="$(awk '{
              s = int($1);
              d = int(s / 86400); s %= 86400;
              h = int(s / 3600); s %= 3600;
              m = int(s / 60);
              if (d > 0) printf "%dd %dh", d, h;
              else if (h > 0) printf "%dh %dm", h, m;
              else printf "%dm", m;
            }' /proc/uptime 2>/dev/null)"
            [[ -n "$_kryonix_uptime" ]] || _kryonix_uptime="unknown"
            _kryonix_ip="$(ip -o -4 addr show scope global 2>/dev/null | awk '{ split($4, a, "/"); print $2 "=" a[1] }' | paste -sd ' ' -)"
            [[ -n "$_kryonix_ip" ]] || _kryonix_ip="offline/local-only"
            _kryonix_cpu="$(awk -F: '/model name/ { sub(/^[ \t]+/, "", $2); print $2; exit }' /proc/cpuinfo 2>/dev/null)"
            [[ -n "$_kryonix_cpu" ]] || _kryonix_cpu="$(lscpu 2>/dev/null | awk -F: '/Model name/ { sub(/^[ \t]+/, "", $2); print $2; exit }')"
            [[ -n "$_kryonix_cpu" ]] || _kryonix_cpu="unknown CPU"
            _kryonix_mem="$(free -h 2>/dev/null | awk '/^Mem:/ { print $3 "/" $2 }')"
            _kryonix_disk="$(df -h / 2>/dev/null | awk 'NR==2 { print $3 "/" $2 " (" $5 ")" }')"
            _kryonix_gpu="$(for card in /sys/class/drm/card*/device; do
              [[ -e "$card/vendor" ]] || continue
              vendor="$(cat "$card/vendor" 2>/dev/null)"
              device="$(cat "$card/device" 2>/dev/null)"
              case "''${vendor}:''${device}" in
                0x1002:0x6665) printf '%s · ' "AMD Radeon R5 M230/R7 M260DX/520/610 Mobile" ;;
                0x8086:0x3ea0) printf '%s · ' "Intel UHD Graphics 620" ;;
                *)
                  driver="$(basename "$(readlink -f "$card/driver" 2>/dev/null)" 2>/dev/null)"
                  printf '%s:%s/%s · ' "$vendor" "$device" "$driver"
                  ;;
              esac
            done)"
            _kryonix_gpu="''${_kryonix_gpu% · }"
            [[ -n "$_kryonix_gpu" ]] || _kryonix_gpu="unknown GPU"
            _kryonix_profile="Desktop"
            _kryonix_edition="Kryonix Desktop"
            if [[ -r /etc/kryonix/identity.json ]]; then
              _kryonix_profile="$(jq -r '.role // "Desktop"' /etc/kryonix/identity.json 2>/dev/null || echo Desktop)"
              _kryonix_edition="$(jq -r '.edition // "Kryonix Desktop"' /etc/kryonix/identity.json 2>/dev/null || echo 'Kryonix Desktop')"
            fi
            _kryonix_panel_host="$(ip -o -4 addr show scope global 2>/dev/null | awk '{ split($4, a, "/"); print a[1]; exit }')"
            [[ -n "$_kryonix_panel_host" ]] || _kryonix_panel_host="127.0.0.1"
            _kryonix_panel_name="''${_kryonix_hostname}.local"

            printf '\033[36m%s\033[0m\n' ' _  _______   ______  _   _ ___ __  __   ___  ____'
            printf '\033[36m%s\033[0m\n' '| |/ /  __ \ / __  \| \ | |_ _|\ \/ /  / _ \/ ___|'
            printf '\033[36m%s\033[0m\n' "| ' /| |__) | |  | ||  \\| || |  \\  /  | | | \\___ \\"
            printf '\033[36m%s\033[0m\n' '| . \|  _  /| |  | || |\  || |  /  \  | |_| |___) |'
            printf '\033[36m%s\033[0m\n' '|_|\_\_| \_\ \____/ |_| \_|___|/_/\_\  \___/|____/'
            printf '\033[35m%s\033[0m\n' "KryonixOS · $_kryonix_hostname · $_kryonix_edition"
            printf '\033[2m%s\033[0m\n' "────────────────────────────────────────────────────────"
            printf '  \033[36m%-10s\033[0m %s\n' "IP" "$_kryonix_ip"
            printf '  \033[36m%-10s\033[0m %s\n' "Hardware" "$_kryonix_cpu"
            printf '  \033[36m%-10s\033[0m RAM %s · Root %s\n' "Uso" "$_kryonix_mem" "$_kryonix_disk"
            printf '  \033[36m%-10s\033[0m %s\n' "GPU" "$_kryonix_gpu"
            printf '  \033[36m%-10s\033[0m role=%s · kernel=%s · uptime=%s\n' "Perfil" "$_kryonix_profile" "$_kryonix_kernel" "$_kryonix_uptime"
            printf '  \033[36m%-10s\033[0m Host: http://%s:8080\n' "Painel" "$_kryonix_panel_name"
            printf '  \033[36m%-10s\033[0m IP:   http://%s:8080\n' "" "$_kryonix_panel_host"
            printf '\033[2m%s\033[0m\n' "Dica: kryx --help · fastfetch · KRYONIX_NO_WELCOME=1 para ocultar"
          fi
        ''}

        # =========================
        # Startup (interativo)
        # =========================
        # Nota: fastfetch pode travar/demorar dependendo de rede (ex.: publicip).
        # Então o banner completo continua sendo OPT-IN.
        # Para reativar: export RAG_ZSH_STARTUP_BANNER=1
        if [[ -o interactive ]] && [[ -t 1 ]] && [[ -n "''${RAG_ZSH_STARTUP_BANNER-}" ]] && [[ -z "''${RAG_ZSH_STARTUP_BANNER_DONE-}" ]]; then
          export RAG_ZSH_STARTUP_BANNER_DONE=1
          clear
          fastfetch || true
        fi

        # =========================
        # Powerlevel10k
        # =========================
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
        if [ -f "$HOME/.config/zsh/.p10k.zsh" ]; then
          source "$HOME/.config/zsh/.p10k.zsh"
        fi

        # =========================
        # Plugins via Nix
        # =========================
        source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

        # =========================
        # Keybindings
        # =========================
        bindkey -e
        autoload -z edit-command-line
        zle -N edit-command-line
        bindkey "^v" edit-command-line

        # =========================
        # kubectl completion
        # =========================
        source <(${pkgs.kubectl}/bin/kubectl completion zsh)
      '';
    };

    home.packages = with pkgs; [
      git
      kubectl
      eza
      fastfetch
      zsh-powerlevel10k
      zsh-autosuggestions
      zsh-syntax-highlighting
    ];
  };
}
