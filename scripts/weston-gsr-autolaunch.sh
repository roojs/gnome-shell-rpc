#!/usr/bin/env bash
# Runs *inside* Weston ([autolaunch]). Starts nested mutter-rpc on Weston's
# XWayland DISPLAY (Mutter nested is MetaBackendX11Nested).
#
# GSR_WESTON_MODE=session (default) — start mutter via hold; if mutter dies,
#   autolaunch stays alive so Weston + XWayland stay up for manual debugging.
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
	"$ROOT/scripts/nested-weston-hold.sh" &
	echo "weston-gsr-autolaunch: session hold pid=$! (mutter exit does not stop Weston)"
	exec sleep infinity
} >>"$LOG_DIR/weston-autolaunch-prove.log" 2>&1
