#!/bin/sh
# Injected GIR must be nested utf8 (not gpointer / placeholder), then GJS marshals.
set -eu
gir=$1
libdir=$2
js=$3

orig=$libdir/GsrSearch-1.0.gir
if [ ! -f "$orig" ]; then
	echo "FAIL gstrv-gir-gate: vala_gir $orig missing (must keep original)" >&2
	exit 1
fi
if ! grep -q 'gsr_placeholder_nested_gstrv' "$orig"; then
	echo "FAIL gstrv-gir-gate: original GIR lost placeholder (in-place inject?)" >&2
	exit 1
fi
if grep -q 'c:identifier="gsr_search_app_system_search"' "$orig"; then
	echo "FAIL gstrv-gir-gate: original GIR already has search" >&2
	exit 1
fi

if grep -q 'gsr_placeholder_nested_gstrv' "$gir"; then
	echo "FAIL gstrv-gir-gate: placeholder still in injected GIR" >&2
	exit 1
fi
if ! grep -q 'name="ping"' "$gir"; then
	echo "FAIL gstrv-gir-gate: Vala ping missing after inject" >&2
	exit 1
fi

search_xml=$(awk '/c:identifier="gsr_search_app_system_search"/,/<\/function>/' "$gir")
if printf '%s\n' "$search_xml" | grep -q 'name="gpointer"'; then
	echo "FAIL gstrv-gir-gate: GIR search inner type is gpointer" >&2
	printf '%s\n' "$search_xml" >&2
	exit 1
fi
if ! printf '%s\n' "$search_xml" | grep -q 'name="utf8"'; then
	echo "FAIL gstrv-gir-gate: GIR search missing nested utf8" >&2
	printf '%s\n' "$search_xml" >&2
	exit 1
fi
if ! printf '%s\n' "$search_xml" | grep -q 'char\*\*\*'; then
	echo "FAIL gstrv-gir-gate: GIR search missing char***" >&2
	printf '%s\n' "$search_xml" >&2
	exit 1
fi

export GI_TYPELIB_PATH="$libdir${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
export LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
gjs -m "$js"
