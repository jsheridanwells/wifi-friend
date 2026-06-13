CONNECT_DEFAULT_LIMIT=5
CONNECT_SIGNAL_THRESHOLD=20

cmd_connect() {
    echo "Scanning for networks..."

    # Force a fresh scan; fields: active marker, network name, signal (0-100), security type
    local raw
    raw=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null)

    if [[ -z "$raw" ]]; then
        echo "No networks found."
        return
    fi

    # Build indexed arrays of unique, usable networks (one entry per SSID, strongest signal first)
    declare -A seen
    local ssids=() signals=() securities=()
    local active_ssid=""

    while IFS=: read -r in_use ssid signal security; do
        [[ "$in_use" == "*" ]] && active_ssid="$ssid"
    done <<< "$raw"

    while IFS=: read -r in_use ssid signal security; do
        [[ -z "$ssid" ]] && continue
        [[ -v seen["$ssid"] ]] && continue
        if [[ "$signal" -lt "$CONNECT_SIGNAL_THRESHOLD" ]]; then
            seen["$ssid"]=1
            continue
        fi
        seen["$ssid"]=1
        ssids+=("$ssid")
        signals+=("$signal")
        securities+=("$security")
    done <<< "$raw"

    if [[ ${#ssids[@]} -eq 0 ]]; then
        echo "No usable networks found. Try 'wifi scan --all' to see weak signals."
        return
    fi

    # Print the network table; limit=0 means show all
    print_table() {
        local limit=$1
        local total=${#ssids[@]}
        local rows=$(( limit > 0 && limit < total ? limit : total ))

        printf "\n  %-4s  %-30s  %-8s  %s\n" "#" "SSID" "Signal" "Security"
        printf "  %-4s  %-30s  %-8s  %s\n" "----" "------------------------------" "--------" "--------"
        for ((i=0; i<rows; i++)); do
            local prefix="  "
            [[ "${ssids[$i]}" == "$active_ssid" ]] && prefix="* "
            printf "%s%-4s  %-30s  %5s%%   %s\n" "$prefix" "$((i+1))" "${ssids[$i]}" "${signals[$i]}" "${securities[$i]}"
        done
        echo ""
    }

    local show_limit=$CONNECT_DEFAULT_LIMIT

    # Outer loop: network selection — returns here after a non-password connection failure
    while true; do
        print_table "$show_limit"

        local selection
        while true; do
            local total=${#ssids[@]}
            local shown=$(( show_limit > 0 && show_limit < total ? show_limit : total ))

            if [[ $shown -lt $total ]]; then
                read -r -p "  Enter number (1-${shown}), 'more' to show all, or Ctrl+C to cancel: " selection
            else
                read -r -p "  Enter number (1-${shown}), or Ctrl+C to cancel: " selection
            fi

            if [[ "$selection" == "more" ]]; then
                show_limit=0
                print_table 0
                continue
            fi

            if [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -le "$shown" ]]; then
                break
            fi

            echo "  Please enter a number between 1 and $shown."
        done

        local chosen_ssid="${ssids[$((selection-1))]}"
        local chosen_security="${securities[$((selection-1))]}"

        # If a saved connection profile exists, NetworkManager already has the password
        local is_known=false
        nmcli connection show "$chosen_ssid" &>/dev/null && is_known=true || true

        # Prompt for password if the network is secured and not already known.
        # Forced true after a wrong-password failure so the user can re-enter.
        local prompt_for_password=false
        if [[ "$is_known" == false && -n "$chosen_security" && "$chosen_security" != "--" ]]; then
            prompt_for_password=true
        fi

        # Inner loop: password prompt + connect attempt
        # Loops here on wrong password so the user can retry without re-selecting the network
        while true; do
            local password=""
            if [[ "$prompt_for_password" == true ]]; then
                read -r -p "  Password: " password
                # Overwrite the password line with asterisks so it's not readable in the terminal buffer
                local masked
                masked=$(printf '%0.s*' $(seq 1 ${#password}))
                printf "\033[1A\033[2K  Password: %s\n" "$masked"
            fi

            echo ""

            # Run nmcli in the background so we can show a spinner while it connects
            local result_file
            result_file=$(mktemp)

            if [[ -n "$password" ]]; then
                nmcli dev wifi connect "$chosen_ssid" password "$password" &>"$result_file" &
            else
                nmcli dev wifi connect "$chosen_ssid" &>"$result_file" &
            fi
            local connect_pid=$!

            local spin_chars='-\|/'
            local i=0
            while kill -0 "$connect_pid" 2>/dev/null; do
                printf "\r  Connecting... ${spin_chars:$i:1}"
                i=$(( (i + 1) % 4 ))
                sleep 0.1
            done
            printf "\r\033[2K"

            if wait "$connect_pid"; then
                echo "$chosen_ssid connected!"
                rm -f "$result_file"
                return 0
            fi

            local error_output
            error_output=$(cat "$result_file" 2>/dev/null)
            rm -f "$result_file"

            if echo "$error_output" | grep -qi "secrets were required"; then
                # Delete the saved profile so nmcli doesn't reuse the wrong password on the next attempt
                nmcli connection delete "$chosen_ssid" &>/dev/null || true
                prompt_for_password=true
                echo "  Incorrect password."
                local pw_choice
                read -r -p "  [t] Try again  [l] Back to network list  Ctrl+C to quit: " pw_choice
                echo ""
                if [[ "$pw_choice" == "l" || "$pw_choice" == "L" ]]; then
                    break  # back to outer loop (network list)
                fi
                # anything else (including 't') retries the password prompt
            else
                # Any other failure — break to the outer loop to re-show the network list
                echo "  Could not connect to $chosen_ssid. Choose another network or Ctrl+C to cancel."
                echo ""
                break
            fi
        done
    done
}
