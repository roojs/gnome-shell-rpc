#!/usr/bin/env bash
# Vendor JS tree on disk so GNOME_SHELL_JS_DIR can override individual files (no rebuild).
# Edit files under the output dir (e.g. ui/messageList.js), then rerun gi-rpc-smoke.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_JS="${VENDOR_JS:-$ROOT/vendor/gnome-shell/js}"
OUT="${1:-$ROOT/js-override}"

if [[ ! -d "$VENDOR_JS/ui" ]]; then
	echo "$(basename "$0"): missing vendor JS at $VENDOR_JS" >&2
	exit 1
fi

BUILD_CONFIG="$ROOT/build/src/shell-js/misc/config.js"
if [[ ! -f "$BUILD_CONFIG" ]]; then
	echo "$(basename "$0"): missing $BUILD_CONFIG (run meson build first)" >&2
	exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
cp -a "$VENDOR_JS/." "$OUT/"
cp "$BUILD_CONFIG" "$OUT/misc/config.js"

# Optional repo copies win (drop edited files in src/shell-js/ mirroring vendor paths).
if [[ -d "$ROOT/src/shell-js" ]]; then
	while IFS= read -r -d '' src; do
		rel="${src#"$ROOT/src/shell-js/"}"
		cp "$src" "$OUT/$rel"
	done < <(find "$ROOT/src/shell-js" -type f ! -name '*.exit.js' -print0)
fi

echo "$OUT"
echo "export GNOME_SHELL_JS_DIR=$OUT" >&2
echo "./scripts/gi-rpc-smoke.sh run" >&2
