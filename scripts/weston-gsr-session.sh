#!/usr/bin/env bash
# Weston in an X11 window; [autolaunch] runs nested-weston-prove inside the nest.
#
#   ./scripts/weston-gsr-session.sh
#
# Stop: close the Weston window, or: pkill -f 'weston.*wayland-gsr'
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="${GSR_WESTON_SOCKET:-wayland-gsr}"
RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
WIDTH="${GSR_WESTON_WIDTH:-1280}"
HEIGHT="${GSR_WESTON_HEIGHT:-800}"
INI_DIR="${XDG_RUNTIME_DIR:-/tmp}/gsr-weston-$$"
INI="$INI_DIR/weston-gsr.ini"
AUTO="$ROOT/scripts/weston-gsr-autolaunch.sh"

chmod 700 "$RT" 2>/dev/null || true
export XDG_RUNTIME_DIR="$RT"

if [[ -e "$RT/$SOCK" ]]; then
	echo "weston-gsr-session: $RT/$SOCK already present — not starting a second Weston" >&2
	echo "  (close it, or: pkill -f 'weston.*$SOCK')" >&2
	exit 0
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
# Embed absolute autolaunch path (weston.ini does not expand ~).
sed "s|@AUTOLAUNCH@|$AUTO|g" "$ROOT/scripts/weston-gsr.ini.in" >"$INI"

echo "weston-gsr-session: socket=$SOCK ${WIDTH}x${HEIGHT} ini=$INI"
echo "weston-gsr-session: autolaunch → nested-weston-prove (mutter-rpc --nested)"

exec weston \
	--backend=x11-backend.so \
	--width="$WIDTH" \
	--height="$HEIGHT" \
	--socket="$SOCK" \
	--config="$INI"
