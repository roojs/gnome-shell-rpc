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
#   GSR_NESTED_TIMEOUT=5           # hard cap (seconds) — used by weston-gsr-prove.sh
#   GSR_NESTED_SETTLE=1            # seconds after READY=1 before stop
#   GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-gsr
#   GI_RPC_JS_OVERRIDE_DIR=…     # optional debug overlay only — do not default
#
# Prefer: ./scripts/weston-gsr-prove.sh (short) or ./scripts/weston-gsr-session.sh (hold).
# Stops early on A4 marker (when defined), or READY=1 + settle — does not sit idle
# for the full timeout when init already passed the bar.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MUTTER_RPC="${GSR_MUTTER_RPC:-$ROOT/build/src/mutter-rpc}"
TIMEOUT_SEC="${GSR_NESTED_TIMEOUT:-5}"
SETTLE_SEC="${GSR_NESTED_SETTLE:-1}"
RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
# Mutter's own Wayland socket (must not collide with Weston's wayland-gsr).
MUTTER_WL="${GSR_MUTTER_WAYLAND_DISPLAY:-wayland-mutter-gsr}"
WESTON_WL="${GSR_WESTON_SOCKET:-wayland-gsr}"
CLIENT_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc/org.gnome.ShellRpc.debug.log"
TEE_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc/nested-weston-prove.tee.log"
# Stock path: Meta.is_restart means _prepareStartupAnimation ran (A4 proxy until
# a non-override startup-complete marker exists).
A4_PAT='method=Meta\.is_restart'

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

echo "nested-weston-prove: DISPLAY=$DISPLAY weston=$WESTON_WL mutter_wl=$MUTTER_WL timeout=${TIMEOUT_SEC}s settle=${SETTLE_SEC}s${GI_RPC_JS_OVERRIDE_DIR:+ override=$GI_RPC_JS_OVERRIDE_DIR}"

stop_tree() {
	local pid="$1"
	kill "$pid" 2>/dev/null || true
	# mutter / shell children of dbus-run-session
	pkill -9 -P "$pid" 2>/dev/null || true
	pkill -9 -x mutter-rpc 2>/dev/null || true
	pkill -9 -x gnome-shell-rpc 2>/dev/null || true
	wait "$pid" 2>/dev/null || true
}

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
# Keep stdout for weston-autolaunch tee; also capture for markers
dbus-run-session -- \
	env "${env_args[@]}" \
		"$MUTTER_RPC" --debug --wayland --nested --no-x11 \
		--wayland-display="$MUTTER_WL" \
	> >(tee "$TEE_LOG") 2>&1 &
MPID=$!

deadline=$((SECONDS + TIMEOUT_SEC))
ready_at=""
reason="timeout"

seen_a4() {
	rg -q "$A4_PAT" "$CLIENT_LOG" 2>/dev/null \
		|| rg -q "$A4_PAT" "$TEE_LOG" 2>/dev/null
}

while kill -0 "$MPID" 2>/dev/null; do
	if [[ $SECONDS -ge $deadline ]]; then
		reason="timeout"
		break
	fi
	if seen_a4; then
		reason="prepare-started"
		sleep 0.3
		break
	fi
	if [[ -z "$ready_at" ]] && [[ -f "$CLIENT_LOG" ]] && rg -q 'READY=1' "$CLIENT_LOG" 2>/dev/null; then
		ready_at=$SECONDS
		echo "nested-weston-prove: READY=1 — settle ${SETTLE_SEC}s for prepare/startup"
	fi
	if [[ -n "$ready_at" ]] && [[ $((SECONDS - ready_at)) -ge $SETTLE_SEC ]]; then
		reason="READY=1+settle"
		break
	fi
	sleep 0.2
done

if kill -0 "$MPID" 2>/dev/null; then
	echo "nested-weston-prove: stop ($reason) after ${SECONDS}s"
	stop_tree "$MPID"
	[[ "$reason" == "timeout" ]] && exit 124
	exit 0
fi

wait "$MPID"
ec=$?
echo "nested-weston-prove: mutter exited ec=$ec after ${SECONDS}s"
exit "$ec"
