# Layout de disco para o host "inspiron" (disko)
#
# ⚠️  IMPORTANTE: Este arquivo é usado pelo `disko` no Live CD para particionar
#     e formatar o NVMe. O SDA (RAG-DATA) NUNCA é tocado.
#
# Layout do NVMe (SM2P41C3 NVMe ADATA 512GB):
#   p1 = EFI  (1G)    → /boot
#   p2 = swap (16G)
#   p3 = btrfs SISTEMA (~260G) → @, @nix, @log, @cache, @containers, @libvirt,
#        @snapshots, @persist, @tmp  ← PODE FORMATAR SEMPRE
#   p4 = btrfs HOME   (~200G) → @home  ← NUNCA PERDE DADOS
#
# SDA (Kingston SA400S37 240G):
#   Partição única btrfs → /RAG-DATA  ← NÃO GERENCIADO PELO DISKO
#
# Uso no Live CD:
#   sudo nix run github:nix-community/disko -- --mode disko /caminho/disks.nix
#   (ou via nixos-install com disko integrado)

{ lib, ... }:
{
  disko.devices = {
    disk."nvme0n1" = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F";
      content = {
        type = "gpt";
        partitions = {

          # ─── Partição 1: EFI System ───
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0077"
                "dmask=0077"
              ];
            };
          };

          # ─── Partição 2: Swap ───
          swap = {
            size = "16G";
            content = {
              type = "swap";
            };
          };

          # ─── Partição 3: SISTEMA (pode formatar sem medo) ───
          system = {
            size = "260G";
            content = {
              type = "btrfs";
              extraArgs = [
                "-f"
                "-L"
                "NIXOS-SYSTEM"
              ];
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@cache" = {
                  mountpoint = "/var/cache";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@containers" = {
                  mountpoint = "/var/lib/containers";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@libvirt" = {
                  mountpoint = "/var/lib/libvirt";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@tmp" = {
                  mountpoint = "/tmp";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };

          # ─── Partição 4: HOME (nunca formatar!) ───
          home = {
            size = "100%"; # Usa o espaço restante (~200G)
            content = {
              type = "btrfs";
              extraArgs = [
                "-f"
                "-L"
                "NIXOS-HOME"
              ];
              subvolumes = {
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "autodefrag"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
