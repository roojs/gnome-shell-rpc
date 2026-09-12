#!/usr/bin/env bash
# Weston in an X11 window for **looking** at the nested shell.
# Nest stays up until you close the Weston window.
#
#   ./scripts/weston-gsr-session.sh
#
# Short auto-kill prove (agent / CI): ./scripts/weston-gsr-prove.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="${GSR_WESTON_SOCKET:-wayland-gsr}"
RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
WIDTH="${GSR_WESTON_WIDTH:-1280}"
HEIGHT="${GSR_WESTON_HEIGHT:-800}"
INI_DIR="${XDG_RUNTIME_DIR:-/tmp}/gsr-weston-$$"
INI="$INI_DIR/weston-gsr.ini"
AUTO="$ROOT/scripts/weston-gsr-autolaunch.sh"
# session = hold until window closed; prove = short timeout (set by weston-gsr-prove.sh)
MODE="${GSR_WESTON_MODE:-session}"

chmod 700 "$RT" 2>/dev/null || true
export XDG_RUNTIME_DIR="$RT"
export GSR_WESTON_MODE="$MODE"

# Leftover nest from a previous run — clear and continue.
if [[ -e "$RT/$SOCK" || -e "$RT/${SOCK}.lock" ]]; then
	echo "weston-gsr-session: clearing previous $SOCK nest" >&2
	pkill -f "weston.*${SOCK}" 2>/dev/null || true
	pkill -x mutter-rpc 2>/dev/null || true
	pkill -x gnome-shell-rpc 2>/dev/null || true
	sleep 0.2
	rm -f "$RT/$SOCK" "$RT/${SOCK}.lock"
fi

if ! command -v weston >/dev/null; then
	echo "weston-gsr-session: install weston: sudo apt install weston" >&2
	exit 2
fi
if [[ ! -x "$AUTO" ]]; then
	echo "weston-gsr-session: missing $AUTO" >&2
	exit 2
fi

mkdir -p "$INI_DIR"
sed "s|@AUTOLAUNCH@|$AUTO|g" "$ROOT/scripts/weston-gsr.ini.in" >"$INI"

echo "weston-gsr-session: mode=$MODE socket=$SOCK ${WIDTH}x${HEIGHT}"
if [[ "$MODE" == "prove" ]]; then
	echo "weston-gsr-session: autolaunch → nested prove (short timeout)"
else
	echo "weston-gsr-session: autolaunch → nested shell (close Weston window to stop)"
fi

exec weston \
	--backend=x11-backend.so \
	--width="$WIDTH" \
	--height="$HEIGHT" \
	--socket="$SOCK" \
	--config="$INI"
