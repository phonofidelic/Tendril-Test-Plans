---
name: connect-cua-utm-macos-vm
description: >-
  Connect a cua (trycua) Sandbox to a macOS VM running under UTM on a macOS
  host, by provisioning cua's computer-server inside the guest and connecting
  directly via http_url (no Lume/runtime). Use when driving a UTM macOS guest
  with cua-agent-app, when connecting to the guest fails with
  ConnectionRefusedError, when screenshots fail with "could not create image
  from display" (Screen Recording / TCC), or when clicks land at ~2x the
  intended coordinates (Retina/HiDPI scaling).
license: MIT
compatibility: >-
  Requires an Apple Silicon macOS host with UTM (macOS guests need the Apple
  Virtualization backend, not QEMU), uv, and the cua-agent-app CLI, plus a
  macOS 13+ guest with network access from the host to the in-guest
  computer-server on port 8000.
---

# Connect a cua Sandbox to a UTM macOS VM

UTM is not a cua runtime — there is no IP discovery and `Image.macos()` does
not apply (it selects the **Lume** runtime, which cannot see UTM VMs).
Instead, the cua SDK connects **directly** to a `computer-server` running
inside the macOS guest, using its HTTP base URL:

```python
import asyncio
from cua import Sandbox

async def main():
    sb = await Sandbox.connect("tendril-macos", http_url="http://192.168.64.X:8000")
    try:
        png = await sb.screenshot()
        open("screenshot.png", "wb").write(png)
    finally:
        await sb.disconnect()  # leaves the VM running

asyncio.run(main())
```

`cua-agent-app` already supports this: set `CUA_HTTP_URL` (and optionally
`CUA_VM_NAME`) in the repo-root `.env` and every CLI command works unchanged
(step 4).

Gotchas:
- Use `http_url=`, **not** `ws_url=`. The `ws_url` WebSocketTransport speaks
  an older protocol: against a current computer-server, `get_dimensions()`
  raises `KeyError: 'width'` and `screenshot()` raises
  `ValueError: requested 'png' but got 'unknown' (magic bytes: )`.
  `HTTPTransport` parses the current schema.
- Do **not** use `Sandbox.create(Image.macos(), name=..., local=True)`: that
  path is the Lume runtime (see
  [connect-cua-lume-macos-vm](../connect-cua-lume-macos-vm/SKILL.md)) and
  fails for a VM that exists only in UTM.
- With `http_url` set, the `name` argument is only a label; no image/runtime
  is involved.
- `http://<ip>:8000/status` is the health endpoint — expect
  `{"status":"ok","os_type":"darwin",...}`.

## 1. Provision computer-server inside the macOS guest

Run `scripts/provision-computer-server.sh` **inside the VM** as the desktop
user (it needs no Xcode Command Line Tools — `uv` brings its own Python).
The script:

- installs `uv` and creates a venv at `~/cua-server-env` with
  `cua-computer-server`,
- installs a GUI-session LaunchAgent (`com.trycua.computer_server`) on
  port 8000 — a LaunchAgent, not a LaunchDaemon, because screenshots and
  input only work from inside the logged-in GUI session,
- starts it now and curls `http://localhost:8000/status`.

Get the script into the guest by enabling Remote Login in the guest
(System Settings → General → Sharing → Remote Login) and piping it from the
host, or paste it into Terminal. A UTM shared directory (VirtioFS) also works
on macOS 13+ guests.

```bash
# from the host; guest IP from step 2
ssh user@192.168.64.X 'bash -s' < skills/connect-cua-utm-macos-vm/scripts/provision-computer-server.sh
```

## 2. Screen Recording (TCC) — the key macOS blocker

After provisioning, screenshots will fail until the python interpreter is
granted **Screen Recording** permission — as
**"could not create image from display"** on older server versions, or as
**`Command '['screencapture', '-x', ...]' returned non-zero exit status 1`**
on current ones (the server shells out to `screencapture`). Either way it is
NOT a code or port problem:

- Granting requires the VM **GUI** (it cannot be done over SSH): in the
  guest, System Settings → Privacy & Security → Screen & System Audio
  Recording → enable the `python3.12` entry (it appears after the first
  failed capture attempt).
- The grant is keyed by the resolved interpreter path — the real uv Python
  (`~/.local/share/uv/python/cpython-*/bin/python3.12`), which the venv
  python symlinks to. Verify in the system TCC db:
  ```bash
  sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
    'select service,client,auth_value from access where service="kTCCServiceScreenCapture";'
  ```
  `auth_value=2` means allowed.
- TCC changes only apply on process restart. After granting:
  ```bash
  launchctl kickstart -k gui/$(id -u)/com.trycua.computer_server
  ```
- There must be an active GUI login (`stat -f %Su /dev/console` should show
  the user, not `_windowserver`/`loginwindow`).

## 3. UTM networking — find the guest address

- **Shared Network** (UTM default): the guest gets a host-reachable IP,
  typically `192.168.64.x` — but each VM may get its **own bridge/subnet**
  (observed: a macOS guest on `192.168.65.x` while other guests sat on
  `192.168.64.x`). Inside the guest run `ipconfig getifaddr en0`; from the
  host, read the shared-network DHCP leases (works even when
  `utmctl ip-address` fails with "Operation not supported by the backend",
  as it does for Apple Virtualization guests):
  ```bash
  cat /var/db/dhcpd_leases | tr -d '\t' | paste -sd' ' - | sed 's/}/}\n/g'
  ```
  Match by guest hostname / newest lease. The IP **and subnet** can change
  across reboots — re-check if connections start failing.
