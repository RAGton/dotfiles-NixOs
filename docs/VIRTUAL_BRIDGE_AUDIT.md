# Virtual Bridge Audit — ragthink

## Summary

`virbr-ragthink` is currently created by the legacy module `modules/virtualization/net-ragthink.nix`, which defines a Libvirt network from a static XML file.

## Current state

- Libvirt network name: `net-ragthink`
- Linux bridge name: `virbr-ragthink`
- Host bridge address: `192.168.100.1/24`
- NAT: not enabled in current XML
- DHCP: not enabled in current XML
- Used by: downstream `inspiron` and `glacier`
- Runtime on Inspiron: IP is already on the virtual bridge, not on Wi-Fi/Ethernet

## Design decision

Use Libvirt-managed virtual NAT networks for laptop/lab isolation.

Do not bridge Wi-Fi interfaces directly.

## Target topology

wlo1/enp* -> real internet/default route
virbr-ragthink -> 192.168.100.1/24
VMs/labs -> 192.168.100.0/24
NAT -> via Libvirt

## Migration plan

- [x] 1. Add schema for `kryonix.features.network.virtualBridges`
- [x] 2. Implement Libvirt network generation in core
- [ ] 3. Migrate `inspiron` only
- [ ] 4. Validate with `nixos-rebuild test`
- [ ] 5. Migrate `glacier` separately
- [ ] 6. Deprecate `net-ragthink.nix`

## Drift detection

The virtual bridge backend intentionally does not destroy or undefine existing Libvirt networks. If a network already exists but its XML differs from the Kryonix-generated XML, the systemd service fails with a clear message and requires manual migration.

This prevents silently keeping an old non-NAT network while the NixOS configuration declares `nat = true`.

On existing hosts, `net-ragthink` may already exist without NAT because it was created by the legacy module. In that case, enabling `virtualBridges.ragthink.nat = true` requires a one-time manual migration while dependent VMs are shut down.
