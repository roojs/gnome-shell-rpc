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
#   GSR_NESTED_TIMEOUT=35          # hard cap (seconds) — used by weston-gsr-prove.sh
#   GSR_NESTED_STAYUP=1            # no picker stop — run to TIMEOUT
#                                  # (stay-up; or use weston-gsr-session.sh hold)
#   GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-gsr
#   GI_RPC_JS_OVERRIDE_DIR=…     # optional debug overlay only — do not default
#   GI_META_SMOKE=key-smoke      # optional gjs-embed smoke (B1); early-stop on ok
#
# Prefer: ./scripts/weston-gsr-prove.sh (short) or ./scripts/weston-gsr-session.sh (hold).
# Stops when the overview page is up (bottom bar finished rising), then holds
# a few seconds so the calls on that page are in the log. Smoke ok still stops
# first. Stay-up runs to the timeout.
# ℹ️ Early stop SIGKILLs mutter — client log looks like a crash (socket closed,
# pending RPC). Session/hold has no settle kill; if that dies, mutter exited for real.
# Classify the stop before gdb: docs/nested-debug.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "${GSR_MUTTER_RPC:-}" ]]; then
	MUTTER_RPC="$GSR_MUTTER_RPC"
elif [[ -x "$ROOT/build/src/gsr-server" ]]; then
	MUTTER_RPC="$ROOT/build/src/gsr-server"
else
	MUTTER_RPC="$ROOT/build/src/mutter-rpc"
fi
# Uninstalled typelibs sit next to this binary. Installed runs leave it unset.
if [[ -z "${GSR_TYPELIB_DIR:-}" ]]; then
	export GSR_TYPELIB_DIR="$(dirname "$MUTTER_RPC")"
fi
TIMEOUT_SEC="${GSR_NESTED_TIMEOUT:-35}"
# Seconds to keep the nest after the overview page is up.
PICKER_HOLD_SEC="${GSR_NESTED_PICKER_HOLD:-3}"
STAYUP=0
if [[ "${GSR_NESTED_STAYUP:-0}" == "1" ]]; then
	STAYUP=1
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
# layout.js emits startup-complete after the dash has risen. main.js then logs
# this line. That is the overview page with the bottom bar, not an earlier boot marker.
PICKER_PAT='GNOME Shell started at'
# Phase B1/B2: GI_META_SMOKE=key-smoke → key-smoke: ok
# Phase B3: GI_META_SMOKE=panel-click-smoke → panel-click-smoke: ok
# Phase B4: GI_META_SMOKE=focus-smoke → focus-smoke: ok
SMOKE_OK_PAT='(key-smoke: ok|panel-click-smoke: ok|focus-smoke: ok|meta-smoke: put:|layout-allocate-smoke: done|constraint-allocate-smoke: done|actor-allocate-box-smoke: done|adjustment-animatable-smoke: done|layout-expansion-smoke: done|startup-allocate-smoke: done|workspace-dot-align-smoke: done|transformed-geom-smoke: done|allocate-segv-smoke: done|interval-peek-smoke: done|st-temp-smoke: ok|captured-event-smoke: ok|workspace-background-allocate-smoke: done|workarea-panel-inset-smoke: done|workarea-panel-chrome-smoke: done|workarea-reentrant-emit-smoke: done|app-search-smoke: done|app-launch-boundary-smoke: ok|wayland-launch-smoke: ok|date-menu-open-smoke: ok|style-reenter-smoke: ok|dash-hover-style-smoke: ok|quicksettings-layout-neg-smoke: ok|picker-second-launch: ok|help-click-smoke: ok|thumbnail-smoke: ok|drawing-area-reenter-smoke: ok|drawing-area-smoke: ok|slider-grab-smoke: ok|workspace-select-smoke: ok|overview-window-activate-smoke: ok|overview-thumbnail-drag-smoke: ok|scale-transition-gap-smoke: ok|overview-search-double-key: ok|viewport-scroll-child-smoke: done|viewport-scroll-child-smoke: ok|menu-expander-overlap/ui/init: ok|startup-overview-sequence/ui/init: ok)'
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

