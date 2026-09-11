#!/usr/bin/env bash
# Clone or update vendor/gnome-shell/ (upstream GNOME Shell sources).
# See gnome-shell/README.md and docs/plans/README.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT/vendor/gnome-shell"
UPSTREAM="${GNOME_SHELL_VENDOR_UPSTREAM:-https://gitlab.gnome.org/GNOME/gnome-shell.git}"

REF="${GNOME_SHELL_VENDOR_REF:-48.0}"
REFRESH="${GNOME_SHELL_VENDOR_REFRESH:-0}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--refresh] [--ref=REF]

  REF     48.0 (default), head/main, tag, branch, or commit SHA
  --refresh   force fetch + checkout REF
              (also auto-checkouts when HEAD is not already REF)

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

  git -C "$VENDOR_DIR" fetch origin --tags

  if [[ "$ref" == "main" ]]; then
    git -C "$VENDOR_DIR" checkout -B main origin/main
    git -C "$VENDOR_DIR" pull --ff-only origin main || true
  else
    # Tags/commits: ensure object exists after fetch, then detach or checkout tag.
    if ! git -C "$VENDOR_DIR" rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
      echo "scripts/gnome-shell-fetch.sh: unknown ref '${ref}' after fetch" >&2
      exit 1
    fi
    git -C "$VENDOR_DIR" checkout --detach "${ref}^{commit}"
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
    # Shallow clone of a tag often fails; full clone then checkout.
    git clone "$UPSTREAM" "$VENDOR_DIR"
    checkout_ref "$ref"
  fi
}

at_ref() {
  local ref="$1"
  local wanted current
  if [[ "$ref" == "head" || "$ref" == "" ]]; then
    ref="main"
  fi
  wanted="$(git -C "$VENDOR_DIR" rev-parse "${ref}^{commit}" 2>/dev/null || true)"
  current="$(git -C "$VENDOR_DIR" rev-parse HEAD)"
  [[ -n "$wanted" && "$wanted" == "$current" ]]
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

# Existing tree: switch if HEAD is not already REF (so --ref=48.0 works without
# requiring --refresh after a previous head checkout).
git -C "$VENDOR_DIR" fetch origin --tags --quiet 2>/dev/null \
  || git -C "$VENDOR_DIR" fetch origin --tags

if at_ref "$REF"; then
  log_sha
  exit 0
fi

echo "scripts/gnome-shell-fetch.sh: HEAD is not ${REF}; checking out ..."
checkout_ref "$REF"
log_sha
