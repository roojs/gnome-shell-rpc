#!/usr/bin/env bash
# g-ir-compiler wrapper: St/Shell client GIRs need mutter + Meta RPC + Gvc include dirs.
set -euo pipefail
MUTTER_GIR_DIR="@MUTTER_GIR_DIR@"
META_GIR_DIR="@META_GIR_DIR@"
GVC_GIR_DIR="@GVC_GIR_DIR@"
exec "@G_IR_COMPILER@" \
  --includedir="${MUTTER_GIR_DIR}" \
  --includedir="${META_GIR_DIR}" \
  --includedir="${GVC_GIR_DIR}" \
  "$@"
