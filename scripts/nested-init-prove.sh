#!/usr/bin/env bash
# 0.8 Phase A — nested init completion bar (see docs/plans/0.8-init-complete-and-interaction.md)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MUTTER_RPC="${ROOT}/build/src/mutter-rpc"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc"
TIMEOUT_SEC="${NESTED_INIT_PROVE_TIMEOUT:-50}"
TEE_LOG="${NESTED_INIT_PROVE_LOG:-/tmp/nested-init-prove.log}"

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
: > "$CACHE/org.gnome.ShellRpc.debug.log"
: > "$CACHE/mutter-rpc.debug.log"
rm -f "$TEE_LOG"

echo "nested-init-prove: timeout=${TIMEOUT_SEC}s log=$TEE_LOG"
set +e
timeout "$TIMEOUT_SEC" dbus-run-session "$MUTTER_RPC" --debug --wayland --nested \
	>"$TEE_LOG" 2>&1
exit_code=$?
set -e
echo "nested-init-prove: mutter-rpc exit=$exit_code (124=timeout ok)"

CLIENT_LOG="$CACHE/org.gnome.ShellRpc.debug.log"
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

# A4 startup-complete (Shell.Global signal)
if rg -q 'startup-complete' "$CLIENT_LOG" 2>/dev/null; then
	pass "A4 startup-complete"
else
	miss "A4 startup-complete not seen"
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
