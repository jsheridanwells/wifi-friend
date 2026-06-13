cmd_status() {
    # "enabled" or "disabled"
    local radio_state
    radio_state=$(nmcli radio wifi)

    if [[ "$radio_state" == "disabled" ]]; then
        echo "WiFi is disabled."
        return
    fi

    # -t (terse) gives colon-delimited output: ACTIVE:SSID:SIGNAL, one line per visible network
    # grep for the active one; || true prevents set -e from aborting when nothing is connected
    local active_line
    active_line=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi list --rescan no 2>/dev/null | grep '^yes:' || true)

    if [[ -z "$active_line" ]]; then
        echo "WiFi is on, but not connected."
        return
    fi

    # nmcli -t uses ':' as delimiter; literal colons inside SSIDs are escaped as '\:'
    # cut -d: -f2 is safe for the common case of SSIDs without literal colons
    local ssid signal
    ssid=$(echo "$active_line" | cut -d: -f2)
    signal=$(echo "$active_line" | cut -d: -f3)

    echo "Connected to: $ssid  (${signal}% signal)"
}
