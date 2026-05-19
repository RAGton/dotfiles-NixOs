# Take a fully-resolved NixOS `config` attribute and emit a JSON-friendly
# summary: hostName, timezone, and the list of systemd units that will be
# present on the host.
#
# Invocation (from kora.brain.infra_eval):
#   nix eval --json --impure \
#     --apply "import <path>/infra_eval.nix" \
#     <flake>#nixosConfigurations.<host>.config
#
# Why we read `systemd.services` rather than `services.<X>.enable`:
#   NixOS's option tree is a fixed-point of all merged modules. Enumerating
#   it forces evaluation of mandatory-but-unset submodule options and hits
#   module-rename `abort`s that `tryEval` cannot catch. The post-rendering
#   `config.systemd.services` attribute, by contrast, only contains the
#   units that will actually be installed — flat, evaluable, and a better
#   signal of "what runs on this host" than the raw enable flags.
cfg:
let
  tryOr = expr: default:
    let r = builtins.tryEval expr;
    in if r.success then r.value else default;

  attrNamesSafe = v: tryOr (builtins.attrNames v) [ ];

  systemdUnits = attrNamesSafe cfg.systemd.services;
in {
  name     = tryOr cfg.networking.hostName "unknown";
  timezone = tryOr cfg.time.timeZone null;
  services = systemdUnits;
}
