#!/usr/bin/env bash
# Reap leftover dbus-run-session buses from nested mutter-rpc.
#
# Not a product bug — prove/hold SIGKILL mutter and leave
# ``dbus-daemon --print-address --session`` reparented to init. Enough of
# those (plus extra at-spi buses) and the machine hits D-Bus max
# connections and the session bus stops working.
#
# Does not touch the systemd user bus or the system bus.
#
#   ./scripts/clear-nested-dbus.sh
set -euo pipefail

UID_NOW="$(id -u)"
SOCK="${GSR_WESTON_SOCKET:-wayland-gsr}"
RT="${XDG_RUNTIME_DIR:-/run/user/$UID_NOW}"

pkill -9 -u "$UID_NOW" -x mutter-rpc 2>/dev/null || true
pkill -9 -u "$UID_NOW" -x gnome-shell-rpc 2>/dev/null || true
pkill -9 -u "$UID_NOW" -f '/dbus-run-session( |$)' 2>/dev/null || true
pkill -9 -u "$UID_NOW" -f "weston.*${SOCK}" 2>/dev/null || true
rm -f "$RT/$SOCK" "$RT/${SOCK}.lock"

killed=0
while read -r pid rest; do
	[[ -n "${pid:-}" ]] || continue
	case "$rest" in
		*--address=systemd:*)
			continue
			;;
		*at-spi*/bus_0*)
			continue
			;;
		*at-spi*)
			if kill -9 "$pid" 2>/dev/null; then
				killed=$((killed + 1))
			fi
			continue
			;;
	esac
	if [[ "$rest" == *"--print-address"* && "$rest" == *"--session"* ]]; then
		if kill -9 "$pid" 2>/dev/null; then
			killed=$((killed + 1))
		fi
	fi
done < <(pgrep -u "$UID_NOW" -a dbus-daemon 2>/dev/null || true)

echo "clear-nested-dbus: reaped ${killed} leftover dbus-daemon(s)"
