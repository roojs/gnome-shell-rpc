#!/usr/bin/env bash
# Temp: run mutter-rpc under gdb; dump bt on SIGSEGV. Not for ship.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/src/mutter-rpc"
BT_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/gnome-shell-rpc/mutter-rpc-segfault.bt"
exec gdb -batch -q \
	-ex "set pagination off" \
	-ex "set confirm off" \
	-ex "run" \
	-ex "thread apply all bt full" \
	-ex "quit" \
	--args "$BIN" "$@" >"$BT_LOG" 2>&1
