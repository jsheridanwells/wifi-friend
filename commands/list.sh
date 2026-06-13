cmd_list() {
    # connection show lists all NetworkManager profiles (vpn, ethernet, wifi, etc.)
    # grep filters to wifi-only by matching the 802-11-wireless type field
    local raw
    # || true: grep exits 1 when no wifi profiles match, which would otherwise
    # abort the script under 'set -e' before we can print the empty-state message
    raw=$(nmcli -t -f NAME,TYPE,ACTIVE connection show 2>/dev/null | grep ':802-11-wireless:' || true)

    if [[ -z "$raw" ]]; then
        echo "No saved networks found."
        return
    fi

    printf "\n  %-4s  %-30s  %s\n" "#" "SSID" "Status"
    printf "  %-4s  %-30s  %s\n" "----" "------------------------------" "----------"

    local i=1
    while IFS=: read -r name type active; do
        local prefix="  "
        local status=""
        if [[ "$active" == "yes" ]]; then
            prefix="* "
            status="connected"
        fi
        printf "%s%-4s  %-30s  %s\n" "$prefix" "$i" "$name" "$status"
        i=$((i + 1))
    done <<< "$raw"

    echo ""
}
