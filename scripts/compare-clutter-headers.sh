#!/bin/sh
# Scoreboard: generated Clutter headers vs stock mutter-16.
# Usage: scripts/compare-clutter-headers.sh [stock-dir] [ours-dir] [st-dir]
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
STOCK=${1:-/usr/include/mutter-16/clutter/clutter}
OURS=${2:-"$ROOT/build/src/clutter-include/clutter"}
ST=${3:-"$ROOT/vendor/gnome-shell/src/st"}

die() { echo "error: $*" >&2; exit 1; }
[ -d "$STOCK" ] || die "stock dir missing: $STOCK"
[ -d "$OURS" ] || die "ours dir missing: $OURS (build headers first)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Concatenate public-ish headers (skip *-private.h noise in ours).
cat_stock() { find "$STOCK" -name '*.h' -print0 | sort -z | xargs -0 cat; }
cat_ours() {
	find "$OURS" -name '*.h' ! -name '*-private.h' -print0 |
		sort -z | xargs -0 cat
}

# Method / free-function names: clutter_foo (
extract_names() {
	grep -Eo '\bclutter_[a-z0-9_]+\s*\(' | sed 's/[[:space:]]*(//' | sort -u
}

# Rough sig key: name|argtypes (whitespace collapsed, * glued).
extract_sigs() {
	# shellcheck disable=SC2016
	grep -E '^\s*(static\s+inline\s+)?[A-Za-z_].*\bclutter_[a-z0-9_]+\s*\(' |
		grep -v '^\s*\*' |
		sed -E \
			-e 's|/\*[^*]*\*+/||g' \
			-e 's|[[:space:]]+| |g' \
			-e 's|^ ||' \
			-e 's| \*|\*|g' \
			-e 's|\* |\*|g' \
			-e 's| ,|,|g' \
			-e 's|\( |\(|g' \
			-e 's| \)|)|g' |
		sed -En 's/.*\b(clutter_[a-z0-9_]+) *\(([^)]*)\).*/\1|\2/p' |
		sort -u
}

# Class/iface vfunc field names: (* name)
extract_vfunc_names() {
	grep -Eo '\(\s*\*\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\)' |
		sed -E 's/\(\s*\*\s*//;s/\s*\)//' | sort -u
}

# vfunc sig: name|args
extract_vfunc_sigs() {
	grep -E '\(\s*\*\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\)' |
		sed -E \
			-e 's|[[:space:]]+| |g' \
			-e 's| \*|\*|g' \
			-e 's|\* |\*|g' \
			-e 's| ,|,|g' |
		sed -En 's/.*\(\s*\*\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\) *\(([^)]*)\).*/\1|\2/p' |
		sort -u
}

# Public macros CLUTTER_*
extract_macros() {
	grep -E '^\s*#\s*define\s+CLUTTER_[A-Z0-9_]+' |
		sed -E 's/.*#\s*define\s+(CLUTTER_[A-Z0-9_]+).*/\1/' | sort -u
}

score() {
	label=$1
	stock_list=$2
	ours_list=$3
	n_stock=$(wc -l <"$stock_list" | tr -d ' ')
	n_ours=$(wc -l <"$ours_list" | tr -d ' ')
	n_both=$(comm -12 "$stock_list" "$ours_list" | wc -l | tr -d ' ')
	if [ "$n_stock" -eq 0 ]; then
		pct='—'
	else
		pct=$((100 * n_both / n_stock))
	fi
	printf '%-22s  stock=%4s  match=%4s  %3s%%\n' "$label" "$n_stock" "$n_both" "$pct"
	missing="$tmpdir/missing-$label"
	comm -23 "$stock_list" "$ours_list" >"$missing"
	n_miss=$(wc -l <"$missing" | tr -d ' ')
	if [ "$n_miss" -gt 0 ] && [ "$n_miss" -le 20 ]; then
		echo "  missing: $(tr '\n' ' ' <"$missing")"
	elif [ "$n_miss" -gt 20 ]; then
		echo "  missing: $n_miss (first 15: $(head -15 "$missing" | tr '\n' ' '))"
	fi
}

cat_stock >"$tmpdir/stock.h"
cat_ours >"$tmpdir/ours.h"

extract_names <"$tmpdir/stock.h" >"$tmpdir/stock.names"
extract_names <"$tmpdir/ours.h" >"$tmpdir/ours.names"
extract_sigs <"$tmpdir/stock.h" >"$tmpdir/stock.sigs"
extract_sigs <"$tmpdir/ours.h" >"$tmpdir/ours.sigs"
extract_vfunc_names <"$tmpdir/stock.h" >"$tmpdir/stock.vnames"
extract_vfunc_names <"$tmpdir/ours.h" >"$tmpdir/ours.vnames"
extract_vfunc_sigs <"$tmpdir/stock.h" >"$tmpdir/stock.vsigs"
extract_vfunc_sigs <"$tmpdir/ours.h" >"$tmpdir/ours.vsigs"
extract_macros <"$tmpdir/stock.h" >"$tmpdir/stock.macros"
extract_macros <"$tmpdir/ours.h" >"$tmpdir/ours.macros"

echo "stock: $STOCK"
echo "ours:  $OURS"
echo
score "method names" "$tmpdir/stock.names" "$tmpdir/ours.names"
score "method sigs" "$tmpdir/stock.sigs" "$tmpdir/ours.sigs"
score "vfunc names" "$tmpdir/stock.vnames" "$tmpdir/ours.vnames"
score "vfunc sigs" "$tmpdir/stock.vsigs" "$tmpdir/ours.vsigs"
score "macros" "$tmpdir/stock.macros" "$tmpdir/ours.macros"

# St-used refs declared in ours
if [ -d "$ST" ]; then
	{
		grep -RhoE '\bclutter_[a-z0-9_]+\b' "$ST" || true
		grep -RhoE '\bCLUTTER_[A-Z0-9_]+\b' "$ST" || true
	} | sort -u >"$tmpdir/st.refs"
	# Declared = names + macros in ours
	cat "$tmpdir/ours.names" "$tmpdir/ours.macros" | sort -u >"$tmpdir/ours.syms"
	score "St-used refs" "$tmpdir/st.refs" "$tmpdir/ours.syms"
else
	echo "St-used refs         (skip: no $ST)"
fi
