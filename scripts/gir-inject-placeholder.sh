#!/bin/sh
# Swap valac's dummy gsr_placeholder_nested_gstrv for a snippet file.
# Writes a *new* GIR (ninja stamps). Never overwrite the vala_gir output.
set -eu
in=$1
snippet=$2
out=$3
marker=gsr_placeholder_nested_gstrv

in_real=$(realpath "$in")
out_real=$(realpath -m "$out")
if [ "$in_real" = "$out_real" ]; then
	echo "FAIL gir-inject: refusing in-place write ($in)" >&2
	exit 1
fi

if ! grep -q "name=\"$marker\"" "$in"; then
	echo "FAIL gir-inject: marker $marker not in $in" >&2
	exit 1
fi

ident=$(grep -o 'c:identifier="[^"]*"' "$snippet" | head -n1)
if [ -z "$ident" ]; then
	echo "FAIL gir-inject: no c:identifier in $snippet" >&2
	exit 1
fi

tmp=$out.tmp
awk -v snippet_file="$snippet" -v marker="$marker" '
	BEGIN {
		while ((getline line < snippet_file) > 0) {
			snippet = snippet line "\n"
		}
		close(snippet_file)
	}
	$0 ~ "name=\"" marker "\"" {
		skip = 1
		next
	}
	skip && /<\/function>/ {
		skip = 0
		printf "%s", snippet
		next
	}
	skip { next }
	{ print }
' "$in" > "$tmp"

if grep -q "name=\"$marker\"" "$tmp"; then
	echo "FAIL gir-inject: marker still present after replace" >&2
	exit 1
fi
if ! grep -q "$ident" "$tmp"; then
	echo "FAIL gir-inject: snippet $ident not in output" >&2
	exit 1
fi
mv "$tmp" "$out"
