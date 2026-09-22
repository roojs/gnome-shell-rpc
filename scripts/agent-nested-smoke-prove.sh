#!/usr/bin/env bash
# Agents only: nested smoke + timed prove + GSR_WESTON_AUTO_CLOSE=1.
# Does not change product code; uses src/gjs-embed/* smokes.
#
#   GI_META_SMOKE=wayland-launch-smoke ./scripts/agent-nested-smoke-prove.sh
#   GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 GI_META_SMOKE=wayland-launch-smoke ./scripts/agent-nested-smoke-prove.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -z "${GI_META_SMOKE:-}" ]]; then
	echo "agent-nested-smoke-prove: set GI_META_SMOKE" >&2
	exit 2
fi

export GSR_WESTON_MODE=prove
export GSR_WESTON_AUTO_CLOSE=1
case "${GI_META_SMOKE%.js}" in
	app-search-launch-smoke|app-search-smoke|date-menu-open-smoke)
		export GSR_NESTED_TIMEOUT="${GSR_NESTED_TIMEOUT:-90}"
		;;
	*)
		export GSR_NESTED_TIMEOUT="${GSR_NESTED_TIMEOUT:-25}"
		;;
esac
export GSR_NESTED_STAYUP="${GSR_NESTED_STAYUP:-0}"

exec "$ROOT/scripts/weston-gsr-session.sh"
