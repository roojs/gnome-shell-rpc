#!/bin/sh
# GIR from scanner must be nested utf8 (not gpointer), then GJS must marshal it.
set -eu
gir=$1
libdir=$2
js=$3

search_xml=$(awk '/name="search"/,/<\/function>/' "$gir")
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
if ! printf '%s\n' "$search_xml" | grep -q 'c:identifier="gsr_search_app_system_search"'; then
	echo "FAIL gstrv-gir-gate: search not on AppSystem" >&2
	printf '%s\n' "$search_xml" >&2
	exit 1
fi

export GI_TYPELIB_PATH="$libdir${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
export LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
gjs -m "$js"
