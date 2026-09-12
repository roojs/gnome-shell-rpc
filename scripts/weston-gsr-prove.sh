#!/usr/bin/env bash
# Short nested prove under Weston — for agents / quick score (**5s** nest).
#
#   ./scripts/weston-gsr-prove.sh
#
# Always uses nest timeout 5s / settle 1s (ignores stale exported
# GSR_NESTED_* from the shell). Hard wall = 15s so Weston cannot hang.
#
# To look at the nest without auto-kill: ./scripts/weston-gsr-session.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export GSR_WESTON_MODE=prove
export GSR_NESTED_TIMEOUT=5
export GSR_NESTED_SETTLE=1
exec timeout --foreground -k 2 15 "$ROOT/scripts/weston-gsr-session.sh"
