#!/bin/sh
# Rebuild apk-tools after modifications
# Usage: ./scripts/rebuild-apk.sh

set -e
cd "$(dirname "$0")/.."

echo "[*] Cleaning previous build..."
rm -rf apk-tools/build

echo "[*] Configuring..."
cd apk-tools
meson setup -Dprefix=/usr build

echo "[*] Building..."
ninja -C build

echo "[*] Done. Binary at: apk-tools/build/src/apk"
echo "    Test: apk-tools/build/src/apk --version"
