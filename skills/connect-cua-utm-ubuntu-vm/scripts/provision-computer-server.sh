#!/usr/bin/env bash
# Provision trycua computer-server inside an Ubuntu guest (UTM or any VM).
# Run THIS SCRIPT INSIDE THE VM as the desktop user (not root):
#   bash provision-computer-server.sh
#
# Requires an Xorg desktop session (Ubuntu defaults to Wayland — the script
# prints the fix and exits if it detects Wayland) and Python 3.12+ (Ubuntu
# 24.04+). Registers an XDG autostart entry — NOT a systemd system service —
# so the server runs inside the graphical session; outside it there is no
# DISPLAY and it cannot capture the screen or send input. See the parent
# SKILL.md.

set -euo pipefail

PORT="${CUA_SERVER_PORT:-8000}"
VENV="$HOME/cua-server-env"
APP_NAME="cua-computer-server"
AUTOSTART="$HOME/.config/autostart/$APP_NAME.desktop"
LOG="$HOME/.cache/$APP_NAME.log"

if [ "$(id -u)" -eq 0 ]; then
    echo "Run as the desktop user, not root — sudo is used where needed." >&2
    exit 1
fi

echo "==> Checking session type"
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    cat >&2 <<'EOF'
This is a Wayland session: computer-server cannot capture the screen or
inject input. Switch GDM to Xorg, log back in, and re-run this script:

  sudo sed -i 's/^#\?WaylandEnable=.*/WaylandEnable=false/' /etc/gdm3/custom.conf
  sudo systemctl restart gdm3   # or reboot

EOF
    exit 1
fi
echo "    ${XDG_SESSION_TYPE:-unknown} (OK)"

echo "==> Installing system dependencies (sudo)"
sudo apt-get update -qq
sudo apt-get install -y python3 python3-venv python3-dev python3-tk \
    gnome-screenshot scrot xdotool curl

echo "==> Checking Python"
python3 - <<'EOF'
import sys
assert sys.version_info >= (3, 12), \
    f"Python 3.12+ required, found {sys.version.split()[0]} — use Ubuntu 24.04+ or deadsnakes"
print("    Python", sys.version.split()[0])
EOF

echo "==> Creating venv + installing cua-computer-server ($VENV)"
if [ ! -x "$VENV/bin/python" ]; then
    python3 -m venv "$VENV"
fi
"$VENV/bin/python" -m pip install --upgrade pip
"$VENV/bin/python" -m pip install --upgrade cua-computer-server
"$VENV/bin/python" -c "import computer_server; print('    import OK')"

echo "==> Allowing TCP $PORT through ufw (if active)"
if sudo ufw status | grep -q '^Status: active'; then
    sudo ufw allow "$PORT/tcp"
else
    echo "    ufw inactive — nothing to do"
fi

echo "==> Disabling screen blanking and lock screen"
gsettings set org.gnome.desktop.session idle-delay 0 || true
gsettings set org.gnome.desktop.screensaver lock-enabled false || true

echo "==> Registering autostart entry ($AUTOSTART)"
mkdir -p "$(dirname "$AUTOSTART")"
cat > "$AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=trycua computer-server for cua Sandbox connections
Exec=$VENV/bin/python -m computer_server --port $PORT
X-GNOME-Autostart-enabled=true
EOF

echo "==> Starting it now"
mkdir -p "$(dirname "$LOG")"
pkill -f "computer_server --port $PORT" 2>/dev/null || true
nohup "$VENV/bin/python" -m computer_server --port "$PORT" >"$LOG" 2>&1 &
sleep 6

echo "==> Status:"
if curl -fsS -m5 "http://localhost:$PORT/status"; then
    echo
else
    echo "computer-server not answering yet — check $LOG" >&2
fi

echo
echo "Done. From the macOS host, verify with:"
echo "  curl -s -m5 http://<guest-ip>:$PORT/status   # guest IP from: hostname -I"