echo "nested-weston-prove: DISPLAY=$DISPLAY weston=$WESTON_WL mutter_wl=$MUTTER_WL timeout=${TIMEOUT_SEC}s picker_hold=${PICKER_HOLD_SEC}s${STAYUP:+ stayup=1}${GI_META_SMOKE:+ smoke=$GI_META_SMOKE}${GI_RPC_JS_OVERRIDE_DIR:+ override=$GI_RPC_JS_OVERRIDE_DIR}"

stop_tree() {
	local pid="$1"
	kill "$pid" 2>/dev/null || true
	# mutter / shell children of dbus-run-session
	pkill -9 -P "$pid" 2>/dev/null || true
	pkill -9 -x mutter-rpc 2>/dev/null || true
	pkill -9 -x gnome-shell-rpc 2>/dev/null || true
	pkill -9 -x gsr-server 2>/dev/null || true
	pkill -9 -x gsr-client 2>/dev/null || true
	wait "$pid" 2>/dev/null || true
	# dbus-daemon --config-file gsr-nested-dbus is reparented to init
	# if we only SIGKILL mutter — see scripts/clear-nested-dbus.sh
	if [[ "${GSR_WESTON_AUTO_CLOSE:-0}" == "1" ]]; then
		GSR_CLEAR_WESTON=1 "$ROOT/scripts/clear-nested-dbus.sh"
	else
		GSR_CLEAR_WESTON=0 "$ROOT/scripts/clear-nested-dbus.sh"
	fi
}

: >"$TEE_LOG"
env_args=(
	DISPLAY="$DISPLAY"
	XAUTHORITY="${XAUTHORITY:-}"
	XDG_RUNTIME_DIR="$RT"
	WAYLAND_DISPLAY="$MUTTER_WL"
)
if [[ "${GI_META_SMOKE-}" == "app-launch-boundary-smoke" || "${GI_META_SMOKE-}" == "app-launch-boundary-smoke.js" ]]; then
	PROBE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc"
	PROBE_LOG="$PROBE_DIR/app-launch-boundary.probe.log"
	PROBE_STDERR="$PROBE_DIR/app-launch-boundary.stderr.log"
	PROBE_WINDOW="$PROBE_DIR/app-launch-boundary.window.log"
	mkdir -p "$PROBE_DIR"
	: >"$PROBE_LOG"
	: >"$PROBE_STDERR"
	: >"$PROBE_WINDOW"
	env_args+=(
		PATH="$ROOT/scripts/app-launch-probe-bin:$PATH"
		GI_APP_LAUNCH_PROBE_LOG="$PROBE_LOG"
		GI_APP_LAUNCH_PROBE_STDERR="$PROBE_STDERR"
		GI_APP_LAUNCH_PROBE_WINDOW_LOG="$PROBE_WINDOW"
	)
fi
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
# Mutter-rpc process (compositor launch context), not only gnome-shell-rpc child.
if [[ -n "${GI_WAYLAND_LAUNCH_UNSET_DISPLAY:-}" ]]; then
	export GI_WAYLAND_LAUNCH_UNSET_DISPLAY
fi
if [[ -n "${GI_WAYLAND_LAUNCH_GDK_WAYLAND:-}" ]]; then
	env_args+=(GI_WAYLAND_LAUNCH_GDK_WAYLAND="$GI_WAYLAND_LAUNCH_GDK_WAYLAND")
	export GI_WAYLAND_LAUNCH_GDK_WAYLAND
fi
if [[ -n "${GI_META_GDB:-}" ]]; then
	env_args+=(GI_META_GDB="$GI_META_GDB")
fi
PLACE_SO="$ROOT/build/libgsr-nested-place.so"
if [[ -f "$PLACE_SO" ]]; then
	env_args+=(LD_PRELOAD="${PLACE_SO}${LD_PRELOAD:+:$LD_PRELOAD}")
fi
if [[ -n "${GI_META_GDB_BIN:-}" ]]; then
	env_args+=(GI_META_GDB_BIN="$GI_META_GDB_BIN")
fi
if [[ -n "${GI_META_GDB_EX:-}" ]]; then
	env_args+=(GI_META_GDB_EX="$GI_META_GDB_EX")
