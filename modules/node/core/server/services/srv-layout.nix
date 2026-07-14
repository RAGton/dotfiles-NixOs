{ lib, ... }:

let
  # Mantem /srv/node coerente com o mesmo snapshot filtrado usado pela ISO,
  # evitando expor artefatos locais/sujos diferentes do source canônico.
  nodeSrc = lib.cleanSourceWith {
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
  runtimeRoot = "/var/lib/node/runtime";
in
{
  # Ensure runtime dirs exist (complementing tmpfiles in services.nix)
  systemd.tmpfiles.rules = [
    "d /srv/node 0755 root root -"
    "d /var/lib/node 0755 root root -"
    "d ${runtimeRoot} 0755 root root -"
  ];

  # Symlink /srv/node to the checked-out repo content in /nix/store.
  system.activationScripts.linkSrvNode = {
    text = ''
      ln -sfn ${nodeSrc} /srv/node
    '';
    deps = [ ];
  };

  # Keep human-friendly compatibility paths inside /etc/node, but store the
  # real host runtime outside the Git checkout.
  system.activationScripts.linkNodeRuntimeCompat = {
    text = ''
      install -d -m 0755 ${runtimeRoot}
      install -d -m 0755 /etc/node/server/runtime

      ln -sfn ${runtimeRoot}/params.nix /etc/node/server/runtime/params.nix
      ln -sfn ${runtimeRoot}/hardware-configuration.nix /etc/node/server/runtime/hardware-configuration.nix
      ln -sfn ${runtimeRoot}/client-users.json /etc/node/server/runtime/client-users.json
    '';
    deps = [ ];
  };
}
