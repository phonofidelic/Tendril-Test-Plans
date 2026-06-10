---
name: connect-cua-utm-ubuntu-vm
description: >-
  Connect a cua (trycua) Sandbox to an Ubuntu VM running under UTM on a macOS
  host, by provisioning cua's computer-server inside the guest and connecting
  directly via http_url (no Lume/runtime). Use when driving a UTM Ubuntu guest
  with cua-agent-app, when connecting to the guest fails with
  ConnectionRefusedError, when screenshots come back black/empty or input is
  silently ignored (Wayland session), or when the server logs Xlib/"can't
  connect to display" errors.
license: MIT
compatibility: >-
  Requires a macOS host with UTM, uv, and the cua-agent-app CLI, plus an
  Ubuntu 24.04+ guest running an Xorg (not Wayland) desktop session with
  Python 3.12+ and network access from the host to the in-guest
  computer-server on port 8000.
---

# Connect a cua Sandbox to a UTM Ubuntu VM

UTM is not a cua runtime — there is no local-image path and no IP discovery.
Instead, the cua SDK connects **directly** to a `computer-server` running
inside the Ubuntu guest, using its HTTP base URL:

```python
import asyncio
from cua import Sandbox

async def main():
    sb = await Sandbox.connect("tendril-ubuntu", http_url="http://192.168.64.X:8000")
    try:
        png = await sb.screenshot()
        open("screenshot.png", "wb").write(png)
    finally:
        await sb.disconnect()  # leaves the VM running

asyncio.run(main())
```

`cua-agent-app` already supports this: set `CUA_HTTP_URL` (and optionally
`CUA_VM_NAME`) in the repo-root `.env` and every CLI command works unchanged
(step 3).

Gotchas:
- Use `http_url=`, **not** `ws_url=`. The `ws_url` WebSocketTransport speaks
  an older protocol: against a current computer-server, `get_dimensions()`
  raises `KeyError: 'width'` and `screenshot()` raises
  `ValueError: requested 'png' but got 'unknown' (magic bytes: )`.
  `HTTPTransport` parses the current schema.
- With `http_url` set, the `name` argument is only a label; no image/runtime
  is involved.
- The guest desktop session **must be Xorg, not Wayland**. Ubuntu defaults to
  Wayland, where the server cannot capture the screen or inject input —
  screenshots come back black/empty and clicks silently do nothing. The
  provisioning script refuses to run under Wayland and prints the fix
  (step 1).
- `http://<ip>:8000/status` is the health endpoint — expect
  `{"status":"ok","os_type":"linux",...}`.

## 1. Provision computer-server inside the Ubuntu guest

Run `scripts/provision-computer-server.sh` **inside the VM** as the desktop
user (it uses `sudo` where needed — do not run the whole script as root).
The script:

- verifies the session is Xorg; if it finds Wayland it exits with the
  `gdm3` one-liner to disable Wayland and asks you to re-run after relogin,
- installs apt dependencies (`python3-venv`, `python3-tk`, `gnome-screenshot`,
  `scrot`, `xdotool`, …) and checks Python is 3.12+,
- creates a venv at `~/cua-server-env` with `cua-computer-server`,
- opens TCP 8000 in ufw if ufw is active,
- disables screen blanking and the lock screen for unattended runs,
- registers an XDG autostart entry (`~/.config/autostart/`) so the server
  starts with each graphical login,
- starts it now and curls `http://localhost:8000/status`.

Get the script into the guest via a UTM shared directory, `scp` from the
host (if the guest runs sshd), or paste it into a terminal editor. Then:

```bash
bash provision-computer-server.sh
```

The server must run **inside the graphical session** (hence an autostart
entry, not a systemd system service): a system service has no
`DISPLAY`/`XAUTHORITY`, so screenshots fail and input goes nowhere — the
Linux equivalent of Windows Session 0.

