#!/bin/sh
# Ubuntu 26.04 ships St-18.typelib and not St-18.gir.
# usage: st-gir-from-typelib.sh G_IR_GENERATE DEST TYPELIB GI_TYPELIB_PATH XSLTPROC XSL
set -eu
tool=$1
dest=$2
typelib=$3
extra=$4
xsltproc=$5
xsl=$6

if [ -z "${GI_TYPELIB_PATH:-}" ]; then
	export GI_TYPELIB_PATH="$extra"
else
	export GI_TYPELIB_PATH="$extra:$GI_TYPELIB_PATH"
fi

raw=$(mktemp)
trap 'rm -f "$raw"' EXIT
"$tool" "$typelib" > "$raw"
"$xsltproc" --nonet --novalid --output "$dest" "$xsl" "$raw"
