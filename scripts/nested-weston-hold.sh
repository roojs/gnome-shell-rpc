#!/usr/bin/env bash
# Run mutter-rpc --wayland --nested inside Weston and **hold** until it exits
# (close the Weston window). Used by weston-gsr-session.sh (interactive).
# GSR_DEBUG=1 passes --debug and tees the debug logs. Otherwise mutter-rpc
# is started without --debug and its output is discarded.
#
# Short auto-stop prove: ./scripts/weston-gsr-prove.sh → nested-weston-prove.sh
# Hold has no A4/READY SIGKILL. Classify deaths: docs/nested-debug.md
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

CLIENT_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc/org.gnome.ShellRpc.debug.log"
DEBUG=0
if [[ "${GSR_DEBUG:-0}" == "1" ]]; then
	DEBUG=1
	# Fresh logs for this hold so a debug session is readable.
	: >"$CLIENT_LOG"
	: >"$TEE_LOG"
fi
env_args=(
	DISPLAY="$DISPLAY"
	XAUTHORITY="${XAUTHORITY:-}"
	XDG_RUNTIME_DIR="$RT"
	WAYLAND_DISPLAY="$MUTTER_WL"
)
if [[ -n "${GI_RPC_JS_OVERRIDE_DIR:-}" ]]; then
	env_args+=(GI_RPC_JS_OVERRIDE_DIR="$GI_RPC_JS_OVERRIDE_DIR")
fi
if [[ -n "${GI_RPC_GJS_EMBED_DIR:-}" ]]; then
	env_args+=(GI_RPC_GJS_EMBED_DIR="$GI_RPC_GJS_EMBED_DIR")
fi
if [[ -n "${GI_RPC_LAUNCH_PROBE:-}" ]]; then
	env_args+=(GI_RPC_LAUNCH_PROBE="$GI_RPC_LAUNCH_PROBE")
fi
if [[ -n "${GI_RPC_REGISTER_CLASS_TRACE:-}" ]]; then
	env_args+=(GI_RPC_REGISTER_CLASS_TRACE="$GI_RPC_REGISTER_CLASS_TRACE")
fi
if [[ -n "${GI_RPC_APP_SEARCH_OBSERVE:-}" ]]; then
	env_args+=(GI_RPC_APP_SEARCH_OBSERVE="$GI_RPC_APP_SEARCH_OBSERVE")
fi
if [[ -n "${GI_META_SMOKE:-}" ]]; then
	env_args+=(GI_META_SMOKE="$GI_META_SMOKE")
fi
if [[ -n "${GI_META_SMOKE_CMD:-}" ]]; then
	env_args+=(GI_META_SMOKE_CMD="$GI_META_SMOKE_CMD")
fi
if [[ -n "${GI_META_SMOKE_WAIT_MS:-}" ]]; then
	env_args+=(GI_META_SMOKE_WAIT_MS="$GI_META_SMOKE_WAIT_MS")
fi
if [[ -n "${GI_WAYLAND_LAUNCH_UNSET_DISPLAY:-}" ]]; then
	env_args+=(GI_WAYLAND_LAUNCH_UNSET_DISPLAY="$GI_WAYLAND_LAUNCH_UNSET_DISPLAY")
fi
if [[ -n "${GI_META_GDB:-}" ]]; then
	env_args+=(GI_META_GDB="$GI_META_GDB")
fi

DBUS_CONFIG="$("$ROOT/scripts/prepare-nested-dbus.sh" "$RT/gsr-nested-dbus-$$")"
mutter_cmd=(
	"$MUTTER_RPC"
	--wayland --nested --no-x11
	--wayland-display="$MUTTER_WL"
)
if [[ "$DEBUG" == "1" ]]; then
	mutter_cmd=(
		"$MUTTER_RPC" --debug
		--wayland --nested --no-x11
		--wayland-display="$MUTTER_WL"
	)
fi
if [[ "$DEBUG" == "1" ]]; then
	env -u WAYLAND_SOCKET \
		GDK_BACKEND=wayland WAYLAND_DISPLAY="$MUTTER_WL" \
	dbus-run-session --config-file="$DBUS_CONFIG" -- \
		env "${env_args[@]}" \
			"${mutter_cmd[@]}" \
		> >(tee "$TEE_LOG") 2>&1 &
else
	# No --debug: do not tee or create the debug logs.
	env -u WAYLAND_SOCKET \
		GDK_BACKEND=wayland WAYLAND_DISPLAY="$MUTTER_WL" \
	dbus-run-session --config-file="$DBUS_CONFIG" -- \
		env "${env_args[@]}" \
			"${mutter_cmd[@]}" \
		>/dev/null 2>&1 &
fi
MPID=$!

FILL_PID=
if [[ "$DEBUG" != "1" ]]; then
	bash "$ROOT/scripts/weston-gsr-fill-window.sh" "$DISPLAY" &
	FILL_PID=$!
fi

set +e
wait "$MPID"
ec=$?
set -e
if [[ -n "${FILL_PID:-}" ]] && kill -0 "$FILL_PID" 2>/dev/null; then
	kill "$FILL_PID" 2>/dev/null || true
	wait "$FILL_PID" 2>/dev/null || true
fi
echo "nested-weston-hold: mutter exited ec=$ec (Weston stays up — reap dbus only)"
GSR_CLEAR_WESTON=0 "$ROOT/scripts/clear-nested-dbus.sh"
exit "$ec"
