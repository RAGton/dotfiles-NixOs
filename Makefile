.DEFAULT_GOAL := help

HOSTNAME ?= $(shell hostname)
USERNAME ?= $(shell id -un)
FLAKE ?= .#$(HOSTNAME)
HOME_TARGET ?= .#$(USERNAME)@$(HOSTNAME)
ALLOW_DANGEROUS ?= 0
INSTALL_HOST ?= inspiron
INSTALL_USER ?= rocha
VAULT_SUBMODULE ?= ai/kryonix-vault

.PHONY: help flake-show flake-check flake-update nixos-rebuild \
	home-manager-switch home-manager-news nix-gc dangerous-help \
	guard-dangerous sync submodules update-vault \
	format-full format-system install-system

help:
	@echo "Fluxo principal do projeto: use a CLI 'kryonix' para operacao diaria."
	@echo "O Makefile fica como camada secundaria para inspecao e tarefas especificas."
	@echo ""
	@echo "Alvos públicos e seguros:"
	@echo ""
	@echo "  flake-show           - Mostra os outputs da flake em todos os sistemas"
	@echo "  flake-check          - Roda nix flake check com keep-going"
	@echo "  flake-update         - Atualiza os inputs da flake"
	@echo "  sync                 - Inicializa submodules no commit pinado"
	@echo "  update-vault         - Atualiza ai/kryonix-vault para o upstream"
	@echo "  nixos-rebuild        - Aplica o host em FLAKE (default: $(FLAKE))"
	@echo "  home-manager-switch  - Aplica HOME_TARGET (default: $(HOME_TARGET))"
	@echo "  home-manager-news    - Mostra as novidades do Home Manager para HOME_TARGET"
	@echo "  nix-gc               - Executa garbage collection local"
	@echo "  dangerous-help       - Lista alvos destrutivos e machine-specific"
	@echo ""
	@echo "Exemplos:"
	@echo "  make nixos-rebuild HOSTNAME=inspiron"
	@echo "  make home-manager-switch HOME_TARGET=.#rocha@inspiron"

flake-show:
	@nix flake show --all-systems

flake-check:
	@nix flake check --keep-going

flake-update:
	@nix flake update

sync: submodules
	@echo "Sync concluído: submodules inicializados no estado declarado pelo Git."

submodules:
	@if [ ! -f .gitmodules ]; then \
		echo "Sem .gitmodules; nada a inicializar."; \
		exit 0; \
	fi
	@if [ -d "$(VAULT_SUBMODULE)/.git" ] || [ -f "$(VAULT_SUBMODULE)/.git" ]; then \
		if ! git -C "$(VAULT_SUBMODULE)" diff --quiet -- || \
		   ! git -C "$(VAULT_SUBMODULE)" diff --cached --quiet --; then \
			echo "Submodule $(VAULT_SUBMODULE) possui alterações locais; recusando sincronizar."; \
			echo "Resolva, commit ou stash dentro do submodule antes de rodar make sync."; \
			exit 1; \
		fi; \
	fi
	@git submodule sync -- "$(VAULT_SUBMODULE)"
	@git submodule update --init --recursive -- "$(VAULT_SUBMODULE)"
	@git submodule status --recursive -- "$(VAULT_SUBMODULE)"

update-vault: submodules
	@if ! git -C "$(VAULT_SUBMODULE)" diff --quiet -- || \
	   ! git -C "$(VAULT_SUBMODULE)" diff --cached --quiet --; then \
		echo "Submodule $(VAULT_SUBMODULE) possui alterações locais; update abortado."; \
		echo "Resolva, commit ou stash dentro do submodule antes de atualizar."; \
		exit 1; \
	fi
	@git submodule update --remote --recursive -- "$(VAULT_SUBMODULE)"
	@git submodule status --recursive -- "$(VAULT_SUBMODULE)"
	@git status --short -- "$(VAULT_SUBMODULE)"

nixos-rebuild:
	@sudo nixos-rebuild switch --flake $(FLAKE)

home-manager-switch:
	@home-manager switch --flake $(HOME_TARGET)

home-manager-news:
	@home-manager news --flake $(HOME_TARGET)

nix-gc:
	@nix-collect-garbage -d

