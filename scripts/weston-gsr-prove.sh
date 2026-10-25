#!/usr/bin/env bash
# Nested prove under Weston — agents / quick score.
#
#   ./scripts/weston-gsr-prove.sh
#
# Stays up until the overview page is on screen, then a few seconds.
# Nest timeout 35s. Hard wall = 50s.
#
# Hold without auto-kill:
# ./scripts/weston-gsr-session.sh
# Stay-up (run to nest timeout, do not stop when the overview is up):
#   GSR_NESTED_STAYUP=1 ./scripts/weston-gsr-prove.sh
# Classify prove SIGKILL vs real death before gdb: docs/nested-debug.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export GSR_WESTON_MODE=prove
export GSR_WESTON_AUTO_CLOSE=1
export GSR_NESTED_TIMEOUT="${GSR_NESTED_TIMEOUT:-35}"
exec timeout --foreground -k 2 50 "$ROOT/scripts/weston-gsr-session.sh"
