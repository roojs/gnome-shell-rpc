#!/usr/bin/env bash
# Run gi-rpc-mock (server only) + gnome-shell-rpc client with spawn-matching env.
# gi-rpc-mock never embeds GJS — it only listens on MUTTER_RPC_SOCKET.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${GI_RPC_SMOKE_BUILD:-$ROOT/build}"
BINDIR="$BUILD/src"
OCRPC_LIBDIR="${GI_RPC_SMOKE_OCRPC_LIBDIR:-$HOME/gitlive/OLLMchat/build/libocrpc}"
GNOME_SHELL_PKGLIBDIR="${GNOME_SHELL_PKGLIBDIR:-/usr/lib/gnome-shell}"
MUTTER_TL="$(pkg-config --variable=typelibdir libmutter-16 2>/dev/null || true)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
SOCKET="${MUTTER_RPC_SOCKET:-$RUNTIME_DIR/mutter-rpc.sock}"
GI_RPC_SMOKE_SRV_PID=""

kill_mock_server() {
	if [[ -z "$GI_RPC_SMOKE_SRV_PID" ]]; then
		return 0
	fi
	if kill -0 "$GI_RPC_SMOKE_SRV_PID" 2>/dev/null; then
		kill "$GI_RPC_SMOKE_SRV_PID" 2>/dev/null || true
		wait "$GI_RPC_SMOKE_SRV_PID" 2>/dev/null || true
	fi
}

usage() {
	cat <<EOF
Usage: $(basename "$0") server
       $(basename "$0") client [SCRIPT.js] [-- extra gnome-shell-rpc args...]
       $(basename "$0") run [SCRIPT.js] [-- extra gnome-shell-rpc args...]

  server   Start gi-rpc-mock (foreground; RPC socket only).
  client   Run gnome-shell-rpc against an already-listening mock server.
  run      Start gi-rpc-mock in background, run client, kill mock when client exits.

Default client: stock init.js (full gnome-shell boot — same as gnome-shell-rpc with no SCRIPT).
Common env:
  GNOME_SHELL_JS_DIR=...        optional full JS tree boot from disk
  GI_RPC_JS_OVERRIDE_DIR=...    debug: sparse dir (e.g. src/shell-js/ui/messageList.js)
  GI_RPC_JS_VENDOR_DIR=...      vendor JS tree (default: vendor/gnome-shell/js when override set)
  GI_RPC_REGISTER_CLASS_TRACE=1   log registerClass during init.js boot
  GI_MAIN_SMOKE_MODULE=panel.js     module-only trace (register-class-trace-smoke.js)
  GI_RPC_SMOKE_BUILD=$BUILD
  GI_RPC_SMOKE_OCRPC_LIBDIR=$OCRPC_LIBDIR
  MUTTER_RPC_SOCKET=$SOCKET

When the client exits (normal, error, or crash), gi-rpc-smoke.sh kills gi-rpc-mock
if it is still running — the client may never send Meta.Context.terminate.
EOF
}

server_env() {
	export LD_LIBRARY_PATH="$GNOME_SHELL_PKGLIBDIR:${OCRPC_LIBDIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
	export MUTTER_RPC_SOCKET="$SOCKET"
}

client_env() {
	local tip="$BINDIR:$GNOME_SHELL_PKGLIBDIR"
	if [[ -n "$MUTTER_TL" ]]; then
		tip="$tip:$MUTTER_TL"
	fi
	export GI_TYPELIB_PATH="${GI_TYPELIB_PATH:+$GI_TYPELIB_PATH:}$tip"
	export LD_LIBRARY_PATH="$BINDIR:$GNOME_SHELL_PKGLIBDIR:${OCRPC_LIBDIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
	export MUTTER_RPC_SOCKET="$SOCKET"
	export GI_RPC_GJS_EMBED_DIR="$ROOT/src/gjs-embed"
	if [[ -n "${GI_RPC_JS_OVERRIDE_DIR:-}" && -z "${GI_RPC_JS_VENDOR_DIR:-}" ]]; then
		export GI_RPC_JS_VENDOR_DIR="$ROOT/vendor/gnome-shell/js"
	fi
	if [[ -n "${GI_RPC_JS_OVERRIDE_DIR:-}${GI_RPC_JS_VENDOR_DIR:-}" ]]; then
		mkdir -p "${GI_RPC_JS_VENDOR_DIR:-$ROOT/vendor/gnome-shell/js}/misc"
		ln -sf "$BUILD/src/shell-js/misc/config.js" \
			"${GI_RPC_JS_VENDOR_DIR:-$ROOT/vendor/gnome-shell/js}/misc/config.js"
	fi
}

require_bins() {
	local miss=0
	for bin in "$BINDIR/gi-rpc-mock" "$BINDIR/gnome-shell-rpc"; do
		if [[ ! -x "$bin" ]]; then
			echo "$(basename "$0"): missing $bin (meson build?)" >&2
			miss=1
		fi
	done
	if [[ ! -f "$OCRPC_LIBDIR/libocrpc.so" ]]; then
		echo "$(basename "$0"): missing $OCRPC_LIBDIR/libocrpc.so" >&2
		miss=1
	fi
	(( miss == 0 )) || exit 1
}

cmd_server() {
	require_bins
	server_env
	exec "$BINDIR/gi-rpc-mock" --debug "$@"
}

# Empty = gnome-shell-rpc default (resource:///org/gnome/shell/ui/init.js).
default_script() {
	echo ""
}

run_client() {
	client_env
	if [[ -z "$1" ]]; then
		"$BINDIR/gnome-shell-rpc" --debug "${@:2}"
	else
		"$BINDIR/gnome-shell-rpc" --debug "$@"
	fi
}

cmd_client() {
	require_bins
	local script="${1:-$(default_script)}"
	shift || true
	if [[ "${1:-}" == "--" ]]; then
		shift
	fi
	client_env
	if [[ -z "$script" ]]; then
		exec "$BINDIR/gnome-shell-rpc" --debug "$@"
	else
		exec "$BINDIR/gnome-shell-rpc" --debug "$script" "$@"
	fi
}

cmd_run() {
	require_bins
	local script="${1:-$(default_script)}"
	shift || true
	if [[ "${1:-}" == "--" ]]; then
		shift
	fi
	rm -f "$SOCKET"
	server_env
	"$BINDIR/gi-rpc-mock" --debug &
	GI_RPC_SMOKE_SRV_PID=$!
	trap kill_mock_server EXIT
	local i
	for (( i = 0; i < 50; i++ )); do
		if [[ -S "$SOCKET" ]]; then
			break
		fi
		sleep 0.1
	done
	if [[ ! -S "$SOCKET" ]]; then
		echo "$(basename "$0"): gi-rpc-mock did not create $SOCKET" >&2
		exit 1
	fi
	if [[ -z "$script" ]]; then
		run_client "" "$@"
	else
		run_client "$script" "$@"
	fi
	# Client gone (ok, error, or crash) — reap mock if terminate never reached it.
	kill_mock_server
}

main() {
	if [[ $# -lt 1 ]]; then
		usage >&2
		exit 1
	fi
	case "$1" in
		-h|--help) usage; exit 0 ;;
		server) shift; cmd_server "$@" ;;
		client) shift; cmd_client "$@" ;;
		run) shift; cmd_run "$@" ;;
		*) echo "$(basename "$0"): unknown command: $1" >&2; usage >&2; exit 1 ;;
	esac
}

main "$@"
