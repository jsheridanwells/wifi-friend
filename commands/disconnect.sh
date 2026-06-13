cmd_disconnect() {
    # Check for an active wifi connection without rescanning
    local active_line
    active_line=$(nmcli -t -f ACTIVE,SSID dev wifi list --rescan no 2>/dev/null | grep '^yes:' || true)

    if [[ -z "$active_line" ]]; then
        echo "Not connected to any network."
        return
    fi

    local ssid
    ssid=$(echo "$active_line" | cut -d: -f2)

    echo "Currently connected to: $ssid"
    read -r -p "Disconnect? [y/n] " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Cancelled."
        return
    fi

    # Disconnect by device rather than by SSID — more reliable across connection types
    # Gets the first wifi device name (e.g. wlan0, wlp3s0)
    local wifi_device
    wifi_device=$(nmcli -t -f DEVICE,TYPE dev | grep ':wifi' | head -1 | cut -d: -f1)

    if ! nmcli dev disconnect "$wifi_device" &>/dev/null; then
        echo "Failed to disconnect." >&2
        echo "You can try manually: nmcli dev disconnect $wifi_device" >&2
        return 1
    fi

    echo "$ssid disconnected."
}
