#!/usr/bin/env bash
# Weston panel button. Starts the nested shell once, for a demo recording:
# Weston is already up, press this, the shell fills the window.
#
# Debug sessions still auto-open the log terminal from autolaunch. This
# button does nothing while gsr-server is already running.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
ENV_FILE="$RT/gsr-weston-autolaunch.env"
XDISPLAY_FILE="$RT/gsr-weston-xdisplay"
LOCK="$RT/gsr-weston-launch.lock"

exec 9>"$LOCK"
if ! flock -n 9; then
	exit 0
fi

if [[ -f "$ENV_FILE" ]]; then
	set -a
	# shellcheck disable=SC1090
	source "$ENV_FILE"
	set +a
fi

if [[ ! -s "$XDISPLAY_FILE" ]]; then
	echo "weston-gsr-launch: missing $XDISPLAY_FILE" >&2
	exit 2
fi

export DISPLAY="$(<"$XDISPLAY_FILE")"
export XDG_RUNTIME_DIR="$RT"
unset WAYLAND_DISPLAY
unset WAYLAND_SOCKET

if pgrep -x gsr-server >/dev/null 2>&1 || pgrep -x mutter-rpc >/dev/null 2>&1; then
	exit 0
fi

exec "$ROOT/scripts/nested-weston-hold.sh"