dangerous-help:
	@echo "Alvos destrutivos e específicos da máquina inspiron:"
	@echo ""
	@echo "  format-full     - Apaga o NVMe inteiro via disko"
	@echo "  format-system   - Recria apenas o sistema do layout atual do inspiron"
	@echo "  install-system  - Instala $(INSTALL_HOST) em /mnt"
	@echo ""
	@echo "Todos exigem ALLOW_DANGEROUS=1."
	@echo "Exemplo:"
	@echo "  make format-full ALLOW_DANGEROUS=1"

guard-dangerous:
	@if [ "$(ALLOW_DANGEROUS)" != "1" ]; then \
		echo "Recusando executar alvo destrutivo sem ALLOW_DANGEROUS=1."; \
		echo "Use 'make dangerous-help' para revisar o impacto antes."; \
		exit 1; \
	fi

format-full: guard-dangerous
	@echo "⚠️  ATENÇÃO: alvo machine-specific para o host inspiron."
	@echo "⚠️  Isso vai APAGAR TUDO no NVMe (incluindo /home)."
	@echo "Pressione Ctrl+C em 5 segundos para cancelar..."
	@sleep 5
	@sudo nix run github:nix-community/disko -- --mode disko ./hosts/inspiron/disks.nix
	@sudo mkdir -p /mnt/RAG-DATA
	@sudo mount /dev/disk/by-id/ata-KINGSTON_SA400S37240G_50026B7785682AEA-part1 /mnt/RAG-DATA
	@echo "Formatação completa concluída. Revise /mnt antes de instalar."

format-system: guard-dangerous
	@echo "⚠️  ATENÇÃO: alvo machine-specific para o host inspiron."
	@echo "⚠️  Isso recria o sistema, mas tenta preservar /home e o disco SDA."
	@echo "Pressione Ctrl+C em 5 segundos para cancelar..."
	@sleep 5
	@sudo mkfs.vfat -F32 /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part1
	@sudo mkswap /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part2
	@sudo swapon /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part2
	@sudo mkfs.btrfs -f -L NIXOS-SYSTEM /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part3
	@sudo mount /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part3 /mnt
	@sudo btrfs subvol create /mnt/@
	@sudo btrfs subvol create /mnt/@nix
	@sudo btrfs subvol create /mnt/@log
	@sudo btrfs subvol create /mnt/@cache
	@sudo btrfs subvol create /mnt/@containers
	@sudo btrfs subvol create /mnt/@libvirt
	@sudo btrfs subvol create /mnt/@snapshots
	@sudo btrfs subvol create /mnt/@persist
	@sudo btrfs subvol create /mnt/@tmp
	@sudo umount /mnt
	@sudo mount -o subvol=@,compress=zstd,noatime /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part3 /mnt
	@sudo mkdir -p /mnt/{boot,home,nix,var/log,var/cache,var/lib/containers,var/lib/libvirt,.snapshots,persist,tmp,RAG-DATA}
	@sudo mount /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part1 /mnt/boot
	@sudo mount -o subvol=@home,compress=zstd,noatime,autodefrag /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part4 /mnt/home
	@sudo mount -o subvol=@nix,compress=zstd,noatime /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part3 /mnt/nix
	@sudo mount -o subvol=@log,compress=zstd,noatime /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part3 /mnt/var/log
	@sudo mount -o subvol=@cache,compress=zstd,noatime /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part3 /mnt/var/cache
	@sudo mount -o subvol=@containers,compress=zstd,noatime /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part3 /mnt/var/lib/containers
	@sudo mount -o subvol=@libvirt,compress=zstd,noatime /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part3 /mnt/var/lib/libvirt
	@sudo mount -o subvol=@snapshots,compress=zstd,noatime /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part3 /mnt/.snapshots
	@sudo mount -o subvol=@persist,compress=zstd,noatime /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part3 /mnt/persist
	@sudo mount -o subvol=@tmp,compress=zstd,noatime /dev/disk/by-id/nvme-SM2P41C3_NVMe_ADATA_512GB_DM382UX7D58F-part3 /mnt/tmp
	@sudo mount /dev/disk/by-id/ata-KINGSTON_SA400S37240G_50026B7785682AEA-part1 /mnt/RAG-DATA
	@echo "Formatação do sistema concluída. Revise /mnt antes de instalar."

install-system: guard-dangerous
	@echo "Instalando o host $(INSTALL_HOST) em /mnt..."
	@sudo nixos-install --root /mnt --flake .#$(INSTALL_HOST)
	@echo ""
	@echo "Se ainda precisar ajustar a senha do usuário instalado, rode:"
	@echo "  sudo nixos-enter --root /mnt -c 'passwd $(INSTALL_USER)'"
