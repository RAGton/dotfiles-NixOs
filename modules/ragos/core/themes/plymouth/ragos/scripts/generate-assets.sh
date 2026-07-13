#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
theme_dir="$repo_root/themes/plymouth/ragos"
python_version="$(python3 -c 'import sys; print(f\"python{sys.version_info.major}.{sys.version_info.minor}\")')"
pillow_store="$(nix build --no-link --print-out-paths nixpkgs#python3Packages.pillow)"

export PYTHONPATH="$pillow_store/lib/$python_version/site-packages${PYTHONPATH:+:$PYTHONPATH}"
python3 "$theme_dir/scripts/generate-assets.py"
