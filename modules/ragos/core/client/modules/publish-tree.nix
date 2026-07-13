{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.ragos.boot.publishInitrdPath = lib.mkOption {
    type = lib.types.str;
    default = "${config.system.build.initialRamdisk}/initrd";
    internal = true;
    description = "Caminho do initrd efetivamente publicado pelo ragc.";
  };

  config.system.build.ragosPublishTree =
    pkgs.linkFarm "ragos-client-publish-${config.ragos.profile.name}"
      [
        {
          name = "kernel";
          path = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
        }
        {
          name = "initrd";
          path = config.ragos.boot.publishInitrdPath;
        }
        {
          name = "init";
          path = "${config.system.build.toplevel}/init";
        }
        {
          name = "kernel-params";
          path = "${config.system.build.toplevel}/kernel-params";
        }
        {
          name = "toplevel";
          path = config.system.build.toplevel;
        }
      ];
}
