# Remote SSH Feature — Kryonix

## What it does

The `kryonix.features.remote.ssh` feature configures OpenSSH server with secure defaults.
It is opt-in and designed to be used in conjunction with the firewall feature (if desired).

## How to enable

```nix
kryonix.features.remote.ssh.enable = true;
```

## Suboptions

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | boolean | `false` | Enable the OpenSSH server. |
| `ports` | list of port numbers | `[ 22 ]` | TCP ports on which sshd listens. |
| `permitRootLogin` | enum | `"no"` | Whether root can log in via SSH. |
| `passwordAuthentication` | boolean | `false` | Allow password-based authentication. |
| `kbdInteractiveAuthentication` | boolean | `false` | Allow keyboard-interactive authentication. |
| `x11Forwarding` | boolean | `false` | Allow X11 forwarding over SSH. |
| `allowTcpForwarding` | string | `"yes"` | Allow TCP forwarding (useful for SSH tunnels). |
| `logLevel` | enum | `"VERBOSE"` | OpenSSH log verbosity. |
| `openFirewall` | boolean | `false` | Automatically open SSH ports in the firewall (if using `kryonix.features.network.firewall`). |

## Example: Glacier host

In `hosts/glacier/default.nix`:

```nix
kryonix.features.remote.ssh = {
  enable = true;
  ports = [ 2224 ];          # Glacier uses a custom port
  permitRootLogin = "no";
  passwordAuthentication = false;
  kbdInteractiveAuthentication = false;
  x11Forwarding = false;
  allowTcpForwarding = "yes"; # Needed for SSH tunneling (VNC)
  logLevel = "VERBOSE";
  openFirewall = true;        # Open port 2224 in firewall
};
```

## Validation

```bash
# Check if sshd is running
systemctl status sshd

# See which ports are listening
ss -ltnp | grep sshd

# Verify SSH configuration
grep -E 'PermitRootLogin|PasswordAuthentication' /etc/ssh/sshd_config

# Test login (from another machine)
ssh -p 2224 user@glacier-host

# Validate the NixOS option
nixos-option services.openssh.enable
nixos-option services.openssh.ports
nixos-option services.openssh.settings.PasswordAuthentication
```

## Security notes

- By default, the feature is disabled (`enable = false`).
- Root login via password is disabled (`permitRootLogin = "no"` and `passwordAuthentication = false`).
- The firewall is **not** opened automatically (`openFirewall = false`) to avoid accidental exposure.
- If you enable `openFirewall = true`, ensure you trust the network or restrict the source IP via firewall rules.

## Related features

- `kryonix.features.network.firewall` — for controlling access to SSH ports.
- `kryonix.features.remoteDesktop.server` — for alternative remote access (VNC, KRDP).

## Changelog

* 2026-06-24: Initial implementation.