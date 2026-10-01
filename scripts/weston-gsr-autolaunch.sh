#!/usr/bin/env bash
# Runs *inside* Weston ([autolaunch]). Starts nested mutter-rpc on Weston's
# XWayland DISPLAY (Mutter nested is MetaBackendX11Nested).
#
# GSR_WESTON_MODE=session (default)
#   GSR_DEBUG=1 — open weston-terminal inside this Weston. That terminal
#     starts mutter via hold and follows the debug logs.
#   GSR_DEBUG=0 — do not start the shell. The panel button does that.
#     Autolaunch stays alive so Weston stays up.
# GSR_WESTON_MODE=prove — nested-weston-prove.sh (short timeout). Weston stays
#   up after prove unless GSR_WESTON_AUTO_CLOSE=1 (agents: weston-gsr-prove.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${GSR_WESTON_LOG_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc}"
mkdir -p "$LOG_DIR"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
MODE="${GSR_WESTON_MODE:-session}"
SOCK="${GSR_WESTON_SOCKET:-wayland-gsr}"

# Weston may clear exports; session.sh writes this for prove/hold/smoke.
GSR_ENV_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gsr-weston-autolaunch.env"
if [[ -f "$GSR_ENV_FILE" ]]; then
	# shellcheck disable=SC1090
	set -a
	# shellcheck disable=SC1091
	source "$GSR_ENV_FILE"
	set +a
	MODE="${GSR_WESTON_MODE:-$MODE}"
fi

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
		if [[ "${GSR_WESTON_AUTO_CLOSE:-0}" == "1" ]]; then
			echo "weston-gsr-autolaunch: prove ec=$ec — GSR_WESTON_AUTO_CLOSE=1, stopping Weston"
			pkill -f "weston.*--socket=${SOCK}" 2>/dev/null || true
			pkill -f "weston.*${SOCK}" 2>/dev/null || true
			exit "$ec"
		fi
		echo "weston-gsr-autolaunch: prove ec=$ec — keeping Weston up (close window or GSR_WESTON_AUTO_CLOSE=1)"
		exec sleep infinity
	fi
	if [[ -z "${DISPLAY:-}" ]]; then
		echo "weston-gsr-autolaunch: XWayland DISPLAY never appeared — not starting mutter-rpc"
		exec sleep infinity
	fi
	printf '%s\n' "$DISPLAY" >"$XDG_RUNTIME_DIR/gsr-weston-xdisplay"
	if [[ "${GSR_DEBUG:-0}" != "1" ]]; then
		echo "weston-gsr-autolaunch: debug off — waiting for the panel button"
		exec sleep infinity
	fi
	# weston-terminal is a client of this Weston (WAYLAND_DISPLAY=wayland-gsr).
	# gnome-terminal is not: its server lives on the host bus and opens outside.
	if command -v weston-terminal >/dev/null; then
		weston-terminal --font-size=14 --shell="$ROOT/scripts/weston-gsr-log-term.sh" &
		echo "weston-gsr-autolaunch: weston-terminal pid=$! xdisplay=$DISPLAY"
	elif command -v xterm >/dev/null; then
		xterm -T "gsr mutter-rpc" -geometry 110x32 -e bash "$ROOT/scripts/weston-gsr-log-term.sh" &
		echo "weston-gsr-autolaunch: xterm pid=$! xdisplay=$DISPLAY (inside Weston XWayland)"
	else
		echo "weston-gsr-autolaunch: install weston-terminal or xterm — mutter-rpc not started"
	fi
	exec sleep infinity
} >>"$LOG_DIR/weston-autolaunch-prove.log" 2>&1
