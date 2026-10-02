#!/usr/bin/env bash
# Pin the Weston X11 window on the host display.
# The host window manager otherwise picks a new origin every launch,
# which moves the picture around in a screen recording.
#
# Usage: weston-gsr-place-host-window.sh HOST_DISPLAY WESTON_PID X Y WIDTH HEIGHT
set -euo pipefail

HOST_DISPLAY="${1:-}"
WESTON_PID="${2:-}"
POS_X="${3:-0}"
POS_Y="${4:-0}"
WIDTH="${5:-1280}"
HEIGHT="${6:-800}"

if [[ -z "$HOST_DISPLAY" || -z "$WESTON_PID" ]]; then
	echo "weston-gsr-place-host-window: need host DISPLAY and weston pid" >&2
	exit 0
fi
if ! command -v wmctrl >/dev/null; then
	echo "weston-gsr-place-host-window: need wmctrl" >&2
	exit 0
fi

find_id() {
	# Weston does not set _NET_WM_PID, so match the host window title.
	DISPLAY="$HOST_DISPLAY" wmctrl -lx 2>/dev/null | awk '
		tolower($0) ~ /weston compositor/ { print $1; exit }
	'
}

id=""
for _ in $(seq 1 40); do
	if ! kill -0 "$WESTON_PID" 2>/dev/null; then
		exit 0
	fi
	id="$(find_id)"
	if [[ -n "$id" ]]; then
		break
	fi
	sleep 0.1
done
if [[ -z "$id" ]]; then
	echo "weston-gsr-place-host-window: weston window did not appear" >&2
	exit 0
fi

for _ in 1 2 3 4 5 6; do
	if ! kill -0 "$WESTON_PID" 2>/dev/null; then
		exit 0
	fi
	id="$(find_id)"
	[[ -n "$id" ]] || break
	DISPLAY="$HOST_DISPLAY" wmctrl -i -r "$id" -e "0,${POS_X},${POS_Y},${WIDTH},${HEIGHT}" || true
	if command -v xdotool >/dev/null; then
		DISPLAY="$HOST_DISPLAY" xdotool windowmove "$id" "$POS_X" "$POS_Y" || true
		DISPLAY="$HOST_DISPLAY" xdotool windowsize "$id" "$WIDTH" "$HEIGHT" || true
	fi
	sleep 0.3
done
exit 0
