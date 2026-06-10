---
name: connect-cua-utm-windows-vm
description: >-
  Connect a cua (trycua) Sandbox to a Windows VM running under UTM on a macOS
  host, by provisioning cua's computer-server inside the guest and connecting
  directly via http_url (no Lume/runtime). Use when driving a UTM Windows
  guest with cua-agent-app, when connecting to the guest fails with
  ConnectionRefusedError, "KeyError: 'width'", or "requested 'png' but got
  'unknown'", or when clicks/screenshots silently do nothing on a Windows
  guest.
license: MIT
compatibility: >-
  Requires a macOS host with UTM, uv, and the cua-agent-app CLI, plus a
  Windows 10/11 guest with Python 3.12+ and network access from the host to
  the in-guest computer-server on port 8000.
---

# Connect a cua Sandbox to a UTM Windows VM

UTM is not a cua runtime — there is no `Image.windows()` local path and no IP
discovery. Instead, the cua SDK connects **directly** to a `computer-server`
running inside the Windows guest, using its HTTP base URL:

```python
import asyncio
from cua import Sandbox

async def main():
    sb = await Sandbox.connect("tendril-win", http_url="http://192.168.64.X:8000")
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
  `ValueError: requested 'png' but got 'unknown' (magic bytes: )` — the
  server replies `{"success": true, "image_data"/"size": ...}` while that
  transport expects `{"result": ...}`. `HTTPTransport` (the same transport
  the Lume runtime uses) parses the current schema.
- With `http_url` set, the `name` argument is only a label; no image/runtime
  is involved.
- Do **not** use `Sandbox.create(Image.windows(), ..., local=True)`: the local
  Windows path targets Windows Sandbox on a Windows host, not UTM.
- `http://<ip>:8000/status` is the health endpoint.

## 1. Provision computer-server inside the Windows guest

Run `scripts/provision-computer-server.ps1` **inside the VM** in an elevated
PowerShell (Python 3.12+ from python.org must already be on PATH — check
"Add python.exe to PATH" in its installer). The script:

- creates a venv at `%USERPROFILE%\cua-server-env` with `cua-computer-server`,
- opens TCP 8000 in Windows Defender Firewall,
- registers a Scheduled Task (`cua-computer-server`, "At log on" of the
  current user, interactive) so the server starts with each login,
- starts it now and curls `http://localhost:8000/status`.

Get the script into the guest via a UTM shared directory, or paste it into
PowerShell ISE/Notepad. Then:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\provision-computer-server.ps1
```

The server must run in the **interactive desktop session** (hence a logon
Scheduled Task, not a Windows service): a service runs in Session 0 where
screenshots come back black and input goes nowhere.

## 2. UTM networking — find the guest address

- **Shared Network** (UTM default): the guest gets a host-reachable IP,
  typically `192.168.64.x`. Inside the guest run `ipconfig` and read the IPv4
  address. This IP can change across reboots — re-check it if connections
  start failing.
- **Emulated VLAN**: the guest is NATed and not directly reachable. In the
  VM's UTM settings add a port forward (guest 8000 → host 8000) and use
  `http://127.0.0.1:8000`.

Verify from the macOS host before involving the SDK:

```bash
curl -s -m5 http://192.168.64.X:8000/status
# expect {"status":"ok","os_type":"windows",...}
```

## 3. Point cua-agent-app at the guest

In the repo-root `.env` (gitignored; see `.env.example`):

```bash
CUA_HTTP_URL=http://192.168.64.X:8000
CUA_VM_NAME=tendril-win   # label only
```

Then from `cua-agent-app/`:

```bash
uv run main.py dimensions
uv run main.py screenshot --out screenshots/win-00.png
uv run main.py click --x 420 --y 310
uv run main.py keypress --keys win,r
```

Remove or comment out `CUA_HTTP_URL` to fall back to the Lume macOS VM
(`LUME_VM_NAME`, see [connect-cua-lume-macos-vm](../connect-cua-lume-macos-vm/SKILL.md)).

Windows-specific input notes:
- Shortcuts use `ctrl` / `alt` / `win`, never `cmd` — e.g. `ctrl,c`, `alt,f4`,
  `win,r`.
- No Retina scaling on Windows guests: screenshot pixels map 1:1 to the
  coordinate space reported by `dimensions`.

## 4. Screen must stay unlocked

Input and screenshots act on the guest's interactive desktop. If Windows is
sitting at the lock screen / signed out, clicks do nothing and screenshots show
the lock screen. Keep the user signed in, and consider disabling sleep and the
lock timeout in guest Settings → Accounts / Power for unattended runs. Closing
the UTM display window is fine (the VM keeps running headless); stopping the
VM is not.

## Quick troubleshooting map

| Symptom | Cause | Fix |
|---|---|---|
| `ConnectionRefusedError` to guest IP | computer-server not running, or firewall | re-run Scheduled Task; check firewall rule (step 1) |
| Connect hangs / times out | wrong IP (changed on reboot) or Emulated VLAN without port forward | re-check `ipconfig`; add port forward (step 2) |
| `KeyError: 'width'` / `requested 'png' but got 'unknown'` | connected with `ws_url=` (legacy-protocol transport) | use `http_url=` / `CUA_HTTP_URL` (top of this skill) |
| `No local sandbox named ... found` | used `Sandbox.connect(name, local=True)` | pass `http_url=` instead (top of this skill) |
| Screenshot is black / input ignored | server running in Session 0 (service) or lock screen active | use the logon Scheduled Task; keep user signed in (steps 1, 4) |
| `keypress --keys cmd,...` does nothing | macOS key name on Windows guest | use `ctrl` / `alt` / `win` |
| Works, then fails after guest reboot | Shared Network IP changed | update `CUA_HTTP_URL` in `.env` |
