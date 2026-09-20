#!/bin/sh
# Product Shell typelib facts for overview app search (no Weston).
set -eu
bindir=$1
mutter_tl=$2
injected=$3
vala_gir=$4
js=$5
ocrpc_libdir=${6:-}

if [ ! -f "$injected" ]; then
	echo "FAIL H-appinfo-gir: injected GIR missing ($injected)" >&2
	exit 1
fi
if [ ! -f "$vala_gir" ]; then
	echo "FAIL H-appinfo-gir: vala_gir missing ($vala_gir)" >&2
	exit 1
fi

if grep -q 'GLib.DesktopAppInfo' "$injected"; then
	echo "FAIL H-appinfo-gir: GLib.DesktopAppInfo still in $injected" >&2
	exit 1
fi
if ! grep -q 'Gio.DesktopAppInfo' "$injected"; then
	echo "FAIL H-appinfo-gir: Gio.DesktopAppInfo missing from $injected" >&2
	exit 1
fi
if ! grep -q 'c:identifier="shell_app_system_search"' "$injected"; then
	echo "FAIL H-search: AppSystem.search missing from $injected" >&2
	exit 1
fi
if ! grep -q 'c:type="char\*\*\*"' "$injected"; then
	echo "FAIL H-search: nested GStrv missing from $injected" >&2
	exit 1
fi
echo "H-appinfo-gir: ok Gio.DesktopAppInfo (vala_gir kept for ninja)"

export GI_TYPELIB_PATH="$bindir:$mutter_tl${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
ld="$bindir"
if [ -n "$ocrpc_libdir" ]; then
	ld="$bindir:$ocrpc_libdir"
fi
export LD_LIBRARY_PATH="$ld${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec gjs -m "$js"
