#!/usr/bin/env bash
# Queue a privileged command for scripts/agent-run-watch.sh.
# Body from stdin or a file argument.
#
#   ./scripts/agent-run-drop.sh <<'EOF'
#   …command…
#   EOF
#
#   ./scripts/agent-run-drop.sh --wait <<'EOF'    # wait up to timeout+margin
#   …
#   EOF
#
#   ./scripts/agent-run-drop.sh --cancel          # abort current job
set -euo pipefail

DIR="${GSR_AGENT_RUN_DIR:-/tmp/gsr-agent-run}"
REQUEST="$DIR/request.sh"
TMP="$DIR/request.sh.next"
LOG="$DIR/last.log"
EXITF="$DIR/last.exit"
PIDF="$DIR/watcher.pid"
CANCEL="$DIR/cancel"
WAIT=0
WAIT_MAX="${GSR_AGENT_RUN_WAIT_MAX:-90}"

if [[ "${1:-}" == "--cancel" ]]; then
	mkdir -p "$DIR"
	touch "$CANCEL"
	if [[ -f "$DIR/job.pid" ]]; then
		pid="$(cat "$DIR/job.pid" 2>/dev/null || true)"
		if [[ -n "$pid" ]]; then
			kill -TERM "$pid" 2>/dev/null || true
			pkill -TERM -P "$pid" 2>/dev/null || true
			sleep 0.2
			kill -KILL "$pid" 2>/dev/null || true
			pkill -KILL -P "$pid" 2>/dev/null || true
		fi
	fi
	pkill -9 -f 'mutter-rpc --wayland' 2>/dev/null || true
	pkill -9 -f 'gnome-shell-rpc' 2>/dev/null || true
	pkill -9 -f 'machinectl shell testuser' 2>/dev/null || true
	echo "agent-run-drop: cancel requested"
	exit 0
fi

if [[ "${1:-}" == "--wait" ]]; then
	WAIT=1
	shift
fi

if [[ ! -f "$PIDF" ]] || ! kill -0 "$(cat "$PIDF")" 2>/dev/null; then
	echo "agent-run-drop: watcher not running (no $PIDF). Start:" >&2
	echo "  ./scripts/agent-run-watch.sh" >&2
	exit 2
fi

if [[ -f "$DIR/request.sh.running" ]]; then
	echo "agent-run-drop: a job is already running; --cancel first or wait" >&2
	exit 3
fi

mkdir -p "$DIR"
if [[ $# -ge 1 ]]; then
	cp "$1" "$TMP"
else
	cat >"$TMP"
fi
chmod +x "$TMP"

# Refuse host-GNOME nested proves (freeze the desktop). Allow only when the
# script clearly targets the Weston isolation socket (wayland-gsr) or the
# nested-weston-prove helper — or GSR_AGENT_ALLOW_NESTED=1.
if [[ "${GSR_AGENT_ALLOW_NESTED:-0}" != "1" ]]; then
	if grep -Eq 'mutter-rpc|--nested|machinectl shell|nested-weston-prove' "$TMP" 2>/dev/null; then
		if ! grep -Eq 'wayland-gsr|nested-weston-prove|GSR_WESTON_SOCKET' "$TMP" 2>/dev/null; then
			rm -f "$TMP"
			echo "agent-run-drop: refused nested under host GNOME (freezes desktop)." >&2
			echo "  Use scripts/nested-weston-prove.sh (Weston socket wayland-gsr), or set GSR_AGENT_ALLOW_NESTED=1." >&2
			exit 4
		fi
	fi
fi

rm -f "$EXITF"
mv -f "$TMP" "$REQUEST"
echo "agent-run-drop: queued $REQUEST"

if [[ "$WAIT" -eq 1 ]]; then
	echo "agent-run-drop: waiting for $EXITF (max ${WAIT_MAX}s)"
	deadline=$((SECONDS + WAIT_MAX))
	while [[ ! -f "$EXITF" ]]; do
		if (( SECONDS >= deadline )); then
			echo "agent-run-drop: wait timed out — try: $0 --cancel" >&2
			exit 124
		fi
		sleep 0.2
	done
	ec="$(cat "$EXITF")"
	echo "agent-run-drop: exit=$ec (log: $LOG)"
	exit "$ec"
fi
