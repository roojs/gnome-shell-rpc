#!/bin/sh
# Product GIR override: xsltproc identity + snippet files. Never overwrite vala_gir.
# usage: gir-xslt-inject.sh IN OUT XSL GSTRV APPINFO
set -eu
in=$1
out=$2
xsl=$3
gstrv=$4
appinfo=$5

in_real=$(realpath "$in")
out_real=$(realpath -m "$out")
if [ "$in_real" = "$out_real" ]; then
	echo "FAIL gir-inject: refusing in-place write ($in)" >&2
	exit 1
fi

xsltproc --nonet --novalid --output "$out" \
	--stringparam gstrv "$gstrv" \
	--stringparam appinfo "$appinfo" \
	"$xsl" "$in"

if grep -q 'GLib.DesktopAppInfo' "$out"; then
	echo "FAIL gir-inject: GLib.DesktopAppInfo still in $out" >&2
	exit 1
fi
if ! grep -q 'Gio.DesktopAppInfo' "$out"; then
	echo "FAIL gir-inject: Gio.DesktopAppInfo missing from $out" >&2
	exit 1
fi
if ! grep -q 'c:identifier="shell_app_system_search"' "$out"; then
	echo "FAIL gir-inject: AppSystem.search missing from $out" >&2
	exit 1
fi
if ! grep -q 'c:type="char\*\*\*"' "$out"; then
	echo "FAIL gir-inject: nested GStrv missing from $out" >&2
	exit 1
fi
