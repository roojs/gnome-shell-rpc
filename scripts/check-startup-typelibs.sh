#!/bin/sh
# Look for the typelibs gsr-server and gsr-client load.
# Run on the machine you are about to log into, after install.
# A missing file is the "Starting GNOME Shell" hang, without a login.
#
# usage: GI_TYPELIB_PATH=dir:dir ./scripts/check-startup-typelibs.sh 18
set -eu
version=${1:?mutter api version, 16 or 18}
if [ -z "${GI_TYPELIB_PATH:-}" ]; then
	echo "GI_TYPELIB_PATH is unset" >&2
	exit 1
fi

missing=0
for name in Meta Clutter St Shell Cogl; do
	found=0
	oldifs=$IFS
	IFS=:
	for dir in $GI_TYPELIB_PATH; do
		if [ -f "$dir/$name-$version.typelib" ]; then
			found=1
			break
		fi
	done
	IFS=$oldifs
	if [ "$found" -eq 0 ]; then
		echo "$name $version: typelib not found" >&2
		missing=1
	fi
done
if [ "$missing" -ne 0 ]; then
	exit 1
fi
echo "typelibs $version ok"
