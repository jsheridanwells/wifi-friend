#!/usr/bin/env bash
# Test suite for the `wifi` utility.
#
# Every test runs the REAL command scripts but with a mocked nmcli (plus
# systemctl/uname) injected via PATH, so nothing touches real hardware.
# See tests/lib.sh for the sandbox + assertion machinery.
#
# Run with:  bash tests/run_tests.sh

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Build the two sandboxes once and reuse them. The mocks read their behaviour
# from env vars at call time, so the sandbox contents never need to change.
SANDBOX="$(build_sandbox true)"      # with mock nmcli (the normal case)
SANDBOX_NO="$(build_sandbox false)"  # without nmcli (simulates "not installed")

# Clean up temp dirs on exit no matter how we leave.
cleanup() { rm -rf "$SANDBOX" "$SANDBOX_NO"; }
trap cleanup EXIT

section() { echo ""; echo "### $1"; }

# =============================================================================
section "dispatcher (wifi.sh)"
# =============================================================================

reset_mocks
start_test "no args prints usage"
run_wifi "$SANDBOX"
assert_contains "Usage: wifi"

start_test "no args lists the status command"
run_wifi "$SANDBOX"
assert_contains "status"

start_test "--help prints usage"
run_wifi "$SANDBOX" --help
assert_contains "Usage: wifi"

start_test "-h prints usage"
run_wifi "$SANDBOX" -h
assert_contains "Usage: wifi"

start_test "unknown command errors"
run_wifi "$SANDBOX" bogus
assert_contains "Unknown command"

start_test "unknown command exits non-zero"
run_wifi "$SANDBOX" bogus
assert_rc 1

start_test "missing nmcli is reported for normal commands"
run_wifi "$SANDBOX_NO" status
assert_contains "nmcli is not installed"

start_test "missing nmcli exits non-zero"
run_wifi "$SANDBOX_NO" status
assert_rc 1

# =============================================================================
section "status"
# =============================================================================

reset_mocks
export MOCK_RADIO="disabled"
start_test "radio disabled"
run_wifi "$SANDBOX" status
assert_contains "WiFi is disabled"

reset_mocks
export MOCK_RADIO="enabled"
export MOCK_STATUS_LIST=":SomeNet:40"   # no '^yes:' line => not connected
start_test "on but not connected"
run_wifi "$SANDBOX" status
assert_contains "not connected"

reset_mocks
export MOCK_RADIO="enabled"
export MOCK_STATUS_LIST="yes:HomeNet:80"
start_test "connected shows ssid"
run_wifi "$SANDBOX" status
assert_contains "Connected to: HomeNet"

start_test "connected shows signal percent"
run_wifi "$SANDBOX" status
assert_contains "80% signal"

# =============================================================================
section "scan"
# =============================================================================

reset_mocks
export MOCK_WIFI_LIST=""
start_test "no networks found"
run_wifi "$SANDBOX" scan
assert_contains "No networks found"

reset_mocks
# Includes: an active net, an open net, a duplicate SSID, a hidden (blank) SSID,
# and a weak net below the 20% threshold.
export MOCK_WIFI_LIST="*:HomeNet:80:WPA2
:OpenCafe:60:
:HomeNet:55:WPA2
::70:WPA2
:Secured5G:40:WPA2
:Weak:10:WPA2"

start_test "scan shows strong network"
run_wifi "$SANDBOX" scan
assert_contains "HomeNet"

start_test "scan shows open network"
run_wifi "$SANDBOX" scan
assert_contains "OpenCafe"

start_test "scan marks the active network with *"
run_wifi "$SANDBOX" scan
assert_contains "* 1"

start_test "scan hides weak networks by default"
run_wifi "$SANDBOX" scan
assert_not_contains "Weak"

start_test "scan shows the hidden-weak footer"
run_wifi "$SANDBOX" scan
assert_contains "use 'wifi scan --all'"

start_test "scan dedupes repeated SSIDs"
# HomeNet appears twice in the data; it should be listed once (rows 1..3 only)
run_wifi "$SANDBOX" scan
# entry numbering: 1 HomeNet, 2 OpenCafe, 3 Secured5G  -> no 4th visible row
assert_not_contains "4     "

start_test "scan --all shows weak networks"
run_wifi "$SANDBOX" scan --all
assert_contains "Weak"

start_test "scan --all omits the footer"
run_wifi "$SANDBOX" scan --all
assert_not_contains "use 'wifi scan --all'"

# =============================================================================
section "list"
# =============================================================================

reset_mocks
export MOCK_CONN_LIST=""
start_test "no saved networks"
run_wifi "$SANDBOX" list
assert_contains "No saved networks"

reset_mocks
# connection show output: NAME:TYPE:ACTIVE — only wifi rows should appear
export MOCK_CONN_LIST="HomeNet:802-11-wireless:yes
OldCafe:802-11-wireless:no
Wired1:802-3-ethernet:no"

start_test "list shows a saved wifi network"
run_wifi "$SANDBOX" list
assert_contains "HomeNet"

start_test "list marks the connected network"
run_wifi "$SANDBOX" list
assert_contains "connected"

start_test "list excludes non-wifi connections"
run_wifi "$SANDBOX" list
assert_not_contains "Wired1"

