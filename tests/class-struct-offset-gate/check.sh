#!/bin/sh
# GType class_size must match the typelib class_struct GJS uses for vfunc_*.
set -eu
bindir=$1
mutter_tl=$2
js=$3
ocrpc_libdir=${4:-}

export GI_TYPELIB_PATH="$bindir:$mutter_tl${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
ld="$bindir"
if [ -n "$ocrpc_libdir" ]; then
	ld="$bindir:$ocrpc_libdir"
fi
export LD_LIBRARY_PATH="$ld${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec gjs -m "$js"
