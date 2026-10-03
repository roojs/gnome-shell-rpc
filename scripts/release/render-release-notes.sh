#!/usr/bin/env bash
# Write GitHub release notes from CHANGELOG.md. The .deb and .rpm files
# live on the matching v*-packages release.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <tag> [output-file]" >&2
  exit 1
fi

TAG="$1"
OUTPUT="${2:-$ROOT/release-notes.md}"
"$ROOT/scripts/release/changelog.sh" release-notes "$TAG" -o "$OUTPUT"

repo="${GITHUB_REPOSITORY:-roojs/gnome-shell-rpc}"
tmp="$(mktemp)"
{
  echo "Debian (\`.deb\`) and RPM (\`.rpm\`) files for this version are on [${TAG}-packages](https://github.com/${repo}/releases/tag/${TAG}-packages)."
  echo
  echo "---"
  echo
  cat "$OUTPUT"
} > "$tmp"
mv "$tmp" "$OUTPUT"
