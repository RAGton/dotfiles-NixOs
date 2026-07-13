#!/usr/bin/env bash
# Purpose: Validar o contrato de descoberta da live media e recovery do installer ISO
# Category: tests
# Safety: safe
# Expected environment: checkout do RAGOS com flakes habilitados
# Requires: nix

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
flake_ref="path:$repo_root"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if ! grep -Fq "$needle" <<<"$haystack"; then
    printf 'ASSERT FAIL [%s]: missing %q\n' "$label" "$needle" >&2
    exit 1
  fi
}

kernel_params="$("${nix_cmd[@]}" eval --json "$flake_ref#nixosConfigurations.ragos-iso.config.boot.kernelParams")"
available_modules="$("${nix_cmd[@]}" eval --json "$flake_ref#nixosConfigurations.ragos-iso.config.boot.initrd.availableKernelModules")"
supported_fs="$("${nix_cmd[@]}" eval --json "$flake_ref#nixosConfigurations.ragos-iso.config.boot.initrd.supportedFilesystems")"
extra_utils="$("${nix_cmd[@]}" eval --raw "$flake_ref#nixosConfigurations.ragos-iso.config.boot.initrd.extraUtilsCommands")"
post_device="$("${nix_cmd[@]}" eval --raw "$flake_ref#nixosConfigurations.ragos-iso.config.boot.initrd.postDeviceCommands")"
pre_fail="$("${nix_cmd[@]}" eval --raw "$flake_ref#nixosConfigurations.ragos-iso.config.boot.initrd.preFailCommands")"
iso_definition="$(cat "$repo_root/installer/iso.nix")"

assert_contains "$kernel_params" '"root=LABEL=RAGOS_INSTALLER"' "kernel params keep live label"
assert_contains "$kernel_params" '"boot.shell_on_fail"' "kernel params keep recovery shell"

assert_contains "$available_modules" '"dm_mod"' "device-mapper module is in initrd"
assert_contains "$available_modules" '"udf"' "udf module is in initrd"
assert_contains "$supported_fs" '"exfat"' "exfat support for experimental findiso media"
assert_contains "$supported_fs" '"udf"' "udf support for optical style live media"

assert_contains "$extra_utils" '/bin/lsblk' "lsblk copied to initrd"
assert_contains "$extra_utils" '/bin/findmnt' "findmnt copied to initrd"
assert_contains "$extra_utils" '/bin/umount' "umount copied to initrd"
assert_contains "$extra_utils" '/bin/ip' "ip copied to initrd"
assert_contains "$extra_utils" '/bin/journalctl' "journalctl copied to initrd"
assert_contains "$extra_utils" '$out/bin/realpath' "realpath helper emitted into initrd"
assert_contains "$extra_utils" '$out/bin/ragos-live-debug' "debug helper emitted into initrd"

assert_contains "$post_device" 'Ventoy device-mapper live media detected' "Ventoy detection logged in stage 1"
assert_contains "$post_device" 'Resolved live media from blkid scan' "stage 1 relink fallback present"
assert_contains "$pre_fail" 'suporte experimental' "Ventoy warning exposed on failure"
assert_contains "$pre_fail" 'Squashfs da live nao foi localizada' "squashfs failure hint exposed"
assert_contains "$pre_fail" 'Parametro findiso presente, mas arquivo nao localizado.' "findiso failure hint exposed"

assert_contains "$iso_definition" '".lab-validation"' "installer source filter excludes validation artifacts"
assert_contains "$iso_definition" '".codex"' "installer source filter excludes codex workspace data"
assert_contains "$iso_definition" '".vscode"' "installer source filter excludes editor settings"

printf 'Installer live-media contract passed.\n'
