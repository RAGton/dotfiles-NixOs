#!/usr/bin/env bash
# Script para publicar o binário estático do Kryonix Installer
# Autor: Engenheiro de DevOps

set -euo pipefail

VERSION=$(grep '^version' packages/kryonix-installer/Cargo.toml | head -n1 | cut -d'"' -f2)
ARTIFACT="kryonix-installer-x86_64"

echo "🔨 Construindo Kryonix Installer v$VERSION (Estático)..."
nix build .#kryonix-installer-static --out-link result-installer --impure

cp result-installer/bin/kryonix-installer "./$ARTIFACT"
sha256sum "./$ARTIFACT" > "./$ARTIFACT.sha256"

echo "✅ Build concluído: $ARTIFACT"
echo "Sumário SHA256:"
cat "./$ARTIFACT.sha256"

# Nota: Em CI, o upload é feito via GitHub Actions.
# Localmente, você pode usar 'gh release upload'.
