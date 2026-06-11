#!/usr/bin/env bash
# Provision trycua computer-server inside a macOS guest running under UTM.
# Run THIS SCRIPT INSIDE THE VM as the desktop user
# (e.g. ssh user@guest 'bash -s' < provision-computer-server.sh).
# Requires no Xcode Command Line Tools: uv ships its own Python.
#
# After this runs, you still must grant Screen Recording permission to the
# python3.12 interpreter in the VM GUI, then re-run the kickstart line below.
# See the parent SKILL.md, section 2.
set -euo pipefail

PORT="${CUA_SERVER_PORT:-8000}"
VENV="$HOME/cua-server-env"
PLIST="$HOME/Library/LaunchAgents/com.trycua.computer_server.plist"
LOG="$HOME/computer-server.log"
UID_NUM="$(id -u)"

CONSOLE_USER="$(stat -f %Su /dev/console || true)"
if [ "$CONSOLE_USER" != "$(id -un)" ]; then
  echo "WARNING: console user is '$CONSOLE_USER', not $(id -un)." >&2
  echo "The LaunchAgent needs an active GUI login for this user; log in" >&2
  echo "at the VM window or enable automatic login, then re-run." >&2
fi

echo "==> Installing uv (if missing)"
if [ ! -x "$HOME/.local/bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"
uv --version

echo "==> Creating venv + installing cua-computer-server"
# --allow-existing keeps the script idempotent: uv 0.11+ errors on an existing venv
uv venv --python 3.12 --allow-existing "$VENV"
uv pip install --python "$VENV/bin/python" cua-computer-server

# Verify by output, not exit code: over SSH (no GUI context) the interpreter
# prints "import OK" but then segfaults during pyobjc teardown, which would
# abort the whole script under set -e.
IMPORT_OUT="$("$VENV/bin/python" -c "import computer_server, fastapi, uvicorn; print('import OK')" 2>/dev/null || true)"
case "$IMPORT_OUT" in
  *"import OK"*) echo "import OK" ;;
  *) echo "ERROR: cua-computer-server failed to import" >&2; exit 1 ;;
esac

echo "==> Disabling sleep (a sleeping UTM macOS guest drops its network and may never wake)"
defaults -currentHost write com.apple.screensaver idleTime 0
sudo -n pmset -a sleep 0 displaysleep 0 disksleep 0 2>/dev/null \
  || echo "NOTE: could not run pmset non-interactively; run inside the guest:" \
          "sudo pmset -a sleep 0 displaysleep 0 disksleep 0"

echo "==> Writing LaunchAgent ($PLIST)"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.trycua.computer_server</string>
  <key>ProgramArguments</key>
  <array>
    <string>$VENV/bin/python</string>
    <string>-m</string><string>computer_server</string>
    <string>--port</string><string>$PORT</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST

echo "==> Loading agent into GUI session (gui/$UID_NUM)"
pkill -f computer_server 2>/dev/null || true
launchctl bootout "gui/$UID_NUM/com.trycua.computer_server" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
launchctl kickstart -k "gui/$UID_NUM/com.trycua.computer_server"

echo "==> Status:"
STATUS=""
for _ in $(seq 1 10); do
  STATUS="$(curl -s -m5 "localhost:$PORT/status" || true)"
  [ -n "$STATUS" ] && break
  sleep 3
done
echo "${STATUS:-server did not respond on :$PORT within 30s}"
echo "Done. If screenshots fail with 'could not create image from display':"
echo "  1. In the VM GUI: System Settings > Privacy & Security >"
echo "     Screen & System Audio Recording > enable python3.12"
echo "  2. launchctl kickstart -k gui/$UID_NUM/com.trycua.computer_server"
