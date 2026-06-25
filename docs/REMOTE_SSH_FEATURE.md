# Remote SSH Feature

`kryonix.features.remote.ssh` provides declarative OpenSSH configuration.

Safety defaults:

- disabled by default
- password authentication disabled by default
- root login disabled by default
- firewall opening disabled by default

Example:

```nix
kryonix.features.remote.ssh = {
  enable = true;
  ports = [ 2224 ];
  openFirewall = false;
};
```

For remote hosts, test with `nixos-rebuild test` before `switch`.
