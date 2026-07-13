/*
  Hardware do servidor RAGOS.

  IMPORTANTÍSSIMO:
  - Nada de UUIDs/discos aqui.
  - O hardware real é gerado pelo instalador via `nixos-generate-config --root /mnt`
    e persistido em `/var/lib/ragos/runtime/hardware-configuration.nix`
    antes do `nixos-install`.
  - O checkout em `/etc/ragos` pode manter apenas links de compatibilidade para leitura humana.

  Isso evita drift e garante que o flake seja genérico/reutilizável em qualquer hardware.
*/
{ ... }:

let
  runtime = import ../runtime;
in
{
  imports = [
    runtime.hardwareModule
  ];
}
