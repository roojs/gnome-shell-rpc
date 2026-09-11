#!/usr/bin/env bash
# Run mutter-rpc --wayland --nested inside the Weston X nest.
#
# Mutter nested uses MetaBackendX11Nested: the nested *window* is an X11
# client. It must use Weston's XWayland DISPLAY, not the host (:0). Weston's
# Wayland socket (wayland-gsr) is only the parent compositor; mutter gets its
# own --wayland-display for shell clients.
#
# Env:
#   GSR_MUTTER_RPC=…/build/src/mutter-rpc
#   GSR_NESTED_TIMEOUT=55
#   GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-gsr
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MUTTER_RPC="${GSR_MUTTER_RPC:-$ROOT/build/src/mutter-rpc}"
TIMEOUT_SEC="${GSR_NESTED_TIMEOUT:-55}"
RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
# Mutter's own Wayland socket (must not collide with Weston's wayland-gsr).
MUTTER_WL="${GSR_MUTTER_WAYLAND_DISPLAY:-wayland-mutter-gsr}"
WESTON_WL="${GSR_WESTON_SOCKET:-wayland-gsr}"

if [[ ! -x "$MUTTER_RPC" ]]; then
	echo "nested-weston-prove: missing $MUTTER_RPC" >&2
	exit 2
fi
if [[ ! -e "$RT/$WESTON_WL" ]]; then
	echo "nested-weston-prove: missing $RT/$WESTON_WL — start Weston first:" >&2
	echo "  ./scripts/weston-gsr-session.sh" >&2
	exit 2
fi
if [[ -z "${DISPLAY:-}" ]]; then
	echo "nested-weston-prove: DISPLAY unset — need Weston's XWayland (enable xwayland in weston ini)" >&2
	exit 2
fi

# Refuse host X when we can detect it: if DISPLAY is :0 and the weston
# Wayland socket is the intended nest, require that this process was started
# with a DISPLAY that has an X socket (Weston XWayland usually is not :0).
# Autolaunch from Weston sets the right DISPLAY; manual runs must export it.
echo "nested-weston-prove: DISPLAY=$DISPLAY weston=$WESTON_WL mutter_wl=$MUTTER_WL timeout=${TIMEOUT_SEC}s"

exec timeout --foreground -k 5 "$TIMEOUT_SEC" \
	dbus-run-session -- \
	env \
		DISPLAY="$DISPLAY" \
		XAUTHORITY="${XAUTHORITY:-}" \
		XDG_RUNTIME_DIR="$RT" \
		WAYLAND_DISPLAY="$MUTTER_WL" \
		"$MUTTER_RPC" --debug --wayland --nested --no-x11 \
		--wayland-display="$MUTTER_WL"
