# Overview thumbnail cannot be dragged

**Status:** ⏳ open. In the overview, a window thumbnail is visible but cannot be dragged to another workspace or another valid overview drop target.

## Reproduction

The failure was reproduced by hand in the installed session immediately before this report. Open Activities, press and drag a visible window thumbnail, and attempt to drop it on another workspace. The thumbnail does not perform the expected drag-and-drop behavior.

Existing logs to inspect before adding diagnostics:

- `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`
- `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`

## LLM efforts

### 2026-10-12 09:39 report created

Created as a separate bug from thumbnail rendering. No product code or reproduction code has been changed for this failure.
