#!/usr/bin/env bash
# Runs *inside* Weston ([autolaunch]). Starts nested mutter-rpc on Weston's
# XWayland DISPLAY (Mutter nested is MetaBackendX11Nested).
#
# GSR_WESTON_MODE=session (default) — hold until mutter/Weston exits
# GSR_WESTON_MODE=prove — nested-weston-prove.sh (short timeout), then kill
#   Weston so weston-gsr-prove.sh returns (do not leave the X window up).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${GSR_WESTON_LOG_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc}"
mkdir -p "$LOG_DIR"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
MODE="${GSR_WESTON_MODE:-session}"
SOCK="${GSR_WESTON_SOCKET:-wayland-gsr}"

# Wait until Weston has given us an XWayland DISPLAY (not host :0 alone with no X).
for _ in $(seq 1 50); do
	if [[ -n "${DISPLAY:-}" ]] && [[ -S "/tmp/.X11-unix/X${DISPLAY#:}" || -e "/tmp/.X11-unix/X${DISPLAY#:}" ]]; then
		break
	fi
	sleep 0.1
done

{
	echo "weston-gsr-autolaunch: mode=$MODE DISPLAY=${DISPLAY:-unset} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset}"
	if [[ "$MODE" == "prove" ]]; then
		set +e
		"$ROOT/scripts/nested-weston-prove.sh"
		ec=$?
		set -e
		echo "weston-gsr-autolaunch: prove exited ec=$ec — stopping Weston"
		# Parent of this autolaunch is weston; tear it down so prove returns.
		pkill -f "weston.*--socket=${SOCK}" 2>/dev/null || true
		pkill -f "weston.*${SOCK}" 2>/dev/null || true
		exit "$ec"
	fi
	exec "$ROOT/scripts/nested-weston-hold.sh"
} >>"$LOG_DIR/weston-autolaunch-prove.log" 2>&1
