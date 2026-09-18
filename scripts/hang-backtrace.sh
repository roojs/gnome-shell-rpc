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

OUT="/tmp/gsr-hang-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

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

L=~/.cache/gnome-shell-rpc
tail -n 80 "$L/org.gnome.ShellRpc.debug.log"  > "$OUT/client.log.tail.txt" 2>/dev/null || true
tail -n 80 "$L/mutter-rpc.debug.log"          > "$OUT/server.log.tail.txt" 2>/dev/null || true
tail -n 25 "$L/weston-autolaunch-prove.log"   > "$OUT/stop-reason.tail.txt" 2>/dev/null || true

echo
echo "=================================================================="
echo "Captured to: $OUT"
ls -la "$OUT"
echo "=================================================================="
echo "Paste this one line back to the agent:"
echo "    $OUT"