# =============================================================================
section "disconnect"
# =============================================================================

reset_mocks
export MOCK_ACTIVE_LIST=""   # nothing active
start_test "not connected"
run_wifi "$SANDBOX" disconnect <<< "y"
assert_contains "Not connected to any network"

reset_mocks
export MOCK_ACTIVE_LIST="yes:HomeNet"
export MOCK_DEV_LIST="wlan0:wifi"
export MOCK_DISCONNECT_RC="0"
start_test "decline disconnect"
run_wifi "$SANDBOX" disconnect <<< "n"
assert_contains "Cancelled"

start_test "confirm disconnect succeeds"
run_wifi "$SANDBOX" disconnect <<< "y"
assert_contains "HomeNet disconnected"

reset_mocks
export MOCK_ACTIVE_LIST="yes:HomeNet"
export MOCK_DEV_LIST="wlan0:wifi"
export MOCK_DISCONNECT_RC="1"   # nmcli fails
start_test "disconnect failure is reported"
run_wifi "$SANDBOX" disconnect <<< "y"
assert_contains "Failed to disconnect"

# =============================================================================
section "connect"
# =============================================================================

# Six usable networks (>=20%) plus one weak one. Default view shows top 5.
CONNECT_LIST="*:HomeNet:80:WPA2
:OpenCafe:60:
:CafeB:58:
:Library:50:WPA2
:Gym:45:WPA2
:OpenFar:30:
:Weak:10:WPA2"

reset_mocks
export MOCK_WIFI_LIST=""
start_test "connect with no networks"
run_wifi "$SANDBOX" connect <<< ""
assert_contains "No networks found"

reset_mocks
export MOCK_WIFI_LIST="$CONNECT_LIST"
export MOCK_CONNECT_MODE="success"
start_test "connect to an open network (no password prompt)"
run_wifi "$SANDBOX" connect <<< "2"
assert_contains "OpenCafe connected!"

reset_mocks
export MOCK_WIFI_LIST="$CONNECT_LIST"
export MOCK_CONNECT_MODE="success"
start_test "connect to a secured network with a password"
run_wifi "$SANDBOX" connect <<< $'4\nhunter2'
assert_contains "Library connected!"

reset_mocks
export MOCK_WIFI_LIST="$CONNECT_LIST"
export MOCK_KNOWN_SSIDS="Library"
export MOCK_CONNECT_MODE="success"
start_test "connect to a known network skips the password prompt"
run_wifi "$SANDBOX" connect <<< "4"
assert_contains "Library connected!"

reset_mocks
export MOCK_WIFI_LIST="$CONNECT_LIST"
set_connect_sequence "badpass success"
start_test "wrong password then retry succeeds"
run_wifi "$SANDBOX" connect <<< $'4\nwrongpass\nt\ncorrectpass'
assert_contains "Incorrect password"

start_test "retry after wrong password connects"
set_connect_sequence "badpass success"
run_wifi "$SANDBOX" connect <<< $'4\nwrongpass\nt\ncorrectpass'
assert_contains "Library connected!"

reset_mocks
export MOCK_WIFI_LIST="$CONNECT_LIST"
set_connect_sequence "badpass success"
start_test "wrong password then back-to-list, pick open network"
run_wifi "$SANDBOX" connect <<< $'4\nwrongpass\nl\n2'
assert_contains "OpenCafe connected!"

reset_mocks
export MOCK_WIFI_LIST="$CONNECT_LIST"
export MOCK_CONNECT_MODE="success"
start_test "'more' reveals the 6th network and connects"
run_wifi "$SANDBOX" connect <<< $'more\n6'
assert_contains "OpenFar connected!"

reset_mocks
export MOCK_WIFI_LIST="$CONNECT_LIST"
export MOCK_CONNECT_MODE="success"
start_test "invalid selection then valid one"
run_wifi "$SANDBOX" connect <<< $'abc\n2'
assert_contains "OpenCafe connected!"

reset_mocks
export MOCK_WIFI_LIST="$CONNECT_LIST"
set_connect_sequence "fail success"
start_test "non-password failure returns to list, then succeeds"
run_wifi "$SANDBOX" connect <<< $'2\n2'
assert_contains "Could not connect"

start_test "after a generic failure a retry can connect"
set_connect_sequence "fail success"
run_wifi "$SANDBOX" connect <<< $'2\n2'
assert_contains "OpenCafe connected!"

# =============================================================================
section "init"
# =============================================================================

reset_mocks
export MOCK_SYSTEMCTL_RC="0"
start_test "nmcli installed and service running"
run_wifi "$SANDBOX" init
assert_contains "NetworkManager is running"

reset_mocks
export MOCK_SYSTEMCTL_RC="1"
start_test "nmcli installed but service stopped"
run_wifi "$SANDBOX" init
assert_contains "NetworkManager is not running"

reset_mocks
export MOCK_UNAME="Darwin"
start_test "not installed on macOS suggests brew"
run_wifi "$SANDBOX_NO" init
assert_contains "brew install"

reset_mocks
export MOCK_UNAME="Linux"
start_test "not installed on Linux suggests a package manager"
run_wifi "$SANDBOX_NO" init
# Host is Arch, so init reads /etc/os-release and recommends pacman.
assert_contains "pacman"

# =============================================================================
print_summary
