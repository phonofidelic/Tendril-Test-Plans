---
name: connect-cua-lume-macos-vm
description: >-
  Connect a cua (trycua) Sandbox to an existing Lume macOS VM by name, and
  provision the in-VM computer-server it requires. Use when attaching a cua
  Sandbox/ComputerAgent to a running lume VM (e.g. tendril-mac), when
  Sandbox.create/connect fails with "No local sandbox named ... found" or a
  computer-server "not ready" timeout, or when screenshots fail with
  "could not create image from display".
---

# Connect a cua Sandbox to an existing Lume macOS VM

The cua SDK never controls a Lume VM directly. It talks to a `computer-server`
HTTP API running **inside** the VM on port **8443** (`LUME_API_PORT`). The host
Lume API (`:7777`) is only used to find/start the VM and read its IP.

## 1. Connect from the host

Use `Sandbox.create` with a macOS image and the VM's **exact lume name**.
`LumeRuntime` has a reuse fast-path: if a VM with that name is already running,
it attaches instead of cloning/pulling.

```python
import asyncio
from cua import Sandbox, Image

async def main():
    sb = await Sandbox.create(Image.macos(), name="<lume-vm-name>", local=True)
    try:
        png = await sb.screenshot()
        open("screenshot.png", "wb").write(png)
    finally:
        await sb.disconnect()  # leaves the VM running

asyncio.run(main())
```

Gotchas:
- `Sandbox.create(...)` is a coroutine — `await` it. `async with Sandbox.create(...)`
  fails with `'coroutine' object does not support the asynchronous context manager protocol`.
- `Sandbox.connect(name, local=True)` does **not** look at Lume; it only reads
  cua's own state files in `~/.cua/sandboxes/`. For a VM created by the Lume CLI
  it raises `No local sandbox named '<name>' found`. Use `create` + an image
  (above) instead.
- `Image.macos()` only selects the Lume runtime; no image is pulled because the
  named VM already exists.

## 2. The VM must be running computer-server on :8443

If the in-VM server is missing, the connect hangs in `is_ready()` and after
~120s raises `TimeoutError: Lume VM <name> computer-server not ready after 120s`.

Diagnose from the host (`192.168.64.x` is the VM IP from `lume ls`):

```bash
lume ls                                   # name, status, IP
curl -s -m5 http://192.168.64.2:8443/status   # expect {"status":"ok","os_type":"darwin",...}
```

Plain (non-trycua) macOS VMs do **not** ship computer-server — provision it
(step 3). trycua base images already have it as the `com.trycua.computer_server`
LaunchAgent.

## 3. Provision computer-server inside the VM

Run `scripts/provision-computer-server.sh` **inside the VM** (it needs no Xcode
Command Line Tools — `uv` brings its own Python). It installs `uv`, creates a
venv with `cua-computer-server`, installs a GUI-session LaunchAgent on :8443,
and starts it.

SSH into the VM first (see step 5), then either paste the script or pipe it:

```bash
# from the host; user/IP from `lume ls` and VM Sharing > Remote Login
ssh "${LUME_VM_SSH_USER}@${LUME_VM_IP}" 'bash -s' \
  < .cursor/skills/connect-cua-lume-macos-vm/scripts/provision-computer-server.sh
```

## 4. Screenshots fail: "could not create image from display" (Screen Recording / TCC)

This is the key non-obvious blocker. On macOS this message means the
computer-server process lacks **Screen Recording** permission (or its process
started before the grant). It is NOT a code or port problem.

- The grant lives in the **system** TCC db, keyed by the resolved interpreter path:
  ```bash
  sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
    'select service,client,auth_value from access where service="kTCCServiceScreenCapture";'
  ```
  `auth_value=2` means allowed. The `client` is the real uv Python
  (`~/.local/share/uv/python/cpython-*/bin/python3.12`), which the venv python
  symlinks to.
- Granting requires the VM **GUI** (it cannot be done over SSH): in the VM,
  System Settings → Privacy & Security → Screen & System Audio Recording →
  enable the `python3.12` entry.
- TCC changes only apply on process restart. After granting, restart the agent:
  ```bash
  launchctl kickstart -k gui/$(id -u)/com.trycua.computer_server
  ```
- There must be an active GUI login (`stat -f %Su /dev/console` should show the
  user, not `_windowserver`/loginwindow).

## 5. SSH into the lume VM

`lume ssh <name>` is often broken on this host (`Cache.db ... result=8` /
`End of file`); use direct SSH instead.

**Credentials:** read the SSH user from the VM GUI — System Settings → General →
Sharing → Remote Login (e.g. `ssh <user>@<ip>`). Copy `.env.example` → `.env` at
the repo root (`.env` is gitignored) and fill in values, then:

```bash
set -a && source .env && set +a
```

Password auth needs a helper (`sshpass` is usually absent). Use `expect`:

```bash
cat > /tmp/vmssh.exp <<'EOF'
#!/usr/bin/expect -f
set timeout 90
set user $env(LUME_VM_SSH_USER)
set host $env(LUME_VM_IP)
set pw $env(LUME_VM_SSH_PASSWORD)
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o PubkeyAuthentication=no -o PreferredAuthentications=password,keyboard-interactive \
  -o NumberOfPasswordPrompts=1 $user@$host [lindex $argv 0]
expect { -re {[Pp]assword:} { send "$pw\r"; exp_continue } eof }
EOF
expect /tmp/vmssh.exp 'curl -s localhost:8443/status'
```

Note: `LumeRuntime._deliver_vnc_config` also shells out to `lume ssh`, but it
swallows failures, so the broken `lume ssh` does not block the SDK connection.

## Quick troubleshooting map

| Symptom | Cause | Fix |
|---|---|---|
| `No local sandbox named ... found` | used `connect(local=True)` | use `create(Image.macos(), name=..., local=True)` |
| `'coroutine' ... async context manager` | `async with Sandbox.create(...)` | `await Sandbox.create(...)` |
| `computer-server not ready after 120s` | server not on :8443 in VM | provision (step 3) |
| `could not create image from display` | Screen Recording not granted / stale | grant in GUI + kickstart agent (step 4) |
| `lume ssh` errors `result=8`/`End of file` | host lume cache bug | direct `ssh` (step 5) |
