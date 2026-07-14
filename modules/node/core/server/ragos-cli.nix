{ pkgs }:

pkgs.writeShellApplication {
  name = "node";
  runtimeInputs = with pkgs; [
    btrfs-progs
    coreutils
    findutils
    gawk
    gnugrep
    gnused
    jq
    nfs-utils
    openssl
    shadow
    util-linux
  ];
  text = ''
        set -euo pipefail

        readonly NODE_FLAKE_PATH="''${NODE_FLAKE_PATH:-/etc/node}"
        readonly NODE_TARGET_HOST="''${NODE_TARGET_HOST:-srv-rag}"
        readonly NODE_INSTALLABLE="git+file://''${NODE_FLAKE_PATH}#''${NODE_TARGET_HOST}"
        readonly NODE_RUNTIME_ROOT="''${NODE_RUNTIME_ROOT:-/var/lib/node/runtime}"
        readonly NODE_SYSTEM_PROFILE="/nix/var/nix/profiles/system"
        readonly NODE_KEEP_GENERATIONS=5
        readonly NODE_KEEP_SINCE="7d"
        readonly NODE_KEEP_SINCE_DATE_EXPR="7 days ago"
        readonly NODE_HOME_BASE="/srv/data/home"
        readonly NODE_HOME_ARCHIVE_BASE="/srv/data/home/.archive"
        readonly NODE_HOME_SNAPSHOT_BASE="/srv/data/snapshots/users"
        readonly NODE_HOME_META_FILE=".node-home-meta"
        readonly NODE_CLIENT_USERS_FILE="$NODE_RUNTIME_ROOT/client-users.json"
        readonly NODE_STORAGE_BASE="/srv/data/storage"
        readonly NODE_STORAGE_ARCHIVE="/srv/data/storage/.archive"
        readonly NODE_AUDIT_DIR="/var/lib/node/audit"
        readonly NODE_AUDIT_FILE="$NODE_AUDIT_DIR/login-history.json"
        readonly NODE_USER_GROUPS_FILE="$NODE_RUNTIME_ROOT/user-groups.json"

        have_cmd() {
          command -v "$1" >/dev/null 2>&1
        }

        die() {
          printf 'node: %s\n' "$*" >&2
          exit 1
        }

        require_flake_dir() {
          [[ -d "$NODE_FLAKE_PATH" ]] || die "flake local ausente em $NODE_FLAKE_PATH"
        }

        require_git_repo() {
          have_cmd git || die "git nao disponivel no PATH"
          git -C "$NODE_FLAKE_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
            || die "checkout operacional nao e um repositorio Git funcional: $NODE_FLAKE_PATH"
        }

        require_runtime_file() {
          local file_name="$1"
          local path="$NODE_RUNTIME_ROOT/$file_name"
          [[ -f "$path" ]] || die "NODE runtime ausente: srv-rag exige runtime local valido em $NODE_RUNTIME_ROOT (faltando $file_name)"
        }

        resolve_boot_device() {
          nix eval --impure --raw --expr \
            "let flake = builtins.getFlake \"git+file://$NODE_FLAKE_PATH\"; in flake.nixosConfigurations.\"$NODE_TARGET_HOST\".config.fileSystems.\"/boot\".device"
        }

        validate_runtime_guard() {
          require_flake_dir
          require_runtime_file "params.nix"
          require_runtime_file "hardware-configuration.nix"

          local boot_device
          boot_device="$(resolve_boot_device 2>/dev/null || true)"
          [[ -n "$boot_device" ]] || die "NODE runtime invalido: nao foi possivel resolver /boot para $NODE_INSTALLABLE"

          case "$boot_device" in
            /dev/disk/by-label/ESP|/dev/disk/by-label/nixos)
              die "NODE runtime invalido: /boot ainda resolve para placeholder ($boot_device)"
              ;;
          esac
        }

        run_as_root() {
          if (( EUID == 0 )); then
            "$@"
            return 0
          fi

          if have_cmd sudo; then
            sudo "$@"
            return 0
          fi

          die "requer root ou sudo para executar: $*"
        }

        reexec_as_root() {
          if (( EUID == 0 )); then
            return 0
          fi

          if have_cmd sudo; then
            exec sudo --preserve-env=NODE_FLAKE_PATH,NODE_TARGET_HOST "$0" "$@"
          fi

          die "requer root ou sudo para executar: $*"
        }

        ensure_storage_dirs() {
          mkdir -p "$NODE_HOME_BASE" "$NODE_HOME_ARCHIVE_BASE" "$NODE_HOME_SNAPSHOT_BASE"
        }

        ensure_client_users_catalog() {
          mkdir -p "$NODE_RUNTIME_ROOT"
          if [[ ! -s "$NODE_CLIENT_USERS_FILE" ]]; then
            printf '{}\n' > "$NODE_CLIENT_USERS_FILE"
          fi
        }

        hash_password() {
          local plain="$1"
          openssl passwd -6 "$plain"
        }

        is_btrfs_home_storage() {
          [[ "$(findmnt -n -o FSTYPE --target "$NODE_HOME_BASE" 2>/dev/null || true)" == "btrfs" ]]
        }

        require_home_storage() {
          [[ -d "$NODE_HOME_BASE" ]] || die "storage de homes ausente em $NODE_HOME_BASE"
          mountpoint -q "$NODE_HOME_BASE" || die "home persistente nao esta montada em $NODE_HOME_BASE"
        }

        home_path_for_user() {
          printf '%s/%s\n' "$NODE_HOME_BASE" "$1"
        }

        home_meta_path() {
          printf '%s/%s\n' "$(home_path_for_user "$1")" "$NODE_HOME_META_FILE"
        }

        validate_username() {
          local user_name="$1"
          [[ "$user_name" =~ ^[a-z_][a-z0-9_-]{0,30}$ ]] || \
            die "nome de usuario invalido: $user_name"
        }

        normalize_quota() {
          local raw_quota="$1"
          [[ -n "$raw_quota" ]] || die "quota ausente"
          numfmt --from=iec "$raw_quota" >/dev/null 2>&1 || die "quota invalida: $raw_quota"
          printf '%s\n' "$raw_quota"
        }

        quota_bytes() {
          numfmt --from=iec "$1"
        }

        human_bytes() {
          numfmt --to=iec-i --suffix=B "$1"
        }

        read_meta_value() {
          local user_name="$1"
          local key="$2"
          local meta_path
          meta_path="$(home_meta_path "$user_name")"
          [[ -f "$meta_path" ]] || return 0
          awk -F= -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1); exit }' "$meta_path"
        }

        write_user_meta() {
          local user_name="$1"
          local quota="$2"
          local home_path
          home_path="$(home_path_for_user "$user_name")"
          cat > "$(home_meta_path "$user_name")" <<EOF
    USER=$user_name
    HOME=$home_path
    QUOTA=$quota
    UPDATED_AT=$(date --iso-8601=seconds)
    EOF
          chown "$user_name:users" "$(home_meta_path "$user_name")"
          chmod 0640 "$(home_meta_path "$user_name")"
        }

        server_groups_for_user() {
          local user_name="$1"
          id -Gn "$user_name" 2>/dev/null | tr ' ' '\n'
        }

        is_builtin_client_group() {
          local group_name="$1"

          case "$group_name" in
            ""|audio|nogroup|root|users|video|wheel)
              return 0
              ;;
            *)
              return 1
              ;;
          esac
        }

        client_extra_groups_json_for_user() {
          local user_name="$1"

          {
            printf '%s\n' "video"
            printf '%s\n' "audio"
            while IFS= read -r group_name; do
              case "$group_name" in
                ""|"$user_name"|nogroup|root|users|video|audio)
                  continue
                  ;;
                *)
                  printf '%s\n' "$group_name"
                  ;;
              esac
            done < <(server_groups_for_user "$user_name")
          } | jq -Rsc 'split("\n") | map(select(length > 0)) | unique'
        }

        client_group_gids_json_for_user() {
          local user_name="$1"

          while IFS= read -r group_name; do
            local gid

            [[ "$group_name" != "$user_name" ]] || continue
            if is_builtin_client_group "$group_name"; then
              continue
            fi

            gid="$(getent group "$group_name" | cut -d: -f3 || true)"
            [[ -n "$gid" ]] || continue
            printf '%s:%s\n' "$group_name" "$gid"
          done < <(server_groups_for_user "$user_name") | jq -Rsc '
            split("\n")
            | map(select(length > 0) | split(":"))
            | map({ key: .[0], value: (.[1] | tonumber) })
            | from_entries
          '
        }

        shadow_hash_for_user() {
          local user_name="$1"
          getent shadow "$user_name" | cut -d: -f2
        }

        update_client_user_catalog() {
          local user_name="$1"
          local uid="$2"
          local hashed_password="$3"
          local extra_groups_json
          local group_gids_json
          local tmp_json

          ensure_client_users_catalog
          extra_groups_json="$(client_extra_groups_json_for_user "$user_name")"
          group_gids_json="$(client_group_gids_json_for_user "$user_name")"
          tmp_json="$(mktemp)"
          jq \
            --arg user "$user_name" \
            --argjson uid "$uid" \
            --arg hash "$hashed_password" \
            --argjson extraGroups "$extra_groups_json" \
            --argjson groupGids "$group_gids_json" \
            '
              (.[$user] // {}) as $existing
              | .[$user] = ($existing + {
                  uid: $uid,
                  description: ($existing.description // ("NODE User " + $user)),
                  hashedPassword: $hash,
                  extraGroups: $extraGroups,
                  groupGids: $groupGids
                })
            ' \
            "$NODE_CLIENT_USERS_FILE" > "$tmp_json"
          mv "$tmp_json" "$NODE_CLIENT_USERS_FILE"
          chmod 0644 "$NODE_CLIENT_USERS_FILE"
        }

        sync_client_user_catalog_entry() {
          local user_name="$1"
          local uid
          local hashed_password

          id -u "$user_name" >/dev/null 2>&1 || return 0
          uid="$(id -u "$user_name")"
          hashed_password="$(jq -r --arg user "$user_name" '.[$user].hashedPassword // empty' "$NODE_CLIENT_USERS_FILE" 2>/dev/null || true)"
          [[ -n "$hashed_password" ]] || hashed_password="$(shadow_hash_for_user "$user_name" || true)"
          [[ -n "$hashed_password" ]] || hashed_password="!"
          update_client_user_catalog "$user_name" "$uid" "$hashed_password"
        }

        remove_client_user_catalog_entry() {
          local user_name="$1"
          local tmp_json

          ensure_client_users_catalog
          tmp_json="$(mktemp)"
          jq --arg user "$user_name" 'del(.[$user])' "$NODE_CLIENT_USERS_FILE" > "$tmp_json"
          mv "$tmp_json" "$NODE_CLIENT_USERS_FILE"
          chmod 0644 "$NODE_CLIENT_USERS_FILE"
        }

        enable_btrfs_quotas_if_needed() {
          if ! is_btrfs_home_storage; then
            die "storage de homes em $NODE_HOME_BASE nao e btrfs; quotas BTRFS indisponiveis"
          fi

          btrfs quota enable "$NODE_HOME_BASE" >/dev/null 2>&1 || true
        }

        ensure_user_system_account() {
          local user_name="$1"
          local home_path="$2"

          if id -u "$user_name" >/dev/null 2>&1; then
            return 0
          fi

          useradd -M -d "$home_path" -s /run/current-system/sw/bin/bash -U "$user_name"
        }

        bootstrap_home_tree() {
          local user_name="$1"
          local home_path="$2"

          mkdir -p \
            "$home_path/.config" \
            "$home_path/.cache" \
            "$home_path/.local/share" \
            "$home_path/Desktop" \
            "$home_path/Documents" \
            "$home_path/Downloads" \
            "$home_path/Music" \
            "$home_path/Pictures" \
            "$home_path/Videos"
          chown -R "$user_name:users" "$home_path"
          chmod 0700 "$home_path" "$home_path/.config" "$home_path/.cache" "$home_path/.local"
          chmod 0750 "$home_path/.local/share"
        }

        ensure_home_exists() {
          local user_name="$1"
          local home_path="$2"

          if [[ -d "$home_path" ]]; then
            return 0
          fi

          if is_btrfs_home_storage; then
            btrfs subvolume create "$home_path" >/dev/null
          else
            mkdir -p "$home_path"
          fi
        }

        apply_home_quota() {
          local user_name="$1"
          local quota="$2"
          local home_path
          home_path="$(home_path_for_user "$user_name")"

          enable_btrfs_quotas_if_needed
          btrfs qgroup limit "$quota" "$home_path"
          write_user_meta "$user_name" "$quota"
        }

        home_usage_bytes() {
          local user_name="$1"
          local home_path
          home_path="$(home_path_for_user "$user_name")"
          du -sb "$home_path" 2>/dev/null | awk '{print $1}'
        }

        print_user_row() {
          local user_name="$1"
          local home_path quota usage pct quota_b
          home_path="$(home_path_for_user "$user_name")"
          quota="$(read_meta_value "$user_name" QUOTA)"
          usage="$(home_usage_bytes "$user_name")"
          quota_b=0
          pct="-"
          if [[ -n "$quota" ]]; then
            quota_b="$(quota_bytes "$quota")"
            if (( quota_b > 0 )); then
              pct="$(( usage * 100 / quota_b ))%"
            fi
          else
            quota="-"
          fi

          printf '%-16s %-10s %-10s %-8s %s\n' \
            "$user_name" \
            "$(human_bytes "$usage")" \
            "$quota" \
            "$pct" \
            "$home_path"
        }

        current_generation() {
          local profile_link
          profile_link="$(readlink "$NODE_SYSTEM_PROFILE" 2>/dev/null || true)"

          if [[ "$profile_link" =~ system-([0-9]+)-link$ ]]; then
            printf '%s\n' "''${BASH_REMATCH[1]}"
            return 0
          fi

          printf 'desconhecida\n'
        }

        run_flake_check() {
          require_flake_dir
          (
            cd "$NODE_FLAKE_PATH"
            nix flake check --impure "$@"
          )
        }

        run_nixos_rebuild() {
          local action="$1"
          shift || true

          have_cmd nixos-rebuild || die "nixos-rebuild nao disponivel no PATH"

          local -a cmd=(env NODE_ENFORCE_RUNTIME_GUARDS=1 nixos-rebuild "$action")
          case "$action" in
            switch|test)
              cmd+=(--impure --flake "$NODE_INSTALLABLE")
              ;;
            *)
              ;;
          esac

          if (( EUID == 0 )); then
            "''${cmd[@]}" "$@"
          else
            run_as_root "''${cmd[@]}" "$@"
          fi
        }

        clean_without_nh() {
          have_cmd nix-env || die "fallback de clean requer nix-env no PATH"
          have_cmd nix-collect-garbage || die "fallback de clean requer nix-collect-garbage no PATH"

          local cutoff_epoch
          cutoff_epoch="$(date -d "$NODE_KEEP_SINCE_DATE_EXPR" +%s)"

          local -a generations=()
          while read -r generation stamp_date stamp_time _; do
            [[ "$generation" =~ ^[0-9]+$ ]] || continue
            generations+=("$generation|$stamp_date $stamp_time")
          done < <(nix-env --list-generations --profile "$NODE_SYSTEM_PROFILE" 2>/dev/null || true)

          local total="''${#generations[@]}"
          local keep_start=0
          if (( total > NODE_KEEP_GENERATIONS )); then
            keep_start=$(( total - NODE_KEEP_GENERATIONS ))
          fi

          local -a deletable=()
          local entry generation stamp epoch
          local index=0
          for entry in "''${generations[@]}"; do
            generation="''${entry%%|*}"
            stamp="''${entry#*|}"

            if (( index < keep_start )); then
              epoch="$(date -d "$stamp" +%s 2>/dev/null || printf '0')"
              if (( epoch > 0 && epoch < cutoff_epoch )); then
                deletable+=("$generation")
              fi
            fi
            index=$(( index + 1 ))
          done

          if (( ''${#deletable[@]} > 0 )); then
            run_as_root nix-env --profile "$NODE_SYSTEM_PROFILE" --delete-generations "''${deletable[@]}"
          fi

          run_as_root nix-collect-garbage --delete-older-than "$NODE_KEEP_SINCE"
          if have_cmd nix-store; then
            run_as_root nix-store --optimise
          fi
        }

        cmd_switch() {
          validate_runtime_guard
          run_nixos_rebuild switch "$@"
        }

        cmd_test() {
          validate_runtime_guard
          run_nixos_rebuild test "$@"
        }

        cmd_rollback() {
          local generation="''${1:-}"
          if [[ -n "$generation" ]]; then
            shift
          fi

          [[ -z "$generation" ]] || die "rollback para geracao especifica requer nh; fallback suporta apenas a geracao anterior"
          have_cmd nixos-rebuild || die "nixos-rebuild nao disponivel no PATH"
          if (( EUID == 0 )); then
            nixos-rebuild switch --rollback "$@"
          else
            run_as_root nixos-rebuild switch --rollback "$@"
          fi
        }

        cmd_sync() {
          require_flake_dir
          reexec_as_root sync "$@"
          require_git_repo

          git -C "$NODE_FLAKE_PATH" fetch --all --prune
          git -C "$NODE_FLAKE_PATH" pull --ff-only
          if [[ -f "$NODE_FLAKE_PATH/.gitmodules" ]]; then
            git -C "$NODE_FLAKE_PATH" submodule sync --recursive
            git -C "$NODE_FLAKE_PATH" submodule update --init --recursive
          fi
        }

        cmd_update() {
          validate_runtime_guard
          reexec_as_root update "$@"

          (
            cd "$NODE_FLAKE_PATH"
            nix flake update
          )
          run_flake_check
          cmd_switch
        }

        cmd_clean() {
          if have_cmd nh; then
            nh clean all --keep "$NODE_KEEP_GENERATIONS" --keep-since "$NODE_KEEP_SINCE" --optimise "$@"
            return 0
          fi

          clean_without_nh
        }

        cmd_check() {
          run_flake_check "$@"
        }

        cmd_repl() {
          require_flake_dir
          exec nix repl --expr "builtins.getFlake \"$NODE_FLAKE_PATH\""
        }

        cmd_path() {
          printf '%s\n' "$NODE_FLAKE_PATH"
        }

        cmd_enter() {
          require_flake_dir
          cd "$NODE_FLAKE_PATH"
          exec "''${SHELL:-bash}" -l
        }

        cmd_user_add() {
          local user_name="''${1:-}"
          shift || true

          local quota=""
          local plain_password=""
          local password_hash="!"
          local group="default"
          while (( $# > 0 )); do
            case "$1" in
              --quota)
                quota="''${2:-}"
                shift 2
                ;;
              --password)
                plain_password="''${2:-}"
                shift 2
                ;;
              --password-hash)
                password_hash="''${2:-}"
                shift 2
                ;;
              --group)
                group="''${2:-}"
                shift 2
                ;;
              *)
                die "argumento desconhecido para user add: $1"
                ;;
            esac
          done

          [[ -n "$user_name" ]] || die "uso: node user add <nome> --quota 20G"
          quota="$(normalize_quota "$quota")"
          validate_username "$user_name"
          if [[ -n "$plain_password" ]]; then
            reexec_as_root user add "$user_name" --quota "$quota" --password "$plain_password"
          elif [[ "$password_hash" != "!" ]]; then
            reexec_as_root user add "$user_name" --quota "$quota" --password-hash "$password_hash"
          else
            reexec_as_root user add "$user_name" --quota "$quota"
          fi
          require_home_storage
          ensure_storage_dirs

          local home_path
          home_path="$(home_path_for_user "$user_name")"
          [[ ! -e "$home_path" ]] || die "usuario/home ja existe: $user_name ($home_path)"

          if [[ -n "$plain_password" ]]; then
            password_hash="$(hash_password "$plain_password")"
          fi

          ensure_user_system_account "$user_name" "$home_path"
          if [[ "$group" != "default" ]]; then
            getent group "$group" >/dev/null 2>&1 || die "grupo nao existe: $group"
            usermod -a -G "$group" "$user_name"
          fi
          ensure_home_exists "$user_name" "$home_path"
          bootstrap_home_tree "$user_name" "$home_path"
          apply_home_quota "$user_name" "$quota"
          update_client_user_catalog "$user_name" "$(id -u "$user_name")" "$password_hash"

          # Associar usuário ao grupo
          ensure_user_groups_catalog
          local tmp_json
          tmp_json="$(mktemp)"
          jq \
            --arg user "$user_name" \
            --arg group "$group" \
            '.user_groups |= (. // {}) | .user_groups[$user] = $group' \
            "$NODE_USER_GROUPS_FILE" > "$tmp_json"
          mv "$tmp_json" "$NODE_USER_GROUPS_FILE"

          printf 'usuario criado: %s\nhome: %s\nquota: %s\ngrupo: %s\n' "$user_name" "$home_path" "$quota" "$group"
          if [[ "$password_hash" == "!" ]]; then
            printf 'catalogo do cliente: conta criada bloqueada; use --password ou --password-hash para login grafico\n'
          else
            printf 'catalogo do cliente: atualizado em %s\n' "$NODE_CLIENT_USERS_FILE"
          fi
        }

        cmd_user_resize() {
          local user_name="''${1:-}"
          shift || true

          local quota=""
          local force=0
          while (( $# > 0 )); do
            case "$1" in
              --quota)
                quota="''${2:-}"
                shift 2
                ;;
              --force)
                force=1
                shift
                ;;
              *)
                die "argumento desconhecido para user resize: $1"
                ;;
            esac
          done

          [[ -n "$user_name" ]] || die "uso: node user resize <nome> --quota 40G [--force]"
          quota="$(normalize_quota "$quota")"
          if (( force == 1 )); then
            reexec_as_root user resize "$user_name" --quota "$quota" --force
          else
            reexec_as_root user resize "$user_name" --quota "$quota"
          fi

          local home_path usage current_quota usage_b quota_b
          home_path="$(home_path_for_user "$user_name")"
          [[ -d "$home_path" ]] || die "home ausente para $user_name: $home_path"

          usage_b="$(home_usage_bytes "$user_name")"
          quota_b="$(quota_bytes "$quota")"
          current_quota="$(read_meta_value "$user_name" QUOTA)"

          if (( usage_b > quota_b )) && (( force == 0 )); then
            die "nova quota $quota e menor que o uso atual $(human_bytes "$usage_b"); use --force se quiser prosseguir"
          fi

          apply_home_quota "$user_name" "$quota"
          printf 'usuario: %s\nuso atual: %s\nquota anterior: %s\nnova quota: %s\n' \
            "$user_name" \
            "$(human_bytes "$usage_b")" \
            "''${current_quota:--}" \
            "$quota"
        }

        cmd_user_list() {
          reexec_as_root user list "$@"
          require_home_storage
          ensure_storage_dirs

          printf '%-16s %-10s %-10s %-8s %s\n' "usuario" "uso" "quota" "% uso" "home"
          printf '%-16s %-10s %-10s %-8s %s\n' "-------" "---" "-----" "-----" "----"

          local path user_name
          shopt -s nullglob
          for path in "$NODE_HOME_BASE"/*; do
            [[ -d "$path" ]] || continue
            user_name="$(basename "$path")"
            [[ "$user_name" == ".archive" ]] && continue
            print_user_row "$user_name"
          done
          shopt -u nullglob
        }

        cmd_user_delete() {
          local user_name="''${1:-}"
          shift || true

          local archive=0
          while (( $# > 0 )); do
            case "$1" in
              --archive)
                archive=1
                shift
                ;;
              *)
                die "argumento desconhecido para user delete: $1"
                ;;
            esac
          done

          [[ -n "$user_name" ]] || die "uso: node user delete <nome> --archive"
          (( archive == 1 )) || die "delete sem --archive e proibido"
          reexec_as_root user delete "$user_name" --archive
          require_home_storage
          ensure_storage_dirs

          local home_path archive_path stamp
          home_path="$(home_path_for_user "$user_name")"
          [[ -d "$home_path" ]] || die "home ausente para $user_name: $home_path"
          stamp="$(date +%Y%m%d-%H%M%S)"
          archive_path="$NODE_HOME_ARCHIVE_BASE/$user_name-$stamp"

          if is_btrfs_home_storage; then
            btrfs subvolume snapshot -r "$home_path" "$NODE_HOME_SNAPSHOT_BASE/$user_name-$stamp" >/dev/null
          fi

          mv "$home_path" "$archive_path"
          userdel "$user_name" >/dev/null 2>&1 || true
          remove_client_user_catalog_entry "$user_name"

          printf 'usuario arquivado: %s\nhome arquivada em: %s\n' "$user_name" "$archive_path"
          if [[ -d "$NODE_HOME_SNAPSHOT_BASE/$user_name-$stamp" ]]; then
            printf 'snapshot: %s\n' "$NODE_HOME_SNAPSHOT_BASE/$user_name-$stamp"
          fi
        }

        cmd_user_doctor() {
          local user_name="''${1:-}"
          [[ -n "$user_name" ]] || die "uso: node user doctor <nome>"
          reexec_as_root user doctor "$user_name"
          require_home_storage

          local home_path quota usage
          home_path="$(home_path_for_user "$user_name")"
          [[ -d "$home_path" ]] || die "home ausente para $user_name: $home_path"
          quota="$(read_meta_value "$user_name" QUOTA)"
          usage="$(home_usage_bytes "$user_name")"

          cat <<EOF
    usuario: $user_name
    home: $home_path
    filesystem: $(findmnt -n -o FSTYPE --target "$home_path")
    owner: $(stat -c '%U:%G' "$home_path")
    modo: $(stat -c '%a' "$home_path")
    uso: $(human_bytes "$usage")
    quota: ''${quota:--}
    catalogo_cliente: $(jq -r --arg user "$user_name" 'if has($user) then "presente" else "ausente" end' "$NODE_CLIENT_USERS_FILE" 2>/dev/null || echo "ausente")
    montagem:
    $(findmnt -n --target "$home_path" || true)
    qgroup:
    $(btrfs qgroup show -f "$home_path" 2>/dev/null || echo "indisponivel")
    EOF
        }

        cmd_user_quota_sync() {
          reexec_as_root user quota-sync "$@"
          require_home_storage
          ensure_storage_dirs
          enable_btrfs_quotas_if_needed

          local path user_name quota
          shopt -s nullglob
          for path in "$NODE_HOME_BASE"/*; do
            [[ -d "$path" ]] || continue
            user_name="$(basename "$path")"
            [[ "$user_name" == ".archive" ]] && continue
            quota="$(read_meta_value "$user_name" QUOTA)"
            [[ -n "$quota" ]] || continue
            btrfs qgroup limit "$quota" "$path"
          done
          shopt -u nullglob

          echo "quotas sincronizadas com os metadados de home"
        }

        # ─────────────────────────────────────────────────────────────────────────
        # FUNÇÕES DE GRUPO E SETOR
        # ─────────────────────────────────────────────────────────────────────────

        ensure_user_groups_catalog() {
          mkdir -p "$NODE_RUNTIME_ROOT"
          if [[ ! -s "$NODE_USER_GROUPS_FILE" ]]; then
            printf '{}\n' > "$NODE_USER_GROUPS_FILE"
          fi
        }

        ensure_storage_sectors() {
          mkdir -p "$NODE_STORAGE_BASE" "$NODE_STORAGE_ARCHIVE"
        }

        list_sector_storage() {
          ensure_storage_sectors
          printf '%-16s %-30s %s\n' "setor" "armazenamento" "uso"
          printf '%-16s %-30s %s\n' "-----" "-------------" "---"
          shopt -s nullglob
          for sector_path in "$NODE_STORAGE_BASE"/*; do
            [[ -d "$sector_path" ]] || continue
            sector="$(basename "$sector_path")"
            [[ "$sector" == ".archive" ]] && continue
            size="$(du -sh "$sector_path" 2>/dev/null | awk '{print $1}')"
            printf '%-16s %-30s %s\n' "$sector" "$sector_path" "$size"
          done
          shopt -u nullglob
        }

        cmd_user_activity() {
          local user_name="''${1:-}"
          [[ -n "$user_name" ]] || die "uso: node user activity <nome>"

          [[ -f "$NODE_AUDIT_FILE" ]] || {
            printf 'sem registro de auditoria para %s\n' "$user_name"
            return 0
          }

          jq --arg user "$user_name" '.sessions[$user] // []' "$NODE_AUDIT_FILE" 2>/dev/null | \
            jq -r '.[] | "[\(.timestamp)] [\(.action)] tty=\(.tty) ip=\(.ip)"'
        }

        cmd_group_add() {
          local group_name="''${1:-}"
          [[ -n "$group_name" ]] || die "uso: node group add <nome> [--description DESC] [--storage-quota 100G]"
          shift || true

          local description=""
          local quota="100G"
          while (( $# > 0 )); do
            case "$1" in
              --description)
                description="''${2:-}"
                shift 2
                ;;
              --storage-quota)
                quota="''${2:-}"
                shift 2
                ;;
              *)
                die "argumento desconhecido para group add: $1"
                ;;
            esac
          done

          [[ -n "$description" ]] || description="NODE Group $group_name"
          quota="$(normalize_quota "$quota")"
          reexec_as_root group add "$group_name" --description "$description" --storage-quota "$quota"
          ensure_storage_sectors

          local group_storage="$NODE_STORAGE_BASE/$group_name"
          if ! getent group "$group_name" >/dev/null 2>&1; then
            groupadd -r "$group_name"
          fi
          local group_gid
          group_gid="$(getent group "$group_name" | cut -d: -f3)"
          mkdir -p "$group_storage"
          chown "root:$group_name" "$group_storage" 2>/dev/null || true
          chmod 0750 "$group_storage"

          # Guardar metadata do grupo
          cat > "$group_storage/.group-meta" <<EOF
    GROUP=$group_name
    DESCRIPTION=$description
    GID=$group_gid
    QUOTA=$quota
    CREATED_AT=$(date --iso-8601=seconds)
    EOF
          chmod 0640 "$group_storage/.group-meta"

          # Atualizar catalog de grupos
          ensure_user_groups_catalog
          local tmp_json
          tmp_json="$(mktemp)"
          jq \
            --arg group "$group_name" \
            --arg desc "$description" \
            --arg path "$group_storage" \
            --arg quota "$quota" \
            --argjson gid "$group_gid" \
            '.|= . // {} | .[$group] = {description: $desc, storagePath: $path, quota: $quota, gid: $gid, created_at: now|todate}' \
            "$NODE_USER_GROUPS_FILE" > "$tmp_json"
          mv "$tmp_json" "$NODE_USER_GROUPS_FILE"
          chmod 0644 "$NODE_USER_GROUPS_FILE"

          printf 'grupo criado: %s\narmazenamento: %s\ngid: %s\nquota: %s\n' "$group_name" "$group_storage" "$group_gid" "$quota"
        }

        cmd_group_list() {
          ensure_storage_sectors
          list_sector_storage
        }

        cmd_group_delete() {
          local group_name="''${1:-}"
          [[ -n "$group_name" ]] || die "uso: node group delete <nome> --archive"
          shift || true

          # Impedir deleção do grupo admin (permanente)
          [[ "$group_name" != "admin" ]] || die "grupo 'admin' e permanente e nao pode ser deletado"

          local archive=0
          while (( $# > 0 )); do
            case "$1" in
              --archive)
                archive=1
                shift
                ;;
              *)
                die "argumento desconhecido para group delete: $1"
                ;;
            esac
          done

          (( archive == 1 )) || die "delete sem --archive e proibido"
          reexec_as_root group delete "$group_name" --archive
          ensure_storage_sectors

          local group_storage="$NODE_STORAGE_BASE/$group_name"
          [[ -d "$group_storage" ]] || die "storage do grupo ausente: $group_storage"

          local timestamp
          timestamp="$(date +%Y%m%d-%H%M%S)"
          mv "$group_storage" "$NODE_STORAGE_ARCHIVE/$group_name-$timestamp"

          # Remover do catalog
          ensure_user_groups_catalog
          local tmp_json
          tmp_json="$(mktemp)"
          jq --arg group "$group_name" 'del(.[$group])' "$NODE_USER_GROUPS_FILE" > "$tmp_json"
          mv "$tmp_json" "$NODE_USER_GROUPS_FILE"

          printf 'grupo arquivado: %s\narmazenamento em: %s\n' "$group_name" "$NODE_STORAGE_ARCHIVE/$group_name-$timestamp"
        }

        cmd_group_permissions() {
          local group_name="''${1:-}"
          [[ -n "$group_name" ]] || die "uso: node group permissions <nome>"

          local group_storage="$NODE_STORAGE_BASE/$group_name"
          [[ -d "$group_storage" ]] || die "grupo nao existe: $group_name"

          local perms_file="$group_storage/.group-permissions"
          
          if [[ -f "$perms_file" ]]; then
            printf "Permissões do grupo '%s':\n" "$group_name"
            printf "  Arquivo: %s\n" "$perms_file"
            printf "  Conteúdo:\n"
            cat "$perms_file" | sed 's/^/    /'
          else
            # Se não existe, criar padrão
            printf "Permissões do grupo '%s':\n" "$group_name"
            printf "  Modo: 0750 (padrão)\n"
            printf "  Members: nenhum (todos com acesso ao grupo podem ver)\n"
          fi

          local stat_info
          stat_info="$(stat -c 'Owner: %U:%G | Permissões: %a (%A)' "$group_storage")"
          printf "  Filesystem:\n    %s\n" "$stat_info"
        }

        cmd_group_chmod() {
          local group_name="''${1:-}"
          local perms="''${2:-}"
          [[ -n "$group_name" && -n "$perms" ]] || die "uso: node group chmod <nome> <perms> (ex: 0750 ou g+rw)"

          local group_storage="$NODE_STORAGE_BASE/$group_name"
          [[ -d "$group_storage" ]] || die "grupo nao existe: $group_name"

          reexec_as_root chmod "$perms" "$group_storage"

          # Atualizar arquivo de permissões
          local perms_file="$group_storage/.group-permissions"
          local new_mode
          new_mode="$(stat -c '%a' "$group_storage")"
          
          printf 'MODE=%s\nMEMBERS=[]\nUPDATED_AT=%s\n' "$new_mode" "$(date --iso-8601=seconds)" > "$perms_file"
          chmod 0644 "$perms_file"

          printf 'permissoes atualizadas: %s => %s\n' "$group_name" "$new_mode"
        }

        cmd_group_members() {
          local group_name="''${1:-}"
          [[ -n "$group_name" ]] || die "uso: node group members <nome> [--add USER] [--remove USER]"
          shift || true

          local group_storage="$NODE_STORAGE_BASE/$group_name"
          [[ -d "$group_storage" ]] || die "grupo nao existe: $group_name"

          local add_user="" del_user=""
          while (( $# > 0 )); do
            case "$1" in
              --add)
                add_user="''${2:-}"
                [[ -n "$add_user" ]] || die "--add requer nome de usuario"
                shift 2
                ;;
              --remove)
                del_user="''${2:-}"
                [[ -n "$del_user" ]] || die "--remove requer nome de usuario"
                shift 2
                ;;
              *)
                die "argumento desconhecido: $1"
                ;;
            esac
          done

          local perms_file="$group_storage/.group-permissions"

          # Se não existe arquivo, criar
          if [[ ! -f "$perms_file" ]]; then
            printf 'MODE=0750\nMEMBERS=[]\n' > "$perms_file"
            chmod 0644 "$perms_file"
          fi

          if [[ -n "$add_user" ]]; then
            # Validar que usuário existe
            id "$add_user" >/dev/null 2>&1 || die "usuario nao existe: $add_user"
            
            # Adicionar ao grupo
            reexec_as_root usermod -a -G "$group_name" "$add_user"
            sync_client_user_catalog_entry "$add_user"
            printf 'usuario adicionado ao grupo: %s -> %s\n' "$add_user" "$group_name"
          fi

          if [[ -n "$del_user" ]]; then
            # Remover do grupo
            reexec_as_root gpasswd -d "$del_user" "$group_name" 2>/dev/null || true
            sync_client_user_catalog_entry "$del_user"
            printf 'usuario removido do grupo: %s <- %s\n' "$del_user" "$group_name"
          fi

          # Listar membros atuais
          printf "Membros atuais de '%s':\n" "$group_name"
          getent group "$group_name" | cut -d: -f4 | tr ',' '\n' | grep -v '^$' | while read -r member; do
            printf "  - %s\n" "$member"
          done
        }

        cmd_group_ensure_defaults() {
          local storage_base="/srv/data/storage"
          local admin_path="$storage_base/admin"
          local public_path="$storage_base/public"
          local archive_path="$storage_base/.archive"
          
          reexec_as_root group ensure-defaults
          ensure_storage_sectors
          
          # Garantir grupo admin (GID 3000)
          if ! getent group admin >/dev/null 2>&1; then
            groupadd -g 3000 -r admin
            printf 'grupo admin criado (GID 3000)\n'
          fi
          
          # Garantir grupo public (GID 3001)
          if ! getent group public >/dev/null 2>&1; then
            groupadd -g 3001 -r public
            printf 'grupo public criado (GID 3001)\n'
          fi
          
          # Garantir storage admin
          mkdir -p "$admin_path"
          chown root:admin "$admin_path" 2>/dev/null || true
          chmod 0750 "$admin_path"
          
          if [[ ! -f "$admin_path/.group-meta" ]]; then
            cat > "$admin_path/.group-meta" <<'EOF'
    GROUP=admin
    DESCRIPTION=NODE Storage Admin - Permanent
    GID=3000
    QUOTA=1T
    CREATED_AT=$(date --iso-8601=seconds)
    PERMANENT=true
    EOF
            chmod 0640 "$admin_path/.group-meta"
          fi
          
          # Garantir storage public
          mkdir -p "$public_path"
          chown root:public "$public_path" 2>/dev/null || true
          chmod 0770 "$public_path"
          
          if [[ ! -f "$public_path/.group-meta" ]]; then
            cat > "$public_path/.group-meta" <<'EOF'
    GROUP=public
    DESCRIPTION=NODE Storage Public - Permanent
    GID=3001
    QUOTA=1T
    CREATED_AT=$(date --iso-8601=seconds)
    PERMANENT=true
    EOF
            chmod 0640 "$public_path/.group-meta"
          fi
          
          # Garantir .archive com permissões corretas (0700)
          mkdir -p "$archive_path"
          chmod 0700 "$archive_path"
          
          printf 'grupos base garantidos: admin (GID 3000), public (GID 3001), archive criado\n'
        }

        cmd_group() {
          local action="''${1:-}"
          [[ -n "$action" ]] || die "uso: node group <add|list|delete|chmod|members|permissions|ensure-defaults> ..."
          shift || true

          case "$action" in
            add) cmd_group_add "$@" ;;
            list) cmd_group_list "$@" ;;
            delete) cmd_group_delete "$@" ;;
            chmod) cmd_group_chmod "$@" ;;
            members) cmd_group_members "$@" ;;
            permissions) cmd_group_permissions "$@" ;;
            ensure-defaults) cmd_group_ensure_defaults "$@" ;;
            *)
              die "subcomando desconhecido para group: $action"
              ;;
          esac
        }

        cmd_branding_doctor() {
          cat <<EOF
    sddm_theme: $(grep -R \"^Current=\" /etc/sddm.conf* /run/current-system/sw/etc/sddm.conf* 2>/dev/null | head -n 1 || echo \"nao encontrado\")
    plymouth_theme: $(grep -R \"^Theme=\" /etc/plymouth /run/current-system/sw/etc/plymouth 2>/dev/null | head -n 1 || echo \"nao encontrado\")
    sddm_theme_dir: $(find /run/current-system/sw/share/sddm/themes -maxdepth 1 -mindepth 1 -type d | sed -n '1,20p')
    plasma_look_and_feel_dirs: $(find /run/current-system/sw/share/plasma/look-and-feel -maxdepth 1 -mindepth 1 -type d 2>/dev/null | grep -E 'node|org\.node' | sed -n '1,20p' || true)
    plasma_desktoptheme_dirs: $(find /run/current-system/sw/share/plasma/desktoptheme -maxdepth 1 -mindepth 1 -type d 2>/dev/null | grep -E 'node|org\.node' | sed -n '1,20p' || true)
    plasma_color_schemes: $(find /run/current-system/sw/share/color-schemes -maxdepth 1 -type f -name 'NODE*.colors' 2>/dev/null | sed -n '1,20p' || true)
    plasma_wallpaper_dirs: $(find /run/current-system/sw/share/wallpapers -maxdepth 1 -mindepth 1 -type d 2>/dev/null | grep -E 'node|org\.node' | sed -n '1,20p' || true)
    EOF
        }

        cmd_client_session_doctor() {
          reexec_as_root client session-doctor "$@"
          cat <<EOF
    cliente/current manifest: $(sed -nE 's/.*\"id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\1/p' /srv/data/images/current/manifest.json 2>/dev/null | head -n1 || echo indisponivel)
    nfs exports:
    $(exportfs -v 2>/dev/null | sed -n '1,120p' || true)
    inventario:
    $(sed -n '1,200p' /etc/node-inventory/clients.nix 2>/dev/null || true)
    EOF
        }

        cmd_status() {
          local directory_exists="nao"
          local rebuild_available="nao"
          local runtime_root="$NODE_RUNTIME_ROOT"

          [[ -d "$NODE_FLAKE_PATH" ]] && directory_exists="sim"
          have_cmd nixos-rebuild && rebuild_available="sim"

          cat <<EOF
    flake_path: $NODE_FLAKE_PATH
    target_host: $NODE_TARGET_HOST
    runtime_root: $runtime_root
    directory_exists: $directory_exists
    current_generation: $(current_generation)
    nixos_rebuild_available: $rebuild_available
    EOF
        }

        cmd_help() {
          cat <<EOF
    Uso: node <subcomando>

    Subcomandos:
      sync       Sincroniza o checkout operacional via Git e submodulos
      switch     Aplica a configuracao do host srv-rag
      test       Aplica sem fixar no proximo boot
      rollback   Volta para a geracao anterior
      update     Atualiza inputs do flake.lock, valida e aplica
      clean      Limpa geracoes antigas com politica conservadora
      check      Executa nix flake check em /etc/node
      repl       Abre um REPL util para o flake local
      path       Mostra o caminho operacional do flake
      enter      Entra em /etc/node com shell interativo
      user       Gerencia homes persistentes e quotas em /srv/data/home
      branding   Diagnostica branding do servidor/cliente
      client     Diagnostica sessao/home/publicacao do cliente
      status     Mostra caminho, host, geracao e disponibilidade de nh/fallback
      help       Mostra esta ajuda

    Contexto fixo:
      flake path: /etc/node
      runtime   : /var/lib/node/runtime
      host alvo : srv-rag

    Operacao de usuarios:
      node user add <nome> --quota 20G
      node user resize <nome> --quota 40G [--force]
      node user list
      node user delete <nome> --archive
      node user doctor <nome>
      node user quota-sync
    EOF
        }

        cmd_user() {
          local action="''${1:-}"
          [[ -n "$action" ]] || die "uso: node user <add|resize|list|delete|doctor|quota-sync|activity> ..."
          shift || true

          case "$action" in
            add) cmd_user_add "$@" ;;
            resize) cmd_user_resize "$@" ;;
            list) cmd_user_list "$@" ;;
            delete) cmd_user_delete "$@" ;;
            doctor) cmd_user_doctor "$@" ;;
            quota-sync) cmd_user_quota_sync "$@" ;;
            activity) cmd_user_activity "$@" ;;
            *)
              die "subcomando desconhecido para user: $action"
              ;;
          esac
        }

        cmd_branding() {
          local action="''${1:-doctor}"
          shift || true
          case "$action" in
            doctor) cmd_branding_doctor "$@" ;;
            *)
              die "subcomando desconhecido para branding: $action"
              ;;
          esac
        }

        cmd_client() {
          local action="''${1:-session-doctor}"
          shift || true
          case "$action" in
            session-doctor) cmd_client_session_doctor "$@" ;;
            *)
              die "subcomando desconhecido para client: $action"
              ;;
          esac
        }

        subcommand="''${1:-help}"
        if (( $# > 0 )); then
          shift
        fi

        case "$subcommand" in
          sync) cmd_sync "$@" ;;
          switch) cmd_switch "$@" ;;
          test) cmd_test "$@" ;;
          rollback) cmd_rollback "$@" ;;
          update) cmd_update "$@" ;;
          clean) cmd_clean "$@" ;;
          check) cmd_check "$@" ;;
          repl) cmd_repl "$@" ;;
          path) cmd_path "$@" ;;
          enter) cmd_enter "$@" ;;
          user) cmd_user "$@" ;;
          group) cmd_group "$@" ;;
          branding) cmd_branding "$@" ;;
          client) cmd_client "$@" ;;
          status) cmd_status "$@" ;;
          help|-h|--help) cmd_help ;;
          *)
            die "subcomando desconhecido: $subcommand"
            ;;
        esac
  '';
}
