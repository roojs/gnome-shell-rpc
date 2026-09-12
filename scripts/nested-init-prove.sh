#!/usr/bin/env bash
# 0.8 Phase A — nested init completion bar (see docs/plans/0.8-init-complete-and-interaction.md)
#
# Prefer Weston isolation for live runs: ./scripts/weston-gsr-session.sh
# This script still drives scoring; default timeout is short + early-stop.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MUTTER_RPC="${ROOT}/build/src/mutter-rpc"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc"
TIMEOUT_SEC="${NESTED_INIT_PROVE_TIMEOUT:-5}"
SETTLE_SEC="${NESTED_INIT_PROVE_SETTLE:-1}"
TEE_LOG="${NESTED_INIT_PROVE_LOG:-/tmp/nested-init-prove.log}"
CLIENT_LOG="$CACHE/org.gnome.ShellRpc.debug.log"
# Optional debug only — do not default to src/shell-js
A4_PAT='method=Meta\.is_restart'

fail=0
pass() { echo "PASS  $*"; }
miss() { echo "FAIL  $*"; fail=1; }
warn() { echo "WARN  $*"; }

if [[ ! -x "$MUTTER_RPC" ]]; then
	echo "missing executable: $MUTTER_RPC (meson compile)" >&2
	exit 2
fi

kill "$(pidof mutter-rpc gnome-shell-rpc 2>/dev/null || true)" 2>/dev/null || true
sleep 0.2
mkdir -p "$CACHE"
: > "$CLIENT_LOG"
: > "$CACHE/mutter-rpc.debug.log"
rm -f "$TEE_LOG"

echo "nested-init-prove: timeout=${TIMEOUT_SEC}s settle=${SETTLE_SEC}s log=$TEE_LOG"

stop_tree() {
	local pid="$1"
	kill "$pid" 2>/dev/null || true
	pkill -9 -P "$pid" 2>/dev/null || true
	pkill -9 -x mutter-rpc 2>/dev/null || true
	pkill -9 -x gnome-shell-rpc 2>/dev/null || true
	wait "$pid" 2>/dev/null || true
}

set +e
env_args=()
if [[ -n "${GI_RPC_JS_OVERRIDE_DIR:-}" ]]; then
	env_args+=(GI_RPC_JS_OVERRIDE_DIR="$GI_RPC_JS_OVERRIDE_DIR")
fi
dbus-run-session -- \
	env "${env_args[@]}" \
	"$MUTTER_RPC" --debug --wayland --nested \
	>"$TEE_LOG" 2>&1 &
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
	if [[ -z "$ready_at" ]] && rg -q 'READY=1' "$CLIENT_LOG" 2>/dev/null; then
		ready_at=$SECONDS
		echo "nested-init-prove: READY=1 — settle ${SETTLE_SEC}s"
	fi
	if [[ -n "$ready_at" ]] && [[ $((SECONDS - ready_at)) -ge $SETTLE_SEC ]]; then
		reason="READY=1+settle"
		break
	fi
	sleep 0.2
done

if kill -0 "$MPID" 2>/dev/null; then
	echo "nested-init-prove: stop ($reason) after ${SECONDS}s"
	stop_tree "$MPID"
	exit_code=124
	[[ "$reason" != "timeout" ]] && exit_code=0
else
	wait "$MPID"
	exit_code=$?
fi
set -e
echo "nested-init-prove: mutter-rpc exit=$exit_code reason=$reason"

ALL_LOGS=("$CLIENT_LOG" "$CACHE/mutter-rpc.debug.log" "$TEE_LOG")

# A1 notify_ready + reply
last_nr="$(rg 'id=([0-9]+) method=Meta-Context\.notify_ready' "$CLIENT_LOG" -o -r '$1' 2>/dev/null | tail -1 || true)"
if [[ -n "$last_nr" ]] && rg -q "replied id=${last_nr}" "$CLIENT_LOG"; then
	pass "A1 Meta-Context.notify_ready (id=${last_nr} replied)"
else
	miss "A1 Meta-Context.notify_ready (id=${last_nr:-?} not replied)"
fi

# A2 util_sd_notify (Shell.util_sd_notify → GLib.debug in Util.vala)
if rg -q 'READY=1' "$CLIENT_LOG" 2>/dev/null; then
	pass "A2 util_sd_notify (READY=1 in client log)"
else
	warn "A2 util_sd_notify not seen — main.js idle may not have run"
fi

# A4 proxy until stock startup-complete is observable without JS override:
# Meta.is_restart ⇒ _prepareStartupAnimation ran (layout.js).
if rg -q "$A4_PAT" "$CLIENT_LOG" "$TEE_LOG" 2>/dev/null; then
	pass "A4 prepare started (Meta.is_restart)"
else
	miss "A4 prepare not started (no Meta.is_restart — post-READY hang?)"
fi

# A5 socket / invoke balance
if rg -q 'socket closed' "${ALL_LOGS[@]}" 2>/dev/null; then
	miss "A5 socket closed during run"
else
	pass "A5 no socket closed"
fi

enter="$(rg -c 'DBG invoke ENTER' "$CLIENT_LOG" 2>/dev/null || echo 0)"
done_reply="$(rg -c 'DBG invoke REPLY done' "$CLIENT_LOG" 2>/dev/null || echo 0)"
if [[ "$enter" == "$done_reply" ]]; then
	pass "A5 invoke ENTER==REPLY done ($enter)"
else
	miss "A5 invoke mismatch ENTER=$enter REPLY done=$done_reply"
fi

# A3 weak: extension-related CRITICALs (informational)
if rg -q 'night-light-supported|unsafe-mode' "$TEE_LOG" 2>/dev/null; then
	warn "A3 Meta bind gaps (night-light / unsafe-mode) — may block extension tail"
fi

if rg -q 'Assertion failed:.*stack position' "$TEE_LOG" 2>/dev/null; then
	warn "A3 message-list layout asserts (Cover/Header) — JS still running but noisy"
fi

echo "nested-init-prove: done fail=$fail"
exit "$fail"
