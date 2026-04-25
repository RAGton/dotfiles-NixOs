# =============================================================================
# Módulo NixOS: ISO instaladora (kryonix-install)
#
# O que é:
# - Um conjunto pequeno de ajustes para uma ISO (live CD) que instala hosts
#   deste flake de forma repetível.
#
# Como usar (na ISO):
# - `kryonix-install --host inspiron --disk /dev/nvme0n1`
# =============================================================================
{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  # ISO: habilita flakes e ferramenta de instalação.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages =
    let
      kryonix-install = pkgs.writeShellApplication {
        name = "kryonix-install";
        runtimeInputs = with pkgs; [
          git
          nix
          jq
          fzf
          util-linux
          e2fsprogs
          btrfs-progs
        ];
        text = ''
          set -euo pipefail

          usage() {
            cat <<'EOF'
          kryonix-install: instalador automatizado para este flake

          Uso:
            kryonix-install --host <inspiron> --disk <DISPOSITIVO>

          Exemplos:
            kryonix-install --host inspiron --disk /dev/disk/by-id/nvme-...

          Segurança:
            - Isso APAGA o disco escolhido.
            - Prefira /dev/disk/by-id.
          EOF
          }

          HOST=""
          DISK=""

          while [ "$#" -gt 0 ]; do
            case "$1" in
              --host)
                shift
                [ "$#" -gt 0 ] || { echo "Faltou valor após --host" >&2; exit 2; }
                HOST="$1"
                shift
                ;;
              --disk)
                shift
                [ "$#" -gt 0 ] || { echo "Faltou valor após --disk" >&2; exit 2; }
                DISK="$1"
                shift
                ;;
              -h|--help)
                usage; exit 0;;
              *)
                echo "Argumento desconhecido: $1" >&2
                usage
                exit 2
                ;;
            esac
          done

          if [ -z "$HOST" ]; then
            echo "--host é obrigatório" >&2
            usage
            exit 2
          fi

          if [ -z "$DISK" ]; then
            echo "--disk é obrigatório" >&2
            echo
            echo "Discos detectados:" >&2
            lsblk -d -o NAME,MODEL,SIZE,TYPE | sed 's/^/  /' >&2 || true
            exit 2
          fi

          case "$HOST" in
            inspiron) ;;
            *)
              echo "Host inválido: $HOST" >&2
              echo "Hosts suportados: inspiron" >&2
              exit 2
              ;;
          esac

          if [ ! -b "$DISK" ]; then
            echo "Disco não existe ou não é block device: $DISK" >&2
            exit 2
          fi

          echo "============================================================"
          echo "ATENÇÃO: isso vai APAGAR o disco: $DISK"
          echo "Host alvo: $HOST"
          echo "============================================================"
          read -r "REPLY?Digite 'SIM' para continuar: "
          if [ "$REPLY" != "SIM" ]; then
            echo "Cancelado."
            exit 1
          fi

          # Flake do próprio repo, embutido na ISO.
          FLAKE_SRC="${inputs.self.outPath}"

          # Copiamos para um lugar gravável, porque o store é read-only.
          WORKDIR="/tmp/kryonix-nixos"
          rm -rf "$WORKDIR"
          mkdir -p "$WORKDIR"
          cp -a "$FLAKE_SRC/." "$WORKDIR/"

          list_hosts() {
            find "$WORKDIR/hosts" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
          }

          if [ "$HOST" = "list" ]; then
            list_hosts
            exit 0
          fi

          if [ ! -f "$WORKDIR/hosts/$HOST/default.nix" ]; then
            echo "Host inválido ou não encontrado em $WORKDIR/hosts: $HOST" >&2
            echo "Hosts disponíveis:" >&2
            list_hosts | sed 's/^/  /' >&2
            exit 2
          fi

          DISKS_NIX="$WORKDIR/hosts/$HOST/disks.nix"
          if [ ! -f "$DISKS_NIX" ]; then
            echo "Host $HOST não tem disks.nix (necessário p/ instalação automatizada)." >&2
            exit 1
          fi

          TMP_DISKS_NIX="/tmp/disko-$HOST.nix"
          echo "Gerando layout temporário do disko: $TMP_DISKS_NIX"
          sed -E "s#device = \\\"/dev/[^\\\"]+\\\";#device = \\\"$DISK\\\";#" "$DISKS_NIX" > "$TMP_DISKS_NIX"

          echo "Aplicando particionamento com disko (input pinado no flake)..."
          nix --experimental-features 'nix-command flakes' run "${inputs.disko}" -- --mode disko "$TMP_DISKS_NIX"

          echo "Instalando NixOS via flake..."
          nixos-install --no-root-password --flake "$WORKDIR#$HOST"

          echo "OK. Instalação concluída. Agora reinicie."
        '';
      };

      kryonix-install-tui = pkgs.writeShellApplication {
        name = "kryonix-install-tui";
        runtimeInputs =
          with pkgs;
          [
            bash
            coreutils
            util-linux
            nix
          ]
          ++ [ kryonix-install ];
        text = ''
          set -euo pipefail

          TMP_DIR="$(mktemp -d)"
          cleanup() { rm -rf "$TMP_DIR"; }
          trap cleanup EXIT

          # Copia scripts da TUI para um dir e injeta paths.
          cp -a ${./tui-lib.sh} "$TMP_DIR/tui-lib.sh"
          sed \
            -e "s|@FLAKE_SRC@|${inputs.self.outPath}|g" \
            -e "s|@DISKO_INPUT@|${inputs.disko}|g" \
            ${./kryonix-install-tui.sh} > "$TMP_DIR/kryonix-install-tui.sh"

          chmod +x "$TMP_DIR/kryonix-install-tui.sh"

          exec "$TMP_DIR/kryonix-install-tui.sh"
        '';
      };

    in
    [
      kryonix-install
      kryonix-install-tui
    ];

  networking.networkmanager.enable = lib.mkDefault true;
  services.fstrim.enable = lib.mkDefault false;
}