Ubuntu 24.04 LTS ships Python 3.12. On 22.04 (Python 3.10) install 3.12 from
the deadsnakes PPA first, or use a 24.04+ image.

## 2. UTM networking — find the guest address

- **Shared Network** (UTM default): the guest gets a host-reachable IP,
  typically `192.168.64.x`. Inside the guest run `hostname -I` (or
  `ip -4 addr`) and read the address. This IP can change across reboots —
  re-check it if connections start failing.
- **Emulated VLAN**: the guest is NATed and not directly reachable. In the
  VM's UTM settings add a port forward (guest 8000 → host 8000) and use
  `http://127.0.0.1:8000`.

Verify from the macOS host before involving the SDK:

```bash
curl -s -m5 http://192.168.64.X:8000/status
# expect {"status":"ok","os_type":"linux",...}
```

## 3. Point cua-agent-app at the guest

In the repo-root `.env` (gitignored; see `.env.example`):

```bash
CUA_HTTP_URL=http://192.168.64.X:8000
CUA_VM_NAME=tendril-ubuntu   # label only
```

Then from `cua-agent-app/`:

```bash
uv run main.py dimensions
uv run main.py screenshot --out screenshots/ubuntu-00.png
uv run main.py click --x 420 --y 310
uv run main.py keypress --keys ctrl,alt,t
```

Remove or comment out `CUA_HTTP_URL` to fall back to the Lume macOS VM
(`LUME_VM_NAME`, see [connect-cua-lume-macos-vm](../connect-cua-lume-macos-vm/SKILL.md)).

Linux-specific input notes:
- Shortcuts use `ctrl` / `alt` / `super`, never `cmd` — e.g. `ctrl,c`,
  `alt,f4`, `ctrl,alt,t` (terminal).
- Keep GNOME display scaling at 100% (Settings → Displays): with fractional
  or 200% scaling, screenshot pixels no longer map 1:1 to the coordinate
  space reported by `dimensions`.

## 4. Session must stay unlocked (and stay Xorg)

Input and screenshots act on the guest's interactive desktop. If Ubuntu is
sitting at the GDM login screen or the session is locked, clicks do nothing
and screenshots show the lock screen. The provisioning script disables screen
blanking and the lock screen; additionally enable automatic login
(Settings → Users → Automatic Login) so the graphical session — and with it
the autostart entry — comes up after a reboot without interaction. Closing
the UTM display window is fine (the VM keeps running headless); stopping the
VM is not.

## Quick troubleshooting map

| Symptom | Cause | Fix |
|---|---|---|
| `ConnectionRefusedError` to guest IP | computer-server not running, or ufw blocking 8000 | re-login or re-run the script; `sudo ufw status` (step 1) |
| Connect hangs / times out | wrong IP (changed on reboot) or Emulated VLAN without port forward | re-check `hostname -I`; add port forward (step 2) |
| Screenshot black/empty, input ignored | Wayland session, or server started without `DISPLAY` (system service) | switch to Xorg; use the autostart entry (step 1) |
| Server log shows Xlib / "can't connect to display" | server launched outside the graphical session | start via the autostart entry, not ssh/systemd (step 1) |
| `KeyError: 'width'` / `requested 'png' but got 'unknown'` | connected with `ws_url=` (legacy-protocol transport) | use `http_url=` / `CUA_HTTP_URL` (top of this skill) |
| `No local sandbox named ... found` | used `Sandbox.connect(name, local=True)` | pass `http_url=` instead (top of this skill) |
| Clicks land at wrong coordinates | GNOME display scaling ≠ 100% | set scaling to 100% (step 3) |
| `keypress --keys cmd,...` does nothing | macOS key name on Linux guest | use `ctrl` / `alt` / `super` |
| Works after script, dead after reboot | sat at GDM login screen (autostart never ran) | enable automatic login (step 4) |
| Works, then fails after guest reboot | Shared Network IP changed | update `CUA_HTTP_URL` in `.env` |
