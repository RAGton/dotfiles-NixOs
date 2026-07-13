{
  config,
  pkgs,
  ragosServerIp,
  ragosHttpPort,
  ragosMgmtInterface,
  ragosHostName,
  ragosTimeZone,
  ragosLocale,
  ragosKeyMap,
  ragosAdminUser,
  ragosAdminUid,
  ragosAdminHashedPassword,
  ragosAdminAuthorizedKeys,
  ragcPkg,
  lib,
  ...
}:

let
  ragosOpsPkg = pkgs.callPackage ../ragos-cli.nix { };
in
{
  system.stateVersion = "25.11";
  networking.hostName = ragosHostName;

  time.timeZone = ragosTimeZone;
  i18n.defaultLocale = ragosLocale;
  console.keyMap = ragosKeyMap;

  environment.systemPackages =
    (with pkgs; [
      ragosOpsPkg
      ragcPkg
      ipxe
      iproute2
      nano
      tree
      git
      htop
      btrfs-progs
      squashfsTools
      nixos-generators
      nfs-utils
      rsync
      tmux
    ])
    ++ [
      config.system.build.nixos-rebuild
    ];

  programs.nh = {
    enable = true;
    flake = "/etc/ragos";
    clean = {
      enable = true;
      dates = "daily";
      extraArgs = "--keep 5 --keep-since 7d --optimise";
    };
  };

  services.openssh.enable = true;

  environment.etc."issue".text = lib.mkForce ''
    RAGOS Server
    Host: \n
    TTY:  \l

    Authorized access only.
  '';

  environment.etc."issue.net".text = lib.mkForce ''
    RAGOS Server ${ragosHostName}
    Authorized access only.
  '';

  # Criar admin user apenas se configurado
  users.users = lib.optionalAttrs (ragosAdminUser != "" && ragosAdminUser != null) {
    "${ragosAdminUser}" = {
      isNormalUser = true;
      uid = ragosAdminUid;
      extraGroups = [ "wheel" ];
      hashedPassword = ragosAdminHashedPassword;
      openssh.authorizedKeys.keys = ragosAdminAuthorizedKeys;
    };
  };

  security.sudo.wheelNeedsPassword = false;

  programs.bash.promptInit = ''
    if [[ -n "''${SSH_CONNECTION:-}" ]]; then
      ragos_ctx="ssh"
    else
      ragos_ctx="local"
    fi

    if [[ "$EUID" -eq 0 ]]; then
      ragos_user_color='\[\e[1;31m\]'
      ragos_prompt_char='#'
    else
      ragos_user_color='\[\e[1;34m\]'
      ragos_prompt_char='$'
    fi

    export PROMPT_DIRTRIM=2
    PS1='\[\e[2m\]['"$ragos_ctx"']\[\e[0m\] '"$ragos_user_color"'\u@\h\[\e[0m\] \[\e[1;37m\]\W\[\e[0m\] '"$ragos_prompt_char"' '
  '';

  programs.bash.interactiveShellInit = ''
        if [[ -n "''${RAGOS_SESSION_WELCOME_SHOWN:-}" ]]; then
          return
        fi

        if [[ ! -t 1 || "''${SHLVL:-1}" -gt 1 || -n "''${TMUX:-}" || -n "''${STY:-}" ]]; then
          return
        fi

        if [[ -z "''${SSH_CONNECTION:-}" ]]; then
          case "$(tty 2>/dev/null || true)" in
            /dev/tty1|/dev/ttyS*|/dev/hvc*|/dev/ttyAMA*)
              ;;
            *)
              return
              ;;
          esac
        fi

        export RAGOS_SESSION_WELCOME_SHOWN=1

        ragos_server_welcome() {
          local os_pretty kernel_version mem_used mem_total server_ipv4 lan_ipv4 uptime_line
          local system_generation client_generation tier1_state nginx_state nfs_state dnsmasq_state

          status_text() {
            case "$1" in
              active|ready)
                printf '\033[1;32m%s\033[0m' "$1"
                ;;
              activating|reloading)
                printf '\033[1;33m%s\033[0m' "$1"
                ;;
              *)
                printf '\033[1;31m%s\033[0m' "$1"
                ;;
            esac
          }

          os_pretty="$(source /etc/os-release 2>/dev/null && echo "''${PRETTY_NAME:-RAGOS Server}")"
          kernel_version="$(uname -r 2>/dev/null || echo 'desconhecido')"
          mem_used="$(awk '/MemTotal/ { total=$2 } /MemAvailable/ { avail=$2 } END { used=total-avail; printf "%.1f GiB", used/1024/1024 }' /proc/meminfo 2>/dev/null)"
          mem_total="$(awk '/MemTotal/ { printf "%.1f GiB", $2/1024/1024 }' /proc/meminfo 2>/dev/null)"
          uptime_line="$(uptime -p 2>/dev/null || true)"
          uptime_line="''${uptime_line:-uptime indisponivel}"
          lan_ipv4="$(ip -4 -o addr show dev ${ragosMgmtInterface} 2>/dev/null | awk '{print $4}' | sed 's#/.*##' | head -n1)"
          server_ipv4="''${lan_ipv4:-${ragosServerIp}}"
          system_generation="$(readlink /nix/var/nix/profiles/system 2>/dev/null | sed -nE 's/.*system-([0-9]+)-link/\1/p')"
          system_generation="''${system_generation:-?}"
          client_generation="$(sed -nE 's/.*"id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' /srv/data/images/current/manifest.json 2>/dev/null | head -n1 || true)"
          client_generation="''${client_generation:-indisponivel}"

          if mountpoint -q /srv/data/images && mountpoint -q /srv/data/home && mountpoint -q /srv/data/snapshots; then
            tier1_state="ready"
          else
            tier1_state="degraded"
          fi

          nginx_state="$(systemctl is-active nginx 2>/dev/null || echo failed)"
          nfs_state="$(systemctl is-active nfs-server 2>/dev/null || echo failed)"
          dnsmasq_state="$(systemctl is-active dnsmasq 2>/dev/null || echo failed)"

          if [[ -z "''${SSH_CONNECTION:-}" ]]; then
            clear
          fi

          cat <<EOF
    \033[1;37mRAGOS Server\033[0m
    \033[2m$(printf '─%.0s' $(seq 1 56))\033[0m
    Host........ ${ragosHostName}
    LAN......... ${ragosMgmtInterface}  ''${server_ipv4}
    Boot HTTP... http://${ragosServerIp}:${toString ragosHttpPort}
    System...... ''${os_pretty}
    Generation.. sistema ''${system_generation}   cliente ''${client_generation}
    Kernel...... ''${kernel_version}
    Uptime...... ''${uptime_line}
    Memory...... ''${mem_used:-indisponivel} / ''${mem_total:-indisponivel}
    Tier1....... $(status_text "''${tier1_state}")
    Services.... nginx=$(status_text "''${nginx_state}")  nfs=$(status_text "''${nfs_state}")  dnsmasq=$(status_text "''${dnsmasq_state}")

    Ops......... ragc doctor
    Ops......... ragc status
    Ops......... systemctl --failed
    Ops......... journalctl -p err -b

    EOF
        }

        ragos_server_welcome
  '';
}
