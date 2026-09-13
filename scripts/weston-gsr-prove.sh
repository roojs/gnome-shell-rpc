#!/usr/bin/env bash
# Nested prove under Weston — agents / quick score.
#
#   ./scripts/weston-gsr-prove.sh
#
# Nest timeout 15s / settle 5s after READY=1 (debug logging is slow; do not
# stop on READY alone before prepare/A4 can run). Hard wall = 30s.
#
# Early-stop still wins if A4 marker appears. Hold without auto-kill:
# ./scripts/weston-gsr-session.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export GSR_WESTON_MODE=prove
export GSR_NESTED_TIMEOUT=15
export GSR_NESTED_SETTLE=5
exec timeout --foreground -k 2 30 "$ROOT/scripts/weston-gsr-session.sh"
