{
  inputs,
  hostname,
  nixosModules,
  ...
}:
{
  imports = [
    # Hardware correto para INTEL
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-gpu-intel
    inputs.hardware.nixosModules.common-pc-ssd

    ./hardware-configuration.nix

    # Módulos do seu layout
    "${nixosModules}/common"
    "${nixosModules}/desktop/kde"
    "${nixosModules}/programs/steam"
    "${nixosModules}/virtualization/default.nix"
  ];

  ############################
  # Hostname
  ############################
  networking.hostName = hostname;

  ############################
  # Locale PT-BR
  ############################
  i18n = {
    defaultLocale = "pt_BR.UTF-8";
    supportedLocales = [
      "pt_BR.UTF-8/UTF-8"
    ];
  };

  environment.variables = {
    LANG = "pt_BR.UTF-8";
    LC_ALL = "pt_BR.UTF-8";
  };
  ############################
  # IOMMU (Intel)
  ############################
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
  ];

  # Use GRUB as the system bootloader (EFI mode)
  boot.loader.grub = {
    enable = true;
    version = 2;
    # Install to the EFI NVRAM (mark removable so it works on many machines)
    efiInstallAsRemovable = true;
  };

  ############################
  # Versão de estado
  ############################
  system.stateVersion = "25.11";
}
