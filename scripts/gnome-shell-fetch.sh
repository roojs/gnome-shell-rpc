#!/usr/bin/env bash
# Clone or update vendor/gnome-shell/ (upstream GNOME Shell sources).
# See gnome-shell/README.md and docs/plans/0.7-gnome-shell-rpc-client.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT/vendor/gnome-shell"
UPSTREAM="${GNOME_SHELL_VENDOR_UPSTREAM:-https://gitlab.gnome.org/GNOME/gnome-shell.git}"

REF="${GNOME_SHELL_VENDOR_REF:-head}"
REFRESH="${GNOME_SHELL_VENDOR_REFRESH:-0}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--refresh] [--ref=REF]

  REF     head (default), branch name, tag, or commit SHA
  --refresh   git fetch and checkout REF (default: use existing tree if present)

Environment (used by meson configure):
  GNOME_SHELL_VENDOR_REF       same as --ref
  GNOME_SHELL_VENDOR_REFRESH   1 to refresh
  GNOME_SHELL_VENDOR_UPSTREAM  override clone URL
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --refresh) REFRESH=1; shift ;;
    --ref=*) REF="${1#*=}"; shift ;;
    --ref)
      REF="${2:?missing ref argument}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "scripts/gnome-shell-fetch.sh: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

log_sha() {
  local sha short subject
  sha="$(git -C "$VENDOR_DIR" rev-parse HEAD)"
  short="$(git -C "$VENDOR_DIR" rev-parse --short HEAD)"
  subject="$(git -C "$VENDOR_DIR" log -1 --format=%s)"
  echo "gnome-shell vendor at ${short} (${sha})"
  echo "  ${subject}"
}

checkout_ref() {
  local ref="$1"
  if [[ "$ref" == "head" || "$ref" == "" ]]; then
    ref="main"
  fi

  git -C "$VENDOR_DIR" fetch origin

  if [[ "$ref" == "main" ]]; then
    git -C "$VENDOR_DIR" checkout -B main origin/main
    git -C "$VENDOR_DIR" pull --ff-only origin main || true
  else
    git -C "$VENDOR_DIR" checkout "$ref"
  fi
}

clone_at_ref() {
  local ref="$1"
  local branch="main"

  if [[ "$ref" != "head" && "$ref" != "" && "$ref" != "main" ]]; then
    branch="$ref"
  fi

  mkdir -p "$(dirname "$VENDOR_DIR")"
  if git clone --depth 1 --branch "$branch" "$UPSTREAM" "$VENDOR_DIR" 2>/dev/null; then
    :
  elif [[ "$branch" == "main" ]]; then
    git clone --depth 1 "$UPSTREAM" "$VENDOR_DIR"
    checkout_ref main
  else
    git clone "$UPSTREAM" "$VENDOR_DIR"
    checkout_ref "$ref"
  fi
}

if [[ ! -d "$VENDOR_DIR/.git" ]]; then
  echo "scripts/gnome-shell-fetch.sh: cloning ${UPSTREAM} (ref=${REF}) ..."
  clone_at_ref "$REF"
  log_sha
  exit 0
fi

if [[ "$REFRESH" == "1" ]]; then
  echo "scripts/gnome-shell-fetch.sh: refreshing (ref=${REF}) ..."
  checkout_ref "$REF"
  log_sha
  exit 0
fi

log_sha
