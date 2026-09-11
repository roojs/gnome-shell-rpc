#!/usr/bin/env bash
# Watch a drop directory for request.sh; run it with *your* privileges, then
# clear the request. Start once in a normal terminal (sudo works there).
#
#   ./scripts/agent-run-watch.sh
#
# Hard limits:
#   - Every job: timeout --foreground -k 5 (default 60s) — keeps TTY so sudo works
#   - Ctrl-C / SIGTERM aborts the job and exits
#   - Touch $DIR/cancel (or agent-run-drop.sh --cancel) aborts one job
#
# Do NOT use setsid here — that detaches the TTY and breaks sudo.
#
#   GSR_AGENT_RUN_DIR=/tmp/gsr-agent-run
#   GSR_AGENT_RUN_TIMEOUT=60
#   GSR_AGENT_RUN_POLL=0.5
set -euo pipefail

DIR="${GSR_AGENT_RUN_DIR:-/tmp/gsr-agent-run}"
POLL_SEC="${GSR_AGENT_RUN_POLL:-0.5}"
TIMEOUT_SEC="${GSR_AGENT_RUN_TIMEOUT:-60}"
REQUEST="$DIR/request.sh"
RUNNING="$DIR/request.sh.running"
CANCEL="$DIR/cancel"
LOG="$DIR/last.log"
EXITF="$DIR/last.exit"
PIDF="$DIR/watcher.pid"
JOBPIDF="$DIR/job.pid"

JOB_PID=""

mkdir -p "$DIR"
chmod 700 "$DIR" 2>/dev/null || true
echo $$ >"$PIDF"

kill_job() {
	local why="${1:-signal}"
	if [[ -n "${JOB_PID}" ]] && kill -0 "$JOB_PID" 2>/dev/null; then
		echo "agent-run-watch: killing job pid=$JOB_PID ($why)" | tee -a "$LOG" || true
		# timeout's child tree — TERM then KILL; also known nested leftovers
		kill -TERM "$JOB_PID" 2>/dev/null || true
		pkill -TERM -P "$JOB_PID" 2>/dev/null || true
		sleep 0.4
		kill -KILL "$JOB_PID" 2>/dev/null || true
		pkill -KILL -P "$JOB_PID" 2>/dev/null || true
		pkill -9 -f 'mutter-rpc --wayland' 2>/dev/null || true
		pkill -9 -f 'gnome-shell-rpc' 2>/dev/null || true
		pkill -9 -f 'machinectl shell testuser' 2>/dev/null || true
		wait "$JOB_PID" 2>/dev/null || true
	fi
	JOB_PID=""
	rm -f "$JOBPIDF" "$RUNNING" "$CANCEL" 2>/dev/null || true
}

on_exit() {
	kill_job "watcher-exit"
	rm -f "$PIDF" "$JOBPIDF" 2>/dev/null || true
}
trap on_exit EXIT
trap 'kill_job "SIGINT"; exit 130' INT
trap 'kill_job "SIGTERM"; exit 143' TERM

echo "agent-run-watch: dir=$DIR timeout=${TIMEOUT_SEC}s poll=${POLL_SEC}s"
echo "agent-run-watch: Ctrl-C stops watcher; touch $CANCEL aborts one job"
echo "agent-run-watch: using timeout --foreground (keeps TTY for sudo)"

while true; do
	if [[ -f "$CANCEL" && -z "${JOB_PID}" ]]; then
		rm -f "$CANCEL"
	fi

	if [[ -f "$REQUEST" ]]; then
		if ! mv "$REQUEST" "$RUNNING" 2>/dev/null; then
			sleep "$POLL_SEC"
			continue
		fi
		chmod +x "$RUNNING" 2>/dev/null || true
		: >"$LOG"
		rm -f "$EXITF" "$CANCEL"
		echo "agent-run-watch: running $(date -Is) timeout=${TIMEOUT_SEC}s" | tee -a "$LOG"

		set +e
		# --foreground: keep TTY for sudo; -k 5: SIGKILL after grace
		timeout --foreground -k 5 "$TIMEOUT_SEC" bash "$RUNNING" >>"$LOG" 2>&1 &
		JOB_PID=$!
		echo "$JOB_PID" >"$JOBPIDF"
		while kill -0 "$JOB_PID" 2>/dev/null; do
			if [[ -f "$CANCEL" ]]; then
				kill_job "cancel-file"
				echo "124" >"$EXITF"
				echo "agent-run-watch: canceled $(date -Is)" | tee -a "$LOG"
				JOB_PID=""
				break
			fi
			sleep "$POLL_SEC"
		done
		if [[ -n "${JOB_PID}" ]]; then
			wait "$JOB_PID"
			ec=$?
			JOB_PID=""
			rm -f "$JOBPIDF" "$RUNNING"
			echo "$ec" >"$EXITF"
			echo "agent-run-watch: exit=$ec $(date -Is)" | tee -a "$LOG"
		fi
		set -e
	fi
	sleep "$POLL_SEC"
done
