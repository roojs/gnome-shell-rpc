#!/usr/bin/env bash
#
# Capture paired backtraces of the nested "hang after settle" — client
# (gnome-shell-rpc) + server (mutter-rpc) + the last RPC log lines.
#
# HOW TO USE:
#   Terminal 1: start the nested session (leave it running):
#     GSR_NESTED_STAYUP=1 GSR_NESTED_TIMEOUT=180 GSR_WESTON_MODE=prove \
#       ./scripts/weston-gsr-session.sh
#   Terminal 2: the MOMENT it freezes (e.g. right after the IBus notification
#   disappears), run:
#     ./scripts/hang-backtrace.sh
#
# It writes everything into one folder and prints the path to paste back.
set -u

# Not /tmp: the 2026-09-18 09:40 capture was lost to tmp cleanup before it
# could be read back. Keep captures beside the logs they explain.
STAMP="hang-$(date +%Y%m%d-%H%M%S)"
OUT="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc/$STAMP"
if ! mkdir -p "$OUT" 2>/dev/null; then
	OUT="/tmp/gsr-$STAMP"
	mkdir -p "$OUT"
	echo "!! cache dir not writable — captured to $OUT (copy it out before tmp cleanup)"
fi

# gdb attach needs ptrace_scope=0 on Ubuntu (default 1 blocks -p). Sudo prompt.
scope="$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo 0)"
if [[ "$scope" != "0" ]]; then
	echo "ptrace_scope=$scope — enabling (sudo password may be asked)..."
	sudo sysctl -q kernel.yama.ptrace_scope=0 || true
fi

# Record everything running so we can adjust if names differ.
ps -eo pid,comm,args | grep -E 'mutter-rpc|gnome-shell-rpc|weston' \
	| grep -v grep > "$OUT/ps.txt" 2>/dev/null || true

dump() {   # $1 = label   $2 = exact process name (comm)
	local label="$1" name="$2" pids pid
	pids="$(pgrep -x "$name" || true)"
	if [[ -z "$pids" ]]; then
		pids="$(pgrep -f "src/$name" || true)"
	fi
	if [[ -z "$pids" ]]; then
		echo "!! no process found for $label ($name)" | tee -a "$OUT/index.txt"
		return
	fi
	for pid in $pids; do
		echo "== $label pid=$pid ==" | tee -a "$OUT/index.txt"
		gdb -p "$pid" -batch \
			-ex "set pagination off" \
			-ex "info threads" \
			-ex "thread apply all bt full" \
			> "$OUT/$label-$pid.bt.txt" 2>&1
		echo "   -> $OUT/$label-$pid.bt.txt"
	done
}

dump client gnome-shell-rpc
dump server mutter-rpc

# Socket queues decide the argument: unread bytes sitting in a receive queue
# mean the reply WAS written and the peer is not draining (consumer/poll bug);
# empty queues both ways mean nobody wrote (a real cross-wait).
{
	echo "== unix socket queues (rq = unread by the reader) =="
	ss -x -m -p 2>/dev/null | grep -aE 'mutter-rpc|gnome-shell-rpc|State|Recv-Q' || true
} > "$OUT/socket-queues.txt" 2>/dev/null || true

L=~/.cache/gnome-shell-rpc
# Whole logs, not tails: the in-flight id usually has to be traced back through
# several thousand lines of the emit storm.
gzip -c "$L/org.gnome.ShellRpc.debug.log" > "$OUT/client.debug.log.gz" 2>/dev/null || true
gzip -c "$L/mutter-rpc.debug.log"         > "$OUT/server.debug.log.gz" 2>/dev/null || true
tail -n 80 "$L/org.gnome.ShellRpc.debug.log"  > "$OUT/client.log.tail.txt" 2>/dev/null || true
tail -n 80 "$L/mutter-rpc.debug.log"          > "$OUT/server.log.tail.txt" 2>/dev/null || true
tail -n 25 "$L/weston-autolaunch-prove.log"   > "$OUT/stop-reason.tail.txt" 2>/dev/null || true

# The two ends of the deadlock, straight out of the logs: last request the
# client sent, last request the server read, and every server connection seen.
{
	echo "== client: last call_poll sends (Client.vala id=… method=…) =="
	grep -a "method=" "$L/org.gnome.ShellRpc.debug.log" 2>/dev/null | tail -n 10
	echo
	echo "== server: last recv (Connection.vala recv id=… method=…) =="
	echo "   src/rpc/Connection.vala:NNN  = drain_readable → read INSIDE hook.emit"
	echo "   OPC Connection.vala:NNN      = on_input_ready → read from the main loop"
	grep -a "recv id=" "$L/mutter-rpc.debug.log" 2>/dev/null | tail -n 10
	echo
	echo "== server: connections seen (emit_wait_poll polls ONE conn fd) =="
	grep -ao "conn=0x[0-9a-f]*" "$L/mutter-rpc.debug.log" 2>/dev/null \
		| sort | uniq -c | sort -rn
} > "$OUT/in-flight.txt" 2>/dev/null || true

echo
echo "=================================================================="
echo "Captured to: $OUT"
ls -la "$OUT"
echo "=================================================================="
echo "Paste this one line back to the agent:"
echo "    $OUT"
