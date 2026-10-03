#!/usr/bin/env bash
# Generate debian/changelog and splice the RPM %changelog from CHANGELOG.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$ROOT/scripts/release/changelog.sh" sync \
  --splice-spec "$ROOT/packaging/rpm/gnome-shell-rpc.spec" \
  "$@"
