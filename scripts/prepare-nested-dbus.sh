#!/usr/bin/env bash
# Build a private session-bus config for the nested shell.
#
# GNOME Terminal's distro service delegates to the host user systemd manager.
# That manager is attached to the host session bus/display, so it cannot own
# org.gnome.Terminal on dbus-run-session's private bus. Prefer a direct Exec
# service for this nested session.
set -euo pipefail

OUT_DIR="${1:?usage: prepare-nested-dbus.sh OUT_DIR}"
SYSTEM_CONFIG="/usr/share/dbus-1/session.conf"
SERVICE_DIR="$OUT_DIR/services"
CONFIG="$OUT_DIR/session.conf"

mkdir -p "$SERVICE_DIR"
cat >"$SERVICE_DIR/org.gnome.Terminal.service" <<'EOF'
[D-BUS Service]
Name=org.gnome.Terminal
Exec=/usr/libexec/gnome-terminal-server
EOF

python3 - "$SYSTEM_CONFIG" "$CONFIG" "$SERVICE_DIR" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
marker = "  <standard_session_servicedirs />"
if marker not in source:
    raise SystemExit(f"{sys.argv[1]} has no standard_session_servicedirs marker")
service_dir = sys.argv[3].replace("&", "&amp;").replace("<", "&lt;")
source = source.replace(
    marker,
    f"  <servicedir>{service_dir}</servicedir>\n{marker}",
    1,
)
Path(sys.argv[2]).write_text(source)
PY

printf '%s\n' "$CONFIG"
