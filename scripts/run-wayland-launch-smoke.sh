#!/usr/bin/env bash
# Agent prove for wayland-launch-smoke (auto-closes Weston). Manual nest: use
# GI_META_SMOKE=wayland-launch-smoke ./scripts/weston-gsr-session.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec env GI_META_SMOKE=wayland-launch-smoke "$ROOT/scripts/agent-nested-smoke-prove.sh"
