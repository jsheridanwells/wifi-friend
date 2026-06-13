SCAN_SIGNAL_THRESHOLD=20

cmd_scan() {
    # --all option. show all networks regardless of signal strength
    local show_all=false
    [[ "${1:-}" == "--all" ]] && show_all=true

    source "$COMMANDS_DIR/spinner.sh"

    # Background the nmcli scan so we can spin while it rescans the radio
    local raw_file
    raw_file=$(mktemp)
    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list >"$raw_file" 2>/dev/null &
    show_spinner "Scanning for networks..." "$!"
    wait "$!" || true

    local raw
    raw=$(cat "$raw_file")
    rm -f "$raw_file"

    if [[ -z "$raw" ]]; then
        echo "No networks found."
        return
    fi

    # Pass 1: find the name of the currently connected network (if any)
    local active_ssid=""
    while IFS=: read -r in_use ssid signal security; do
        [[ "$in_use" == "*" ]] && active_ssid="$ssid" && break
    done <<< "$raw"

    printf "\n  %-4s  %-30s  %-8s  %s\n" "#" "SSID" "Signal" "Security"
    printf "  %-4s  %-30s  %-8s  %s\n" "----" "------------------------------" "--------" "--------"

    # Pass 2: print the first occurrence of each SSID (= strongest signal, since nmcli sorts desc)
    # Multiple rows with the same SSID are the same network on different access points — skip them
    declare -A seen
    local i=1
    local hidden_count=0
    while IFS=: read -r in_use ssid signal security; do
        if [[ -z "$ssid" ]]; then
            hidden_count=$((hidden_count + 1))
            continue
        fi

        [[ -v seen["$ssid"] ]] && continue

        # Skip weak signals unless --all was passed
        if [[ "$show_all" == false && "$signal" -lt "$SCAN_SIGNAL_THRESHOLD" ]]; then
            seen["$ssid"]=1
            continue
        fi

        seen["$ssid"]=1
        local prefix="  "
        [[ "$ssid" == "$active_ssid" ]] && prefix="* "
        printf "%s%-4s  %-30s  %5s%%   %s\n" "$prefix" "$i" "$ssid" "$signal" "$security"
        i=$((i + 1))
    done <<< "$raw"

    if [[ "$show_all" == false ]]; then
        echo ""
        echo "  (networks below ${SCAN_SIGNAL_THRESHOLD}% signal hidden — use 'wifi scan --all' to show them)"
    fi
    echo ""
}
