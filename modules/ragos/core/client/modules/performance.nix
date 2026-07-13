{ ... }:

{
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
  };

  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "20s";
  };
}
