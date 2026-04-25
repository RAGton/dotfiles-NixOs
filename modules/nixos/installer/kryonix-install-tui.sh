#!/usr/bin/env bash
set -euo pipefail

# TUI em terminal puro p/ instalar hosts do flake.
# - sem dialog
# - menus numerados (portável em TTY/SSH/serial)

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$LIB_DIR/tui-lib.sh"

sys::require_root

ui::title "Bem-vindo ao NixOS Host Manager (ISO)"

while true; do
  choice=$(ui::menu "Menu inicial" \
    "Instalar host existente" \
    "Criar novo host (esqueleto)" \
    "Sair")

  case "$choice" in
    1)
      # Instalar host existente
      FLAKE_SRC="@FLAKE_SRC@"
      WORKDIR="/tmp/kryonix-nixos"
      rm -rf "$WORKDIR"
      mkdir -p "$WORKDIR"
      cp -a "$FLAKE_SRC/." "$WORKDIR/"

      mapfile -t hosts < <(sys::list_hosts "$WORKDIR/hosts")
      if [ "${#hosts[@]}" -eq 0 ]; then
        echo "Nenhum host encontrado em $WORKDIR/hosts" >&2
        ui::pause
        continue
      fi

      ui::title "Selecione o host"
      local_i=1
      for h in "${hosts[@]}"; do
        printf '[%d] %s\n' "$local_i" "$h"
        local_i=$((local_i+1))
      done
      printf '\nEscolha: '
      read -r host_idx
      if ! [[ "$host_idx" =~ ^[0-9]+$ ]] || [ "$host_idx" -lt 1 ] || [ "$host_idx" -gt "${#hosts[@]}" ]; then
        echo "Opção inválida." >&2
        ui::pause
        continue
      fi
      HOST="${hosts[$((host_idx-1))]}"

      # Selecionar disco
      mapfile -t disks < <(sys::list_disks_pretty)
      if [ "${#disks[@]}" -eq 0 ]; then
        echo "Nenhum disco detectado." >&2
        ui::pause
        continue
      fi

      ui::title "Selecione o disco (será APAGADO)"
      local_i=1
      for d in "${disks[@]}"; do
        IFS='|' read -r path model size <<<"$d"
        printf '[%d] %s  (%s, %s)\n' "$local_i" "$path" "${model:-unknown}" "$size"
        local_i=$((local_i+1))
      done
      printf '\nEscolha: '
      read -r disk_idx
      if ! [[ "$disk_idx" =~ ^[0-9]+$ ]] || [ "$disk_idx" -lt 1 ] || [ "$disk_idx" -gt "${#disks[@]}" ]; then
        echo "Opção inválida." >&2
        ui::pause
        continue
      fi
      IFS='|' read -r DISK _ _ <<<"${disks[$((disk_idx-1))]}"

      ui::title "Resumo"
      echo "Host: $HOST"
      echo "Disco: $DISK"
      echo
      echo "Isso vai apagar o disco e instalar o NixOS do seu flake.";

      if ! ui::confirm "Continuar?"; then
        echo "Cancelado."
        ui::pause
        continue
      fi

      # Reusar o instalador CLI atual
      kryonix-install --host "$HOST" --disk "$DISK"
      ui::pause
      ;;

    2)
      ui::title "Criar novo host (esqueleto)"
      echo "Importante: o flake tem outputs estáticos."
      echo "Este modo gera arquivos do host no disco alvo, mas você ainda precisa"
      echo "promover esse host no repo (editar flake.nix) para ter um output oficial."
      echo

      NEW_HOST=$(ui::prompt "Nome do novo host: ")
      if [ -z "$NEW_HOST" ]; then
        echo "Nome não pode ser vazio." >&2
        ui::pause
        continue
      fi

      # Seleciona disco (vamos criar um layout padrão BTRFS)
      mapfile -t disks < <(sys::list_disks_pretty)
      ui::title "Selecione o disco para preparar /mnt (será APAGADO)"
      local_i=1
      for d in "${disks[@]}"; do
        IFS='|' read -r path model size <<<"$d"
        printf '[%d] %s  (%s, %s)\n' "$local_i" "$path" "${model:-unknown}" "$size"
        local_i=$((local_i+1))
      done
      printf '\nEscolha: '
      read -r disk_idx
      if ! [[ "$disk_idx" =~ ^[0-9]+$ ]] || [ "$disk_idx" -lt 1 ] || [ "$disk_idx" -gt "${#disks[@]}" ]; then
        echo "Opção inválida." >&2
        ui::pause
        continue
      fi
      IFS='|' read -r DISK _ _ <<<"${disks[$((disk_idx-1))]}"

      USERNAME=$(ui::prompt "Usuário inicial (ex: rocha): ")
      if [ -z "$USERNAME" ]; then
        echo "Usuário não pode ser vazio." >&2
        ui::pause
        continue
      fi

      if ! ui::confirm "Confirmar: criar host '$NEW_HOST' e apagar '$DISK'?"; then
        echo "Cancelado."
        ui::pause
        continue
      fi

      # 1) Particionar/montar com um template simples BTRFS
      TMP_DISKS_NIX="/tmp/disko-$NEW_HOST.nix"
      cat >"$TMP_DISKS_NIX" <<EOF
{ lib, ... }:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "${DISK}";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "ef00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "fmask=0022" "dmask=0022" ];
            };
          };
          root = {
            size = "100%";
            type = "8300";
            content = {
              type = "btrfs";
              extraArgs = [ "-L" "RAIZ-NIXOS" ];
              subvolumes = {
                "@" = { mountpoint = "/"; mountOptions = [ "subvol=@" "compress=zstd" "noatime" ]; };
                "@home" = { mountpoint = "/home"; mountOptions = [ "subvol=@home" "compress=zstd" "noatime" ]; };
                "@nix" = { mountpoint = "/nix"; mountOptions = [ "subvol=@nix" "compress=zstd" "noatime" ]; };
                "@log" = { mountpoint = "/var/log"; mountOptions = [ "subvol=@log" "compress=zstd" "noatime" ]; };
                "@cache" = { mountpoint = "/var/cache"; mountOptions = [ "subvol=@cache" "compress=zstd" "noatime" ]; };
              };
            };
          };
        };
      };
    };
  };
}
EOF

      nix --experimental-features 'nix-command flakes' run "@DISKO_INPUT@" -- --mode disko "$TMP_DISKS_NIX"

      # 2) Gerar hardware-config
      nixos-generate-config --root /mnt

      # 3) Criar esqueleto de host em /mnt/etc/nixos (para o usuário versionar depois)
      HOST_DIR="/mnt/etc/nixos/hosts/$NEW_HOST"
      mkdir -p "$HOST_DIR"

      mv /mnt/etc/nixos/hardware-configuration.nix "$HOST_DIR/hardware-configuration.nix"

      cat >"$HOST_DIR/default.nix" <<EOF
{ inputs, hostname ? "${NEW_HOST}", nixosModules ? "./modules/nixos", lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = hostname;

  users.users.${USERNAME} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  services.openssh.enable = true;

  system.stateVersion = "25.11";
}
EOF

      cp "$TMP_DISKS_NIX" "$HOST_DIR/disks.nix"

      ui::title "Host gerado"
      echo "Criado em: $HOST_DIR"
      echo
      echo "Próximos passos (recomendado):"
      echo "1) Boot no sistema instalado ou use git para copiar esse diretório para o repo."
      echo "2) Adicione o host em flake.nix -> nixosConfigurations (mkNixosConfiguration)."
      echo "3) (Opcional) Adicione homeConfigurations também."
      echo
      echo "Se você quiser instalar agora, primeiro promova o host no flake e rode nixos-install."

      ui::pause
      ;;

    3)
      exit 0
      ;;
  esac

done
