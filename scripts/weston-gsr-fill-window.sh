#!/usr/bin/env bash
# Make the nested compositor window cover Weston's XWayland output.
# Mutter nested maps at 1024x768. That is exactly 80% of the default
# 1280-wide Weston, so a "still small" check never resized it.
#
# Usage: weston-gsr-fill-window.sh DISPLAY
set -euo pipefail

DISP="${1:-${DISPLAY:-}}"
if [[ -z "$DISP" ]]; then
	echo "weston-gsr-fill-window: DISPLAY unset" >&2
	exit 0
fi
if ! command -v wmctrl >/dev/null || ! command -v xwininfo >/dev/null; then
	echo "weston-gsr-fill-window: need wmctrl and xwininfo" >&2
	exit 0
fi

find_id() {
	DISPLAY="$DISP" wmctrl -lx 2>/dev/null | awk '
		tolower($0) ~ /gsr-server|mutter/ { print $1; exit }
	'
}

id=""
for _ in $(seq 1 80); do
	id="$(find_id)"
	if [[ -n "$id" ]]; then
		break
	fi
	sleep 0.25
done
if [[ -z "$id" ]]; then
	echo "weston-gsr-fill-window: nested window did not appear" >&2
	DISPLAY="$DISP" wmctrl -lx >&2 || true
	exit 0
fi

root_w="$(DISPLAY="$DISP" xwininfo -root 2>/dev/null | awk '/Width:/ {print $2; exit}')"
root_h="$(DISPLAY="$DISP" xwininfo -root 2>/dev/null | awk '/Height:/ {print $2; exit}')"
if [[ -z "${root_w:-}" || -z "${root_h:-}" ]]; then
	echo "weston-gsr-fill-window: no root size" >&2
	exit 0
fi

# Cover the Weston output, panel included. The panel button is for
# starting the demo; after that the shell is the picture.
for _ in 1 2 3 4 5 6 7 8; do
	id="$(find_id)"
	[[ -n "$id" ]] || break
	DISPLAY="$DISP" wmctrl -i -a "$id" || true
	DISPLAY="$DISP" wmctrl -i -r "$id" -b add,fullscreen || true
	DISPLAY="$DISP" wmctrl -i -r "$id" -e "0,0,0,${root_w},${root_h}" || true
	if command -v xdotool >/dev/null; then
		DISPLAY="$DISP" xdotool windowmove "$id" 0 0 || true
		DISPLAY="$DISP" xdotool windowsize "$id" "$root_w" "$root_h" || true
	fi
	sleep 0.5
done
exit 0
