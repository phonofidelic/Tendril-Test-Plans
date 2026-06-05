---
name: install-tendril-in-mac-vm
description: >-
  Agent-agnostic runbook to install Tendril on the tendril-mac Lume VM as a
  human would (GUI .pkg first, Terminal script fallback). Use when the VM is
  stopped or has no Tendril, before running test-plan skills, or when setting
  up a fresh VM for CUA-driven testing. Works with any Cursor agent.
---

# Install Tendril on the Lume VM (agent-agnostic)

The **invoking agent** is the computer-use brain. [`cua-agent-app`](../../../cua-agent-app/) provides eyes and hands via CLI primitives. No nested LLM, no provider API keys, no Ivy-Tendril source reading.

## Agent contract

Whichever agent runs this skill must:

1. Control the VM only through `cua-agent-app` CLI commands (from `cua-agent-app/`).
2. **Screenshot after every action** and verify the UI changed before continuing.
3. Use only the public URLs and steps below — do not install Tendril via SSH, curl from the host, or Ivy-Tendril source/NuGet paths.
4. If unsure where to click, screenshot first and reason from what you see — never hardcode coordinates in advance.
5. VM user password for Installer prompts: `LUME_VM_SSH_PASSWORD` from `.env`.

**Core loop:**

```bash
cd cua-agent-app
uv run main.py screenshot --out screenshots/NN-step.png
# interpret image → pick coords → act with a single cua SDK call
uv run main.py click --x X --y Y
```

