# cua-agent-app

A thin CLI over the [`cua`](https://pypi.org/project/cua/) Sandbox SDK for controlling the `tendril-mac` Lume VM — or any other VM running cua's `computer-server` (e.g. a Windows VM in UTM, see [Driving a UTM Windows VM](#driving-a-utm-windows-vm)). Any Cursor agent uses these commands as **eyes and hands** while following the [install-tendril-in-mac-vm](../skills/install-tendril-in-mac-vm/SKILL.md) skill runbook.

Each subcommand connects to the VM and calls a single cua SDK method — `sb.screenshot()`, `sb.mouse.*`, `sb.keyboard.*`, or `sb.get_dimensions()`. The app defines **no input or coordinate primitives of its own**; the SDK owns those. See the [cua docs](https://cua.ai/docs/cua/guide/get-started/what-is-cua).

Uses the **Lume** runtime to attach to an already-running local VM (no clone or pull).

## Requirements

- macOS (Apple Silicon) with [Lume](https://github.com/trycua/cua) installed
- A Lume VM named `tendril-mac` (started via `lume run tendril-mac`)
- `computer-server` running in the VM on port 8443 — see [connect-cua-lume-macos-vm](../skills/connect-cua-lume-macos-vm/SKILL.md)
- Python `>=3.12,<3.14`
- [`uv`](https://docs.astral.sh/uv/) for dependency management
- Repo-root [`.env`](../.env) with `LUME_VM_NAME` (and related vars)

No LLM API keys required — the invoking Cursor agent drives the install loop.

## Setup

```bash
uv sync
```

Start the VM and confirm CUA connectivity before using the CLI:

```bash
set -a && source ../.env && set +a
lume run "${LUME_VM_NAME:-tendril-mac}"
cd cua-agent-app && uv run main.py screenshot --out screenshots/00-ready.png
```

## CLI commands

Each command connects to the VM, performs one action, and disconnects (VM stays running).

| Command | SDK call | Example |
|---|---|---|
| `dimensions` | `sb.get_dimensions()` | `uv run main.py dimensions` |
| `screenshot` | `sb.screenshot()` | `uv run main.py screenshot --out screenshots/01.png` |
| `click` | `sb.mouse.click` | `uv run main.py click --x 420 --y 310` |
| `double-click` | `sb.mouse.double_click` | `uv run main.py double-click --x 100 --y 200` |
| `right-click` | `sb.mouse.right_click` | `uv run main.py right-click --x 100 --y 200` |
| `move` | `sb.mouse.move` | `uv run main.py move --x 100 --y 200` |
| `drag` | `sb.mouse.drag` | `uv run main.py drag --x1 10 --y1 10 --x2 80 --y2 80` |
| `scroll` | `sb.mouse.scroll` | `uv run main.py scroll --x 500 --y 400 --dy -5` |
| `type` | `sb.keyboard.type` | `uv run main.py type --text "https://..."` |
| `keypress` | `sb.keyboard.keypress` | `uv run main.py keypress --keys cmd,space` |

Coordinates use the SDK screen space from `dimensions`. On Retina VMs the saved screenshot PNG may differ in pixel size from that screen space; if so, scale a point measured on the PNG by `screen / png` before clicking.

```bash
uv run main.py --help
```

## Agent workflow

The install runbook lives in the skill, not in this app:

1. `screenshot` → agent interprets the image
2. `click` / `type` / `keypress` → next human-like action
3. Repeat until Tendril's native macOS app is visible

See [`skills/install-tendril-in-mac-vm/SKILL.md`](../skills/install-tendril-in-mac-vm/SKILL.md) for the full cold-start → GUI install → fallback procedure.

## Project structure

```
cua-agent-app/
├── main.py              # Thin SDK CLI: dimensions, screenshot, mouse + keyboard
├── vm.py                # Sandbox connect/disconnect + .env loading
├── pyproject.toml
├── uv.lock
└── screenshots/         # Step evidence (gitignored outputs except .gitkeep)
```

## How it works

1. `vm.py` loads `LUME_VM_NAME` (or `CUA_WS_URL`) from the repo-root `.env`.
2. `Sandbox.create(Image.macos(), name=..., local=True)` attaches to the running Lume VM — or, when `CUA_WS_URL` is set, `Sandbox.connect(name, ws_url=...)` connects directly to a `computer-server`.
3. Each subcommand calls one cua SDK method — `sb.screenshot()`, `sb.mouse.*`, `sb.keyboard.*`, or `sb.get_dimensions()` — and nothing else.
4. `sb.disconnect()` leaves the VM running.

## Driving a UTM Windows VM

The Lume runtime only exists to find the VM's IP and provision `computer-server` inside it. With a UTM Windows guest you do those two steps by hand once, then the exact same CLI commands work. The full runbook (including a guest provisioning script) lives in [connect-cua-utm-windows-vm](../skills/connect-cua-utm-windows-vm/SKILL.md); the short version follows.

### 1. One-time setup inside the Windows guest

- Install Python 3.12+ from [python.org](https://www.python.org/downloads/windows/) (check **Add python.exe to PATH** in the installer).
- In PowerShell:

  ```powershell
  pip install cua-computer-server
  python -m computer_server          # listens on port 8000, WebSocket at /ws
  ```

- Allow the port through Windows Defender Firewall when prompted (or pre-allow it):

  ```powershell
  netsh advfirewall firewall add rule name="cua computer-server" dir=in action=allow protocol=TCP localport=8000
  ```

- To make it start on login, put the `python -m computer_server` command in a Task Scheduler "At log on" task or a shortcut in `shell:startup`.

### 2. UTM networking

Use UTM's **Shared Network** mode (the default) so the guest gets an IP the Mac host can reach. Find it inside the guest with `ipconfig` (the IPv4 address, typically `192.168.64.x`).

If the VM uses **Emulated VLAN** instead, add a port forward in UTM (guest 8000 → host 8000) and use `ws://127.0.0.1:8000/ws` below.

### 3. Point the CLI at it

In the repo-root `.env`:

```bash
CUA_WS_URL=ws://192.168.64.X:8000/ws
CUA_VM_NAME=tendril-win   # optional, label only
```

Then every command works unchanged:

```bash
uv run main.py screenshot --out screenshots/win-00.png
uv run main.py click --x 420 --y 310
uv run main.py keypress --keys ctrl,c
```

Remove or comment out `CUA_WS_URL` to fall back to the Lume macOS VM.

Notes:

- Windows shortcuts use `ctrl`/`alt`/`win`, not `cmd` — e.g. `keypress --keys win,r` to open Run.
- The guest IP can change across reboots under Shared Network; re-check with `ipconfig` if connections start failing.
- `dimensions` reports the guest's native resolution; no Retina scaling applies on Windows guests, so screenshot pixels map 1:1 to click coordinates.
