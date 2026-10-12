# Overview workspace selection does not switch workspace

**Status:** ⏳ open. Clicking the workspace preview on the right side of the overview does not activate that workspace, so an application cannot then be launched on the selected workspace.

## Reproduction

The failure was reproduced by hand in the installed session immediately before this report. Open Activities, click the workspace preview on the right, and observe that it does not become the active workspace.

Existing logs to inspect before adding diagnostics:

- `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`
- `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`

## LLM efforts

### 2026-10-12 09:39 report created

Created as a separate bug from thumbnail rendering and window dragging. No product code or reproduction code has been changed for this failure.