fi
DBUS_CONFIG="$("$ROOT/scripts/prepare-nested-dbus.sh" "$RT/gsr-nested-dbus-$$")"
# Weston starts this script as one of its own Wayland clients, so its private
# WAYLAND_SOCKET points back to Weston. It must not leak into mutter-rpc, the
# nested session bus, or applications launched for the compositor under test.
# GTK otherwise also inherits the outer Cursor backend preference and maps on
# Weston's Xwayland instead of wayland-mutter-gsr.
# Keep stdout for weston-autolaunch tee; also capture for markers.
env -u WAYLAND_SOCKET \
	GDK_BACKEND=wayland WAYLAND_DISPLAY="$MUTTER_WL" \
dbus-run-session --config-file="$DBUS_CONFIG" -- \
	env "${env_args[@]}" \
		"$MUTTER_RPC" --debug --wayland --nested --no-x11 \
		--wayland-display="$MUTTER_WL" \
	> >(tee "$TEE_LOG") 2>&1 &
MPID=$!

deadline=$((SECONDS + TIMEOUT_SEC))
picker_at=""
reason="timeout"

seen_picker() {
	rg -q "$PICKER_PAT" "$CLIENT_LOG" 2>/dev/null \
		|| rg -q "$PICKER_PAT" "$TEE_LOG" 2>/dev/null
}

seen_smoke_ok() {
	[[ -n "${GI_META_SMOKE:-}" ]] || return 1
	# This smoke terminates its own context. Its verbose shell logs can contain
	# unrelated historical marker strings, so do not short-circuit on the
	# aggregate marker regex.
	[[ "${GI_META_SMOKE-}" != "app-search-launch-smoke" && "${GI_META_SMOKE-}" != "app-search-launch-smoke.js" ]] || return 1
	rg -q "$SMOKE_OK_PAT" "$CLIENT_LOG" 2>/dev/null \
		|| rg -q "$SMOKE_OK_PAT" "$TEE_LOG" 2>/dev/null
}

seen_smoke_fail() {
	[[ "$SMOKE_MODE" -eq 1 ]] || return 1
	local stem="${GI_META_SMOKE-}"
	stem="${stem%.js}"
	[[ -n "$stem" ]] || return 1
	rg -q "${stem}: miss" "$CLIENT_LOG" 2>/dev/null \
		&& return 0
	rg -q "${stem}: miss" "$TEE_LOG" 2>/dev/null \
		&& return 0
	rg -q "Module file://.*${stem}\\.js threw an exception" "$CLIENT_LOG" 2>/dev/null \
		&& return 0
	rg -q "Module file://.*${stem}\\.js threw an exception" "$TEE_LOG" 2>/dev/null \
		&& return 0
	return 1
}

while kill -0 "$MPID" 2>/dev/null; do
	if [[ "${GI_META_SMOKE-}" == "app-launch-boundary-smoke" || "${GI_META_SMOKE-}" == "app-launch-boundary-smoke.js" ]] \
			&& [[ -n "${PROBE_WINDOW:-}" ]] \
			&& rg -q 'app-launch-boundary-smoke: Shell.App.launch returned true' "$TEE_LOG" 2>/dev/null \
			&& rg -q 'notification method=Window.created object_type=Window' "$TEE_LOG" 2>/dev/null; then
		printf 'mutter_window_created=1\n' >"$PROBE_WINDOW"
	fi
	if [[ $SECONDS -ge $deadline ]]; then
		reason="timeout"
		break
	fi
	if seen_smoke_ok; then
		reason="smoke-ok"
		sleep 0.2
		break
	fi
	if seen_smoke_fail; then
		reason="smoke-fail"
		sleep 0.2
		break
	fi
	if [[ "$SMOKE_MODE" -eq 0 ]] && [[ "$STAYUP" -eq 0 ]] && [[ -z "$picker_at" ]] && seen_picker; then
		picker_at=$SECONDS
		echo "nested-weston-prove: overview up — hold ${PICKER_HOLD_SEC}s"
	fi
	if [[ "$SMOKE_MODE" -eq 0 ]] && [[ "$STAYUP" -eq 0 ]] && [[ -n "$picker_at" ]] && [[ $((SECONDS - picker_at)) -ge $PICKER_HOLD_SEC ]]; then
		reason="picker-up"
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
