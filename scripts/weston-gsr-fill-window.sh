#!/usr/bin/env bash
# Stretch the nested mutter X window across Weston's XWayland work area.
# Called only when the session is not in --debug. The log terminal is absent,
# so the nested window should fill Weston and leave the panel as the border.
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

id=""
for _ in $(seq 1 80); do
	id="$(DISPLAY="$DISP" wmctrl -l 2>/dev/null | awk '/[Mm]utter/ {print $1; exit}')"
	if [[ -n "$id" ]]; then
		break
	fi
	sleep 0.25
done
if [[ -z "$id" ]]; then
	echo "weston-gsr-fill-window: mutter window did not appear" >&2
	exit 0
fi

# Weston desktop-shell honors maximize as "output minus the top panel".
DISPLAY="$DISP" wmctrl -i -r "$id" -b add,maximized_vert,maximized_horz || true
sleep 0.4

win_w="$(DISPLAY="$DISP" xwininfo -id "$id" 2>/dev/null | awk '/Width:/ {print $2; exit}')"
root_w="$(DISPLAY="$DISP" xwininfo -root 2>/dev/null | awk '/Width:/ {print $2; exit}')"
root_h="$(DISPLAY="$DISP" xwininfo -root 2>/dev/null | awk '/Height:/ {print $2; exit}')"
# Weston desktop-shell panel. Used only if maximize left the small frame.
panel="${GSR_WESTON_PANEL:-32}"

if [[ -n "${win_w:-}" && -n "${root_w:-}" && -n "${root_h:-}" ]] \
		&& [[ "$win_w" -lt $((root_w * 8 / 10)) ]]; then
	DISPLAY="$DISP" wmctrl -i -r "$id" -b remove,maximized_vert,maximized_horz || true
	h=$((root_h - panel))
	if [[ "$h" -lt 1 ]]; then
		h=$root_h
		panel=0
	fi
	DISPLAY="$DISP" wmctrl -i -r "$id" -e "0,0,${panel},${root_w},${h}" || true
fi
exit 0
