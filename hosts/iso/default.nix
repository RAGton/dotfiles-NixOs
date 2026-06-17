# Host: iso (Live CD / instalador automatizado)
#
# Objetivo
# - Gerar uma ISO bootável que facilite a instalação dos hosts deste flake.
# - A ISO traz um script `kryonix-install` que particiona (Disko) e roda `nixos-install`.
{
  inputs,
  hostname,
  lib,
  pkgs,
  modulesPath,
  offlineMode ? false,
  ...
}:
{
  imports = [
    # Base do instalador do NixOS (ISO minimal)
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")

    # Modulos para ISO modular
    inputs.self.nixosModules.installer-core

    ../../modules/nixos/installer/web-kiosk.nix
    ../../modules/shared/nixpkgs
    ../../modules/nixos/meta

    # Branding Kryonix (GRUB tema + Plymouth + os-release)
    ../../modules/nixos/branding/kryonix/default.nix
  ]
  ++ lib.optionals offlineMode [
    inputs.self.nixosModules.full-profile
  ];

  networking.hostName = lib.mkForce "kryonix";
  kryonix.installer.kiosk.enable = true;
  kryonix.branding.enable = true;

  # Se estiver em modo offline, garante que o closure esteja no store da ISO.
  isoImage.storeContents = lib.optional offlineMode (
    with pkgs;
    [
      # Garante que as ferramentas e o flake estejam acessíveis sem internet
      git
      curl
      jq
      nix
      inputs.self.outPath
    ]
  );

  # ── Rede: ethernet DHCP automático + WiFi via NetworkManager ──────────────
  # O instalador precisa de internet antes do passo 1 (OAuth GitHub).
  # nmcli é a ponte entre o backend Axum e as interfaces de rede.
  networking.networkmanager.enable = lib.mkForce true;
  # Desabilita dhcpcd para evitar conflito com NM
  networking.useDHCP = lib.mkForce false;

  # Firmware WiFi para as chips mais comuns (Intel, Realtek, Broadcom, Atheros)
  hardware.enableAllFirmware = lib.mkDefault true;
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # Usuário live precisa estar no grupo networkmanager para rodar nmcli sem sudo
  users.users.nixos.extraGroups = lib.mkDefault [
    "networkmanager"
    "wheel"
  ];

  # ISO identity
  system.nixos.distroName = lib.mkForce "KryonixOS";
  system.nixos.label = lib.mkForce "KryonixOS-Installer";
  image.baseName = lib.mkForce "kryonix";
  isoImage.volumeID = lib.mkForce "KRYONIX";
  isoImage.appendToMenuLabel = lib.mkForce "Installer";

  # Plymouth: cd-minimal desabilita com mkForce, precisamos sobrescrever
  boot.plymouth.enable = lib.mkForce true;

  # Boot silencioso para Plymouth aparecer corretamente
  boot.initrd.verbose = lib.mkForce false;
  boot.consoleLogLevel = lib.mkForce 0;
  # IMPORTANT: usar mkAfter, NUNCA mkForce. O iso-image.nix injeta os params
  # essenciais do boot da Live ISO em boot.kernelParams — em especial
  # "root=LABEL=${volumeID}" (stage-1 script-based monta o CD por label). Um
  # lib.mkForce (prio 50) sobrescreve a lista inteira do iso-image e apaga o
  # root=LABEL → o stage-1 não acha o store → switch_root falha → kernel panic
  # "Attempted to kill init! exitcode=0x7f00". mkAfter apenas ANEXA os
  # cosméticos abaixo, preservando root=LABEL e boot.shell_on_fail.
  boot.kernelParams = lib.mkAfter [
    "quiet"
    "splash"
    "loglevel=0"
    "udev.log_priority=3"
    "systemd.show_status=false"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "vt.global_cursor_default=0"
    "plymouth.ignore-serial-consoles"
    "kryonix.installer.mode=local"
  ];

  specialisation."remote".configuration = {
    # Em modo remote, o usuário precisa ver o TTY para ler o Session Token.
    # Desabilitamos o splash e ativamos loglevel adequado, além de definir o mode.
    boot.kernelParams = [
      "kryonix.installer.mode=remote"
    ];
    # Remove quiet/splash para ver os logs de boot
    boot.plymouth.enable = lib.mkOverride 10 false;
    isoImage.appendToMenuLabel = lib.mkForce "Installer (Remote Web)";
  };

  # NOTE: o bloco de "Early KMS" (boot.initrd.kernelModules=[virtio_gpu] +
  # availableKernelModules amdgpu/radeon/nouveau/i915) foi removido. Não era a
  # causa do panic (essa era o lib.mkForce em kernelParams, corrigido acima),
  # mas puxava firmware GPU pesado para o initrd sem necessidade no boot do
  # ambiente live. Reintroduzir só se o splash precisar, de forma isolada.

  # Sem banner de login no tty1: elimina o texto "kryonix login: installer
  # (automatic login)" que aparecia na janela entre o Plymouth e o kiosk gráfico.
  services.getty.greetingLine = lib.mkForce "";
  services.getty.helpLine = lib.mkForce "";

  # ISO deve ser estável e pequena: evita trazer desktop completo.
  documentation.enable = lib.mkDefault false;

  # Ajuda no debug e instalação
  environment.systemPackages = with pkgs; [
    kryonix
    kryonix-hardware-probe
    git
    curl
    jq
    fzf
    # nmcli já vem pelo networkmanager; garantimos explicitamente para o backend
    networkmanager
    # iw é útil para debug manual de WiFi no terminal
    iw
  ];

  # Normally útil em instalação remota (opcional)
  services.openssh.enable = lib.mkDefault true;
  services.qemuGuest.enable = lib.mkDefault true;

  # Meta versioning
  kryonix.meta.version.enable = true;

  # Evita pedir senha no live. Chave pode ser adicionada depois.
  users.users.nixos.openssh.authorizedKeys.keys = lib.mkDefault [ ];
}
