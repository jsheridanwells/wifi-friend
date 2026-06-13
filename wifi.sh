#!/usr/bin/env bash
set -euo pipefail

# Locate commands/ — works from the project repo and after install to /usr/local/bin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/commands" ]]; then
    COMMANDS_DIR="$SCRIPT_DIR/commands"
elif [[ -d "/usr/local/lib/wifi" ]]; then
    COMMANDS_DIR="/usr/local/lib/wifi"
else
    echo "Error: cannot locate wifi commands directory" >&2
    exit 1
fi

SUBCOMMAND="${1:-}"

# init is the command used to install nmcli, so skip the check for it
if [[ "$SUBCOMMAND" != "init" ]]; then
    if ! command -v nmcli &>/dev/null; then
        echo "nmcli is not installed. Run 'wifi init' for installation instructions."
        exit 1
    fi
fi

case "$SUBCOMMAND" in
    --help|-h|"")
        echo "Usage: wifi <command> [options]"
        echo ""
        echo "Commands:"
        echo "  status        Show current wifi connection"
        echo "  scan          List available networks"
        echo "  list          List known (saved) networks"
        echo "  connect       Connect to a network"
        echo "  disconnect    Disconnect from current network"
        echo "  init          Check for nmcli and show install instructions if missing"
        exit 0
        ;;
    status|get-status)
        source "$COMMANDS_DIR/status.sh"
        cmd_status
        ;;
    scan|s)
        source "$COMMANDS_DIR/scan.sh"
        cmd_scan "${@:2}"
        ;;
    list|l)
        source "$COMMANDS_DIR/list.sh"
        cmd_list
        ;;
    init)
        source "$COMMANDS_DIR/init.sh"
        cmd_init
        ;;
    connect|c)
        source "$COMMANDS_DIR/connect.sh"
        cmd_connect
        ;;
    disconnect|d)
        source "$COMMANDS_DIR/disconnect.sh"
        cmd_disconnect
        ;;
    *)
        echo "Unknown command: '$SUBCOMMAND'" >&2
        echo "Run 'wifi' for a list of commands." >&2
        exit 1
        ;;
esac
