# Overview workspace selection does not switch workspace

**Status:** ⏳ open. Clicking the workspace preview on the right side of the overview does not activate that workspace, so an application cannot then be launched on the selected workspace. The installed-session log contains the pointer events but no `Meta.Workspace.activate` RPC during the entire hand test.

## Reproduction

The failure was reproduced by hand in the installed session immediately before this report. Open Activities, click the workspace preview on the right, and observe that it does not become the active workspace.

Existing logs to inspect before adding diagnostics:

- `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`
- `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`

## Debug-code cleanup ledger

- No reproduction or product code has been added yet.

## LLM efforts

### 2026-10-12 09:39 report created

Created as a separate bug from thumbnail rendering and window dragging. No product code or reproduction code has been changed for this failure.

### 2026-10-12 09:41 installed-session logs stop before workspace activation

The server received the hand test's primary-button press and release events and the client replied to the event callbacks. Across the 09:36 test there is no `Meta.Workspace.activate` RPC. The failure is therefore before the compositor workspace switch: either the thumbnails-box click action does not emit `clicked`, or `_activateThumbnailAtPoint()` does not resolve the clicked preview.
