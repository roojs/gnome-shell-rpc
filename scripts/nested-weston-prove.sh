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
#   GSR_NESTED_TIMEOUT=25          # hard cap (seconds) — used by weston-gsr-prove.sh
#   GSR_NESTED_SETTLE=10           # seconds after READY=1 before stop (A4 window)
#   GSR_NESTED_STAYUP=1            # no READY+settle / A4 early-stop — run to TIMEOUT
#                                  # (stay-up; or use weston-gsr-session.sh hold)
#   GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-gsr
#   GI_RPC_JS_OVERRIDE_DIR=…     # optional debug overlay only — do not default
#   GI_META_SMOKE=key-smoke      # optional gjs-embed smoke (B1); early-stop on ok
#
# Prefer: ./scripts/weston-gsr-prove.sh (short) or ./scripts/weston-gsr-session.sh (hold).
# Stops early on A4 marker (when defined), smoke ok, or READY=1 + settle — does not
# sit idle for the full timeout when init already passed the bar.
# ℹ️ Early stop SIGKILLs mutter — client log looks like a crash (socket closed,
# pending RPC). Session/hold has no settle kill; if that dies, mutter exited for real.
# Classify the stop before gdb: docs/nested-debug.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MUTTER_RPC="${GSR_MUTTER_RPC:-$ROOT/build/src/mutter-rpc}"
TIMEOUT_SEC="${GSR_NESTED_TIMEOUT:-25}"
SETTLE_SEC="${GSR_NESTED_SETTLE:-10}"
STAYUP=0
if [[ "${GSR_NESTED_STAYUP:-0}" == "1" ]]; then
	STAYUP=1
	# Stay-up also skips A4 early-stop (same as GSR_NESTED_NO_A4=1).
	export GSR_NESTED_NO_A4=1
fi
RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
# Mutter's own Wayland socket (must not collide with Weston's wayland-gsr).
MUTTER_WL="${GSR_MUTTER_WAYLAND_DISPLAY:-wayland-mutter-gsr}"
WESTON_WL="${GSR_WESTON_SOCKET:-wayland-gsr}"
CLIENT_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc/org.gnome.ShellRpc.debug.log"
TEE_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc/nested-weston-prove.tee.log"
# Truncate so stale A4 / smoke markers from prior runs cannot early-stop.
: >"$CLIENT_LOG"
: >"$TEE_LOG"
# Stock path: Meta.is_restart means _prepareStartupAnimation ran (A4 proxy until
# a non-override startup-complete marker exists).
# GSR_NESTED_NO_A4=1 — keep running after A4 (stay-up / post-READY extension spawn).
A4_PAT='method=Meta\.is_restart'
if [[ "${GSR_NESTED_NO_A4:-0}" == "1" ]]; then
	A4_PAT='__gsr_no_a4_early_stop__'
fi
# Phase B1/B2: GI_META_SMOKE=key-smoke → key-smoke: ok
# Phase B3: GI_META_SMOKE=panel-click-smoke → panel-click-smoke: ok
# Phase B4: GI_META_SMOKE=focus-smoke → focus-smoke: ok
SMOKE_OK_PAT='(key-smoke: ok|panel-click-smoke: ok|focus-smoke: ok|layout-allocate-smoke: done|constraint-allocate-smoke: done|actor-allocate-box-smoke: done|adjustment-animatable-smoke: done|startup-allocate-smoke: done|workspace-dot-align-smoke: done|transformed-geom-smoke: done|allocate-segv-smoke: done|interval-peek-smoke: done|st-temp-smoke: ok)'
# When proving a smoke script, do not early-stop on A4 (init is not running).
SMOKE_MODE=0
if [[ -n "${GI_META_SMOKE:-}" && "${GI_META_SMOKE}" != "init" && "${GI_META_SMOKE}" != "init.js" ]]; then
	SMOKE_MODE=1
fi

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

echo "nested-weston-prove: DISPLAY=$DISPLAY weston=$WESTON_WL mutter_wl=$MUTTER_WL timeout=${TIMEOUT_SEC}s settle=${SETTLE_SEC}s${STAYUP:+ stayup=1}${GI_META_SMOKE:+ smoke=$GI_META_SMOKE}${GI_RPC_JS_OVERRIDE_DIR:+ override=$GI_RPC_JS_OVERRIDE_DIR}"

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
if [[ -n "${GI_META_SMOKE:-}" ]]; then
	env_args+=(GI_META_SMOKE="$GI_META_SMOKE")
fi
if [[ -n "${GI_META_GDB:-}" ]]; then
	env_args+=(GI_META_GDB="$GI_META_GDB")
fi
if [[ -n "${GI_META_GDB_BIN:-}" ]]; then
	env_args+=(GI_META_GDB_BIN="$GI_META_GDB_BIN")
fi
if [[ -n "${GI_META_GDB_EX:-}" ]]; then
	env_args+=(GI_META_GDB_EX="$GI_META_GDB_EX")
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

seen_smoke_ok() {
	[[ -n "${GI_META_SMOKE:-}" ]] || return 1
	rg -q "$SMOKE_OK_PAT" "$CLIENT_LOG" 2>/dev/null \
		|| rg -q "$SMOKE_OK_PAT" "$TEE_LOG" 2>/dev/null
}

while kill -0 "$MPID" 2>/dev/null; do
	if [[ $SECONDS -ge $deadline ]]; then
		reason="timeout"
		break
	fi
	if seen_smoke_ok; then
		reason="smoke-ok"
		sleep 0.2
		break
	fi
	if [[ "$SMOKE_MODE" -eq 0 ]] && seen_a4; then
		reason="prepare-started"
		sleep 0.3
		break
	fi
	if [[ "$SMOKE_MODE" -eq 0 ]] && [[ "$STAYUP" -eq 0 ]] && [[ -z "$ready_at" ]] && [[ -f "$CLIENT_LOG" ]] && rg -q 'READY=1' "$CLIENT_LOG" 2>/dev/null; then
		ready_at=$SECONDS
		echo "nested-weston-prove: READY=1 — settle ${SETTLE_SEC}s for prepare/startup"
	fi
	if [[ "$SMOKE_MODE" -eq 0 ]] && [[ "$STAYUP" -eq 0 ]] && [[ -n "$ready_at" ]] && [[ $((SECONDS - ready_at)) -ge $SETTLE_SEC ]]; then
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

set +e
wait "$MPID"
ec=$?
set -e
echo "nested-weston-prove: mutter exited ec=$ec after ${SECONDS}s"
exit "$ec"
