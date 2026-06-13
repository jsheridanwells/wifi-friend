# WiFi Friend

A simple, idiomatic command-line utility for managing your machine's wifi connections

This utility wraps `nmcli` to run normal wifi manager commands (connect,
disconnect, scan, list, etc.) and not have to remember too much.

## Installation

You'll need `nmcli` installed first. If you're not sure whether you have it, `wifi init` will
check and tell you what to run if you don't.

To install...

```bash
sudo bash install.sh
```

That copies `wifi` to `/usr/local/bin` and the supporting command files to `/usr/local/lib/wifi`.

## Usage

```
wifi <command> [options]
```

| Command      | Alias | What it does                                      |
|--------------|-------|---------------------------------------------------|
| `status`     | —     | Show whether you're connected and to what network |
| `scan`       | `s`   | List available networks sorted by signal strength |
| `list`       | `l`   | List networks you've connected to before          |
| `connect`    | `c`   | Pick a network from a menu and connect to it      |
| `disconnect` | `d`   | Disconnect from the current network               |
| `init`       | —     | Check for nmcli and show install instructions     |

`scan` hides networks below 20% signal by default — they're usually not worth connecting to
anyway. Pass `--all` if you want to see everything:

```bash
wifi scan --all
```

`connect` shows the top 5 networks by signal strength. Type `more` at the prompt if you need
to see the full list.

## Development

The project is a single entry point (`wifi.sh`) that dispatches to one file per subcommand
in the `commands/` directory. You can run it directly from the repo without installing:

```bash
bash wifi.sh status
bash wifi.sh scan
```

The tests mock `nmcli` via PATH injection so it never touches real hardware.

```bash
bash tests/run_tests.sh
```

After making changes, reinstall with `sudo bash install.sh` to push the updates to
`/usr/local/bin` and `/usr/local/lib/wifi`.

