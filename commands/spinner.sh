# show_spinner "label" pid
# Animates a -\|/ spinner on one line while a background process runs,
# then clears the line when the process exits.
show_spinner() {
    local label="$1" pid="$2"
    local spin_chars='-\|/'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  %s %s" "$label" "${spin_chars:$i:1}"
        i=$(( (i + 1) % 4 ))
        sleep 0.1
    done
    printf "\r\033[2K"
}
