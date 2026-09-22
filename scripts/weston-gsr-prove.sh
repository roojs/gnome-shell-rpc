#!/usr/bin/env bash
# Nested prove under Weston — agents / quick score.
#
#   ./scripts/weston-gsr-prove.sh
#
# Nest timeout 25s / settle 10s after READY=1 (debug logging is slow; do not
# stop on READY alone before prepare/A4 can run). Hard wall = 40s.
#
# Early-stop still wins if A4 marker appears. Hold without auto-kill:
# ./scripts/weston-gsr-session.sh
# Stay-up (no READY/A4 early-stop, run to nest timeout):
#   GSR_NESTED_STAYUP=1 ./scripts/weston-gsr-prove.sh
# Classify prove SIGKILL vs real death before gdb: docs/nested-debug.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export GSR_WESTON_MODE=prove
export GSR_WESTON_AUTO_CLOSE=1
export GSR_NESTED_TIMEOUT="${GSR_NESTED_TIMEOUT:-25}"
export GSR_NESTED_SETTLE="${GSR_NESTED_SETTLE:-10}"
exec timeout --foreground -k 2 40 "$ROOT/scripts/weston-gsr-session.sh"
