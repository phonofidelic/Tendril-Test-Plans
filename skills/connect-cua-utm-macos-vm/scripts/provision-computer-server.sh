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
uv venv --python 3.12 "$VENV"
uv pip install --python "$VENV/bin/python" cua-computer-server
"$VENV/bin/python" -c "import computer_server, fastapi, uvicorn; print('import OK')"

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

sleep 6
echo "==> Status:"
curl -s -m5 "localhost:$PORT/status" || true
echo
echo "Done. If screenshots fail with 'could not create image from display':"
echo "  1. In the VM GUI: System Settings > Privacy & Security >"
echo "     Screen & System Audio Recording > enable python3.12"
echo "  2. launchctl kickstart -k gui/$UID_NUM/com.trycua.computer_server"
