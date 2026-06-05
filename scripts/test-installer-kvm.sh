#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "test-installer-kvm.sh agora usa o teste libvirt canônico e seguro."
exec "$repo_root/scripts/test-iso-boot.sh" "$@"