- **Emulated VLAN**: the guest is NATed and not directly reachable. In the
  VM's UTM settings add a port forward (guest 8000 → host 8000) and use
  `http://127.0.0.1:8000`.

Verify from the host before involving the SDK:

```bash
curl -s -m5 http://192.168.64.X:8000/status
# expect {"status":"ok","os_type":"darwin",...}
```

## 4. Point cua-agent-app at the guest

In the repo-root `.env` (gitignored; see `.env.example`):

```bash
CUA_HTTP_URL=http://192.168.64.X:8000
CUA_VM_NAME=tendril-macos   # label only
```

Then from `cua-agent-app/`:

```bash
uv run main.py dimensions
uv run main.py screenshot --out screenshots/macos-00.png
uv run main.py click --x 420 --y 310
uv run main.py keypress --keys cmd,space
```

Remove or comment out `CUA_HTTP_URL` to fall back to the Lume macOS VM
(`LUME_VM_NAME`, see [connect-cua-lume-macos-vm](../connect-cua-lume-macos-vm/SKILL.md)).

macOS-specific input notes:
- Shortcuts use `cmd` — e.g. `cmd,c`, `cmd,space` (Spotlight), `cmd,q` —
  unlike the Windows (`win`) and Ubuntu (`super`) guests. Key names follow
  the server's hotkey table: `esc`, not `escape`.
- **Coordinate space (Retina/HiDPI):** mouse coordinates are in the guest's
  **logical display space**. With UTM's default (non-Retina) display this is
  **1:1** with `dimensions` and screenshot pixels (verified: 1616×1010
  everywhere); with Retina/HiDPI enabled in the VM's UTM Display settings
  expect the Lume situation instead (logical 1024×768 vs 2048×1536 pixels —
  divide by 2). Calibrate before trusting coordinates: right-click anywhere;
  the context menu's top-left corner appears at the coordinate you passed
  (x exact, y within ~30 px of menu-placement offset). If scaled, measure
  click targets as a **fraction** of the screenshot and multiply by the
  logical size from System Settings → Displays.

## 5. Session must stay logged in, unlocked — and the guest must never sleep

**Sleep is fatal, not cosmetic.** When a UTM macOS guest sleeps, its vmnet
bridge is torn down on the host (the guest's whole subnet disappears from
`ifconfig`) and the guest may show a black screen and **never wake** —
the only recovery is restarting the VM. The provisioning script disables
the screen saver and tries `pmset -a sleep 0 displaysleep 0 disksleep 0`
(needs sudo; run it manually in the guest if the script could not).

Input and screenshots act on the guest's interactive desktop. If macOS is
sitting at the login window or the screen is locked, the LaunchAgent isn't
running (or captures the lock screen) and clicks do nothing. For unattended
runs, in the guest:

- enable automatic login (System Settings → Users & Groups → Automatically
  log in as),
- set Lock Screen → "Require password after…" to Never,
- confirm sleep is off: `pmset -g | grep -E " sleep|displaysleep"` should
  show 0s.

Closing the UTM display window is fine (the VM keeps running headless);
stopping the VM is not.

## Quick troubleshooting map

| Symptom | Cause | Fix |
|---|---|---|
| `ConnectionRefusedError` to guest IP | computer-server not running, or no GUI login (LaunchAgent not loaded) | log in to the guest GUI; re-run the script (steps 1, 5) |
| Connect hangs / times out | wrong IP (changed on reboot) or Emulated VLAN without port forward | re-check `ipconfig getifaddr en0`; add port forward (step 3) |
| `could not create image from display` / `screencapture -x ... exit status 1` | Screen Recording not granted, or server started before the grant | grant in GUI + kickstart the agent (step 2) |
| `KeyError: 'width'` / `requested 'png' but got 'unknown'` | connected with `ws_url=` (legacy-protocol transport) | use `http_url=` / `CUA_HTTP_URL` (top of this skill) |
| `No local sandbox named ... found` | used `Sandbox.connect(name, local=True)` | pass `http_url=` instead (top of this skill) |
| Clicks land ~2× off / hit the wallpaper | pixel coordinates passed in a HiDPI guest | use logical coordinates; calibrate with the right-click trick (step 4) |
| Screenshots OK but clicks/keys silently ignored | guest at login/lock screen; if unlocked, check Accessibility permission for `python3.12` (Privacy & Security → Accessibility) | unlock / auto-login (step 5); grant + kickstart (step 2) |
| `keypress --keys win,...` / `super,...` does nothing | non-macOS key name on macOS guest | use `cmd` |
| `Unknown key in hotkey: escape` | full key name not in the server's hotkey table | use `esc` |
| Works, then fails after guest reboot | Shared Network IP/subnet changed, or login window (no auto-login) | re-read `/var/db/dhcpd_leases`, update `CUA_HTTP_URL` (steps 3, 5) |
| Guest unreachable, UTM window black, won't wake | guest slept; vmnet bridge torn down on host | restart the VM; disable sleep via `pmset` (step 5) |
| `utmctl ip-address` → "Operation not supported by the backend" | Apple Virtualization backend lacks the guest-agent query | read `/var/db/dhcpd_leases` on the host (step 3) |
