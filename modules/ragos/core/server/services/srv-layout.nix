{ lib, ... }:

let
  # Mantem /srv/ragos coerente com o mesmo snapshot filtrado usado pela ISO,
  # evitando expor artefatos locais/sujos diferentes do source canônico.
  ragosSrc = lib.cleanSourceWith {
    src = ../..;
    filter =
      path: type:
      let
        pathStr = toString path;
        srcStr = toString ../..;
        rel =
          if lib.hasPrefix (srcStr + "/") pathStr then
            lib.removePrefix (srcStr + "/") pathStr
          else
            builtins.baseNameOf pathStr;
        parts = lib.splitString "/" rel;
      in
      !builtins.any (
        part:
        builtins.elem part [
          ".git"
          ".direnv"
          "node_modules"
          "target"
        ]
        || builtins.match "result(-.*)?" part != null
      ) parts;
  };
  runtimeRoot = "/var/lib/ragos/runtime";
in
{
  # Ensure runtime dirs exist (complementing tmpfiles in services.nix)
  systemd.tmpfiles.rules = [
    "d /srv/ragos 0755 root root -"
    "d /var/lib/ragos 0755 root root -"
    "d ${runtimeRoot} 0755 root root -"
  ];

  # Symlink /srv/ragos to the checked-out repo content in /nix/store.
  system.activationScripts.linkSrvRagos = {
    text = ''
      ln -sfn ${ragosSrc} /srv/ragos
    '';
    deps = [ ];
  };

  # Keep human-friendly compatibility paths inside /etc/ragos, but store the
  # real host runtime outside the Git checkout.
  system.activationScripts.linkRagosRuntimeCompat = {
    text = ''
      install -d -m 0755 ${runtimeRoot}
      install -d -m 0755 /etc/ragos/server/runtime

      ln -sfn ${runtimeRoot}/params.nix /etc/ragos/server/runtime/params.nix
      ln -sfn ${runtimeRoot}/hardware-configuration.nix /etc/ragos/server/runtime/hardware-configuration.nix
      ln -sfn ${runtimeRoot}/client-users.json /etc/ragos/server/runtime/client-users.json
    '';
    deps = [ ];
  };
}
