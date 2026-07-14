{ nodeServerIp, ... }:

{
  fileSystems."/" = {
    fsType = "tmpfs";
    device = "tmpfs";
    options = [
      "mode=0755"
      "size=2G"
    ];
  };

  fileSystems."/nix/.ro-store" = {
    fsType = "nfs";
    device = "${nodeServerIp}:/nix/store";
    options = [
      "ro"
      "nolock"
      "vers=4.2"
      "addr=${nodeServerIp}"
    ];
    neededForBoot = true;
  };

  fileSystems."/nix/.rw-store" = {
    fsType = "tmpfs";
    options = [
      "mode=0755"
      "size=4G"
    ];
    neededForBoot = true;
  };

  fileSystems."/nix/store" = {
    fsType = "overlay";
    device = "overlay";
    options = [
      "lowerdir=/nix/.ro-store"
      "upperdir=/nix/.rw-store/store"
      "workdir=/nix/.rw-store/work"
    ];
    depends = [
      "/nix/.ro-store"
      "/nix/.rw-store"
    ];
  };
}
