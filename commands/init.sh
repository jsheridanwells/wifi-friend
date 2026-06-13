cmd_init() {
    if command -v nmcli &>/dev/null; then
        local version
        version=$(nmcli --version)
        echo "nmcli is installed: $version"

        # systemctl is Linux-only; skip the service check on macOS
        if [[ "$(uname -s)" == "Linux" ]]; then
            if systemctl is-active --quiet NetworkManager; then
                echo "NetworkManager is running."
                echo "You're all set."
            else
                echo "Warning: NetworkManager is not running."
                echo "Start it with: sudo systemctl enable --now NetworkManager"
            fi
        else
            echo "You're all set."
        fi
        return
    fi

    echo "nmcli is not installed."
    echo ""

    # Detect OS — macOS doesn't have /etc/os-release, so check uname first
    local os distro=""
    os=$(uname -s)

    if [[ "$os" == "Darwin" ]]; then
        distro="macos"
    elif [[ -f /etc/os-release ]]; then
        # /etc/os-release is the standard distro identification file on modern Linux
        distro=$(. /etc/os-release && echo "$ID")
    fi

    case "$distro" in
        arch|manjaro|endeavouros|garuda)
            echo "Install on Arch-based systems:"
            echo "  sudo pacman -S networkmanager"
            echo ""
            echo "Then enable and start the service:"
            echo "  sudo systemctl enable --now NetworkManager"
            ;;
        ubuntu|debian|linuxmint|pop)
            echo "Install on Debian-based systems:"
            echo "  sudo apt install network-manager"
            echo ""
            echo "Then enable and start the service:"
            echo "  sudo systemctl enable --now NetworkManager"
            ;;
        fedora|rhel|centos|rocky|alma)
            echo "Install on Fedora/RHEL-based systems:"
            echo "  sudo dnf install NetworkManager"
            echo ""
            echo "Then enable and start the service:"
            echo "  sudo systemctl enable --now NetworkManager"
            ;;
        macos)
            echo "Install on macOS (requires Homebrew):"
            echo "  brew install networkmanager"
            echo ""
            echo "Note: NetworkManager is a Linux tool — functionality on macOS may be limited."
            ;;
        *)
            echo "Could not detect your distro automatically."
            echo "Install the 'networkmanager' package via your package manager,"
            echo "then run: sudo systemctl enable --now NetworkManager"
            ;;
    esac
}
