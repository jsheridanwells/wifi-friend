#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/wifi"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$EUID" -ne 0 ]]; then
    echo "Install requires sudo. Re-run as: sudo bash install.sh"
    exit 1
fi

echo "Installing wifi to $BIN_DIR/wifi ..."
cp "$SCRIPT_DIR/wifi.sh" "$BIN_DIR/wifi"
chmod +x "$BIN_DIR/wifi"

echo "Installing commands to $LIB_DIR ..."
mkdir -p "$LIB_DIR"
cp "$SCRIPT_DIR/commands/"*.sh "$LIB_DIR/"

echo ""
echo "Done. Run 'wifi' from anywhere to get started."