The CLI is a thin pass-through to the cua Sandbox SDK ([docs](https://cua.ai/docs/cua/guide/get-started/what-is-cua)): `screenshot` → `sb.screenshot()`, `click`/`double-click`/`right-click`/`move`/`drag`/`scroll` → `sb.mouse.*`, `type`/`keypress` → `sb.keyboard.*`, `dimensions` → `sb.get_dimensions()`. No custom coordinate math lives in the app — clicks use the SDK's coordinate space directly.

**Coordinates (verified):** Mouse coordinates are in the VM's **logical display space**, which matches the `display` column in `lume ls` (here **1024×768**) — *not* the pixel size `uv run main.py dimensions` reports (`2048×1536`) nor the saved PNG size (`1920×1440`). The reliable method: measure your target as a **fraction** of the screenshot, then multiply by the logical size: `x = frac_x × 1024`, `y = frac_y × 768`. Passing 2048×1536-scale coordinates lands at ~2× and clicks off-target (often onto the wallpaper). Calibration tip: right-click anywhere and the context menu's top-left appears exactly at the coordinate you passed — use that to confirm the space. Host Lume window letterboxing does not affect API clicks.

**Two macOS gotchas that waste actions:**
- **"Click wallpaper to reveal desktop"** is on by default (Sonoma+). Any click that lands on the wallpaper (e.g. wrong coordinates, or margins outside a window) flings all windows to the screen edges. If this happens, re-activate the target app from the Dock and recheck your coordinate scaling.
- **Scroll wheel is unreliable** here (`sb.mouse.scroll` can register as a middle-click → reveal desktop). To scroll, prefer **dragging the scrollbar thumb** (`drag`) or keyboard (`space` / arrows) with the web/content pane focused — avoid clicking the wallpaper to focus it.

**Key names:** use `esc` (not `escape`) for `keypress`.

---

## 0. Prerequisites (host)

- macOS host with [Lume](https://github.com/trycua/cua) and [`uv`](https://docs.astral.sh/uv/)
- [`.env`](../../../.env) populated from [`.env.example`](../../../.env.example) (`LUME_VM_*` only)
- Dependencies installed:

```bash
cd cua-agent-app && uv sync
```

---

## 1. Cold-start the VM

```bash
set -a && source .env && set +a
lume ls
lume run "${LUME_VM_NAME:-tendril-mac}"
```

Poll until `lume ls` shows the VM **running**. If the NAT IP changed, update `LUME_VM_IP` in `.env` from the `lume ls` output.

**Login screen (cold boot):** CUA primitives cannot run until `computer-server` is up, and that requires an active GUI session. If the Lume virtualization window shows the macOS login screen:

1. Log in **manually** in that window as the VM user (display name may differ from `LUME_VM_SSH_USER`; password is `LUME_VM_SSH_PASSWORD` in local `.env` only — never commit it).
2. After login, continue to section 2 to provision/verify `computer-server`, then use the screenshot → click/type loop for everything else.

Confirm an active GUI session (console user is not `loginwindow`):

```bash
# optional SSH diagnostic from host — infra only, not for Tendril install
# use expect if password auth is required; see connect-cua-lume-macos-vm step 5
ssh "${LUME_VM_SSH_USER}@${LUME_VM_IP}" 'stat -f %Su /dev/console'
```

---

## 2. Ensure CUA connectivity

Follow [connect-cua-lume-macos-vm](../connect-cua-lume-macos-vm/SKILL.md):

- `curl -s -m5 "http://${LUME_VM_IP}:8443/status"` → `{"status":"ok",...}`
- If missing: provision `computer-server` (SSH OK for **infra only**)
- If screenshots fail with `could not create image from display`: grant Screen Recording to `python3.12` in the VM GUI, then kickstart the LaunchAgent

Sanity check:

```bash
cd cua-agent-app
uv run main.py screenshot --out screenshots/00-ready.png
```

---

## 3. Phase A — GUI install (primary)

Execute via screenshot/click/type loop. Save checkpoint screenshots with numbered prefixes.

### 3.1 Open Safari

- Click the Safari icon in the Dock, **or**
- `uv run main.py keypress --keys cmd,space` → `uv run main.py type --text "Safari"` → `uv run main.py keypress --keys enter`

### 3.2 Navigate to releases

Click the address bar, then type the releases URL:

- Default: `https://github.com/Ivy-Interactive/Ivy-Tendril/releases/latest`
- If `TENDRIL_VERSION` is set in `.env`: `https://github.com/Ivy-Interactive/Ivy-Tendril/releases/tag/v${TENDRIL_VERSION}`

Press Enter. Screenshot and confirm the releases page loaded.

### 3.3 Download the macOS installer

Locate and click the **`IvyTendril-<version>-osx-arm64.pkg`** asset link (e.g. `IvyTendril-1.0.51-osx-arm64.pkg`). The release lists one `.pkg` per platform plus `-full.nupkg` deltas — pick the **`osx-arm64.pkg`** (Apple Silicon installer), not `osx-x64.pkg`, not any `.nupkg`. Screenshot until the download completes (Downloads indicator or Downloads folder).

> Asset names are version-stamped (`IvyTendril-<version>-osx-arm64.pkg`); there is no static `IvyTendril-osx-Setup.pkg`. To resolve the exact name for a release, read the Assets list on the releases page.

### 3.4 Run the installer

Open Downloads and launch **`IvyTendril-<version>-osx-arm64.pkg`** (the `.pkg`, not the `IvyTendril-<version>-osx-arm64-full.nupkg` delta).

Reliable launch sequence (avoids precise double-click timing): single-**click** the `.pkg` row to select it, then **`Cmd+O`** to open. **Do not press `Enter`** — in Finder it renames the file. If the file list won't respond, open Downloads with **`Cmd+Option+L`** (Finder → Go → Downloads) first.

**Gatekeeper on current macOS (Sequoia/15+):** quarantined `.pkg` files are blocked on first open and **right-click → Open no longer bypasses it**. You will see ""…pkg" Not Opened" with only **Move to Trash** / **Done** — dismiss with **Done**, then:

1. Open **System Settings → Privacy & Security** (Spotlight: `cmd,space` → type "Privacy & Security" → Enter).
2. Scroll to the **Security** section (drag the scrollbar thumb — the wheel is unreliable). It shows ""…pkg" was blocked to protect your Mac" with an **Open Anyway** button.
3. Click **Open Anyway** → in the confirm sheet click **Open Anyway** again → enter the VM password (`LUME_VM_SSH_PASSWORD`).

The macOS Installer then launches.

Walk the macOS Installer wizard (screenshot through each step):

1. **Continue** (Introduction)
2. **Continue** (Destination Select — "Install for all users" is the default; there may be no license/Agree step)
3. **Install** (Installation Type → Standard Install)
4. Enter the VM password if prompted (`LUME_VM_SSH_PASSWORD`)
5. Click **Allow** if "Installer would like to modify apps on your Mac" appears
6. Wait for "The installation was successful", then **Close** (and **Keep** if asked about trashing the installer)

### 3.5 Launch Tendril

Open **Ivy Tendril** from Applications, or Spotlight:

```bash
uv run main.py keypress --keys cmd,space
uv run main.py type --text "Ivy Tendril"
uv run main.py keypress --keys enter
```

### 3.6 Phase A checkpoint

```bash
uv run main.py screenshot --out screenshots/50-tendril-open.png
```

**Pass:** native Tendril macOS app window is visible (not just a background process). If Phase A fails at any step, proceed to Phase B.

---

## 4. Phase B — Terminal fallback (only if Phase A fails)

Switch here only after Phase A fails (download blocked, installer error, etc.).

### 4.1 Open Terminal

Spotlight (`cmd,space` → "Terminal" → Enter) or Dock.

### 4.2 Run the official install script

Type exactly (as a user would paste from ivy.app):

```bash
uv run main.py type --text "curl -sSf https://cdn.ivy.app/install-tendril.sh | sh"
uv run main.py keypress --keys enter
```

Screenshot periodically until the script prints **Installation Complete** (may take several minutes).

### 4.3 Launch Tendril

As a user would after that install path:

- Applications → Ivy Tendril if an app icon exists, **or**
- In Terminal: `uv run main.py type --text "tendril"` → `uv run main.py keypress --keys enter`

### 4.4 Phase B checkpoint

```bash
uv run main.py screenshot --out screenshots/90-tendril-open.png
```

---

## 5. Done criteria

- Native Tendril macOS app window visible in the final checkpoint screenshot
- Record whether Phase A or Phase B succeeded
- VM remains running (`disconnect` only — never stop the VM unless asked)

---

## 6. Must NOT do

- SSH or host-side curl to install Tendril on the VM
- Read Ivy-Tendril source, `install.sh` internals, or NuGet paths
- Run `dotnet tool install` directly from the host or over SSH
- Delegate to a nested LLM / `ComputerAgent` inside `cua-agent-app`

---

## 7. CLI reference

All commands run from `cua-agent-app/`:

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

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| VM won't start | `lume ls`; check Lume daemon; disk/RAM |
| Stuck at login screen | Screenshot + click/type to log in |
| `computer-server not ready after 120s` | [connect-cua-lume-macos-vm](../connect-cua-lume-macos-vm/SKILL.md) step 3 |
| `could not create image from display` | Screen Recording grant + `launchctl kickstart` |
| Wrong click coordinates / clicks land ~2× off | Coordinates are in the **logical display** size (`lume ls` display column, e.g. 1024×768), not `dimensions` (2048×1536) or PNG size. Measure target as a fraction and multiply by the logical size; re-screenshot before re-measuring |
| All windows fly to screen edges | A click hit the wallpaper ("Click wallpaper to reveal desktop"). Re-activate the app from the Dock and fix coordinate scaling |
| Page/list won't scroll | Wheel can misfire as a middle-click; drag the scrollbar thumb or use keyboard with the pane focused |
| `.pkg` "Not Opened" / blocked | macOS Sequoia: dismiss with **Done**, then System Settings → Privacy & Security → Security → **Open Anyway** (right-click → Open no longer bypasses) |
| Phase A fails | Proceed to Phase B |
| Installer password prompt | `LUME_VM_SSH_PASSWORD` from `.env` |
