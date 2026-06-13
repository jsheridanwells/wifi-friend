# Shared helpers for the wifi test suite.
# Sourced by run_tests.sh. No 'set -e' — we want every test to run and report.

# Absolute paths captured up front, because each test run replaces PATH with a
# locked-down sandbox that contains ONLY our mocks plus a few coreutils.
REAL_BASH="$(command -v bash)"
REAL_ENV="$(command -v env)"
REAL_TIMEOUT="$(command -v timeout)"

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
WIFI="$PROJECT_DIR/wifi.sh"
MOCKS="$TESTS_DIR/mocks"

PASS_COUNT=0
FAIL_COUNT=0
CURRENT_TEST=""

# Coreutils the real scripts shell out to. We symlink the genuine binaries so
# the scripts behave normally — only nmcli/systemctl/uname are faked.
SANDBOX_TOOLS="bash env dirname basename cat grep head tail cut sed sleep seq mktemp rm cp mkdir mv chmod ln tr"

# Builds a sandbox bin directory. $1 = "true" to include the mock nmcli,
# "false" to leave it out (simulating nmcli not being installed).
build_sandbox() {
    local with_nmcli="$1"
    local dir
    dir="$(mktemp -d)"

    local tool path
    for tool in $SANDBOX_TOOLS; do
        path="$(command -v "$tool" 2>/dev/null)" || continue
        ln -s "$path" "$dir/$tool"
    done

    cp "$MOCKS/systemctl" "$dir/systemctl"; chmod +x "$dir/systemctl"
    cp "$MOCKS/uname"     "$dir/uname";     chmod +x "$dir/uname"
    if [[ "$with_nmcli" == "true" ]]; then
        cp "$MOCKS/nmcli" "$dir/nmcli"; chmod +x "$dir/nmcli"
    fi

    echo "$dir"
}

# Wipes any MOCK_* state between tests so leftovers can't leak across cases.
reset_mocks() {
    unset MOCK_RADIO MOCK_STATUS_LIST MOCK_WIFI_LIST MOCK_CONN_LIST \
          MOCK_ACTIVE_LIST MOCK_DEV_LIST MOCK_DISCONNECT_RC \
          MOCK_KNOWN_SSIDS MOCK_CONNECT_MODE MOCK_CONNECT_MODES \
          MOCK_CONNECT_COUNTER MOCK_UNAME MOCK_SYSTEMCTL_RC
}

# Creates a fresh counter file for a multi-attempt connect sequence and exports
# both the modes and the counter path for the mock to read.
set_connect_sequence() {
    export MOCK_CONNECT_MODES="$1"
    MOCK_CONNECT_COUNTER="$(mktemp)"
    echo 0 > "$MOCK_CONNECT_COUNTER"
    export MOCK_CONNECT_COUNTER
}

# Runs wifi.sh inside a sandbox. $1 = sandbox dir, rest = wifi args.
# stdin is inherited from the caller (use <<< "$input" for interactive cases).
# Captures combined stdout+stderr in OUT and the exit code in RC.
# A 10s timeout guards against any prompt loop that fails to terminate.
run_wifi() {
    local sandbox="$1"; shift
    OUT="$("$REAL_TIMEOUT" 10 "$REAL_ENV" PATH="$sandbox" "$REAL_BASH" "$WIFI" "$@" 2>&1)"
    RC=$?
}

# --- assertions --------------------------------------------------------------

start_test() { CURRENT_TEST="$1"; }

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  \033[32mPASS\033[0m  %s\n' "$CURRENT_TEST"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  \033[31mFAIL\033[0m  %s\n' "$CURRENT_TEST"
    printf '        %s\n' "$1"
    if [[ -n "${2:-}" ]]; then
        printf '        --- output ---\n'
        printf '%s\n' "$2" | sed 's/^/        /'
        printf '        --------------\n'
    fi
}

assert_contains() {
    if [[ "$OUT" == *"$1"* ]]; then
        pass
    else
        fail "expected output to contain: $1" "$OUT"
    fi
}

assert_not_contains() {
    if [[ "$OUT" != *"$1"* ]]; then
        pass
    else
        fail "expected output NOT to contain: $1" "$OUT"
    fi
}

assert_rc() {
    if [[ "$RC" == "$1" ]]; then
        pass
    else
        fail "expected exit code $1 but got $RC" "$OUT"
    fi
}

print_summary() {
    echo ""
    echo "================================"
    printf 'Total: %d   \033[32mPassed: %d\033[0m   \033[31mFailed: %d\033[0m\n' \
        "$((PASS_COUNT + FAIL_COUNT))" "$PASS_COUNT" "$FAIL_COUNT"
    echo "================================"
    [[ "$FAIL_COUNT" -eq 0 ]]
}
