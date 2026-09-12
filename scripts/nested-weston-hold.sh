#!/usr/bin/env bash
# Run mutter-rpc --wayland --nested inside Weston and **hold** until it exits
# (close the Weston window). Used by weston-gsr-session.sh (interactive).
#
# Short auto-stop prove: ./scripts/weston-gsr-prove.sh → nested-weston-prove.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MUTTER_RPC="${GSR_MUTTER_RPC:-$ROOT/build/src/mutter-rpc}"
RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
MUTTER_WL="${GSR_MUTTER_WAYLAND_DISPLAY:-wayland-mutter-gsr}"
WESTON_WL="${GSR_WESTON_SOCKET:-wayland-gsr}"
TEE_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc/nested-weston-prove.tee.log"

if [[ ! -x "$MUTTER_RPC" ]]; then
	echo "nested-weston-hold: missing $MUTTER_RPC" >&2
	exit 2
fi
if [[ ! -e "$RT/$WESTON_WL" ]]; then
	echo "nested-weston-hold: missing $RT/$WESTON_WL — start Weston first" >&2
	exit 2
fi
if [[ -z "${DISPLAY:-}" ]]; then
	echo "nested-weston-hold: DISPLAY unset — need Weston's XWayland" >&2
	exit 2
fi

echo "nested-weston-hold: DISPLAY=$DISPLAY weston=$WESTON_WL mutter_wl=$MUTTER_WL (close Weston to stop)"

: >"$TEE_LOG"
env_args=(
	DISPLAY="$DISPLAY"
	XAUTHORITY="${XAUTHORITY:-}"
	XDG_RUNTIME_DIR="$RT"
	WAYLAND_DISPLAY="$MUTTER_WL"
)
if [[ -n "${GI_RPC_JS_OVERRIDE_DIR:-}" ]]; then
	env_args+=(GI_RPC_JS_OVERRIDE_DIR="$GI_RPC_JS_OVERRIDE_DIR")
fi

dbus-run-session -- \
	env "${env_args[@]}" \
		"$MUTTER_RPC" --debug --wayland --nested --no-x11 \
		--wayland-display="$MUTTER_WL" \
	> >(tee "$TEE_LOG") 2>&1 &
MPID=$!

wait "$MPID"
ec=$?
echo "nested-weston-hold: mutter exited ec=$ec"
exit "$ec"
