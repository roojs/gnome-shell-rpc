#!/usr/bin/env bash
# Log window inside Weston (weston-terminal, or xterm on Weston's XWayland).
# Starts mutter-rpc and follows the debug logs in this terminal.
#
# Spawned by weston-gsr-autolaunch.sh. Not used by weston-gsr-prove.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc"
CLIENT_LOG="$LOG_DIR/org.gnome.ShellRpc.debug.log"
SERVER_LOG="$LOG_DIR/mutter-rpc.debug.log"
XDISPLAY_FILE="$RT/gsr-weston-xdisplay"
ENV_FILE="$RT/gsr-weston-autolaunch.env"

if [[ -f "$ENV_FILE" ]]; then
	set -a
	# shellcheck disable=SC1090
	source "$ENV_FILE"
	set +a
fi

if [[ ! -s "$XDISPLAY_FILE" ]]; then
	echo "weston-gsr-log-term: missing $XDISPLAY_FILE — start ./scripts/weston-gsr-session.sh" >&2
	exit 2
fi

# This window is already on Weston. Mutter's nested window must use
# Weston's XWayland DISPLAY, not Weston's own Wayland socket.
export DISPLAY="$(<"$XDISPLAY_FILE")"
export XDG_RUNTIME_DIR="$RT"
unset WAYLAND_DISPLAY
unset WAYLAND_SOCKET

mkdir -p "$LOG_DIR"
: >"$CLIENT_LOG"
: >"$SERVER_LOG"

echo "weston-gsr-log-term: starting mutter-rpc  DISPLAY=$DISPLAY"
echo "  client  $CLIENT_LOG"
echo "  server  $SERVER_LOG"
echo "Close this window to stop mutter-rpc. Close the Weston window to stop the session."
echo

"$ROOT/scripts/nested-weston-hold.sh" &
HOLD=$!

cleanup() {
	if [[ -n "${TAIL:-}" ]] && kill -0 "$TAIL" 2>/dev/null; then
		kill "$TAIL" 2>/dev/null || true
		wait "$TAIL" 2>/dev/null || true
	fi
	if kill -0 "$HOLD" 2>/dev/null; then
		kill "$HOLD" 2>/dev/null || true
		wait "$HOLD" 2>/dev/null || true
	fi
	GSR_CLEAR_WESTON=0 "$ROOT/scripts/clear-nested-dbus.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# Hold truncates the client log before mutter writes. Brief pause, then
# show both files from the start of this run.
sleep 0.3
if ! kill -0 "$HOLD" 2>/dev/null; then
	set +e
	wait "$HOLD"
	ec=$?
	set -e
	echo "weston-gsr-log-term: mutter-rpc exited ec=$ec"
	exit "$ec"
fi

tail -q -n +1 -F "$CLIENT_LOG" "$SERVER_LOG" &
TAIL=$!

set +e
wait "$HOLD"
ec=$?
set -e
if [[ -n "${TAIL:-}" ]] && kill -0 "$TAIL" 2>/dev/null; then
	kill "$TAIL" 2>/dev/null || true
	wait "$TAIL" 2>/dev/null || true
fi
TAIL=
echo
echo "weston-gsr-log-term: mutter-rpc exited ec=$ec"
echo "Press Enter to close this window."
read -r _ || true
exit "$ec"
