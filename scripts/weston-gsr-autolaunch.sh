#!/usr/bin/env bash
# Runs *inside* Weston ([autolaunch]). Starts nested mutter-rpc on Weston's
# XWayland DISPLAY (Mutter nested is MetaBackendX11Nested).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${GSR_WESTON_LOG_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc}"
mkdir -p "$LOG_DIR"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

# Wait until Weston has given us an XWayland DISPLAY (not host :0 alone with no X).
# Weston sets DISPLAY for autolaunch clients when xwayland=true.
for _ in $(seq 1 50); do
	if [[ -n "${DISPLAY:-}" ]] && [[ -S "/tmp/.X11-unix/X${DISPLAY#:}" || -e "/tmp/.X11-unix/X${DISPLAY#:}" ]]; then
		break
	fi
	sleep 0.1
done

{
	echo "weston-gsr-autolaunch: DISPLAY=${DISPLAY:-unset} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset}"
	exec "$ROOT/scripts/nested-weston-prove.sh"
} >>"$LOG_DIR/weston-autolaunch-prove.log" 2>&1
