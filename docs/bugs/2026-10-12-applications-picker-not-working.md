# Applications picker does not work

**Status:** ⏳ open. Clicking the nine-dot Show Applications button opens an applications screen, but the screen does not provide a usable application picker.

## Reproduction

The failure was reproduced by hand in the installed session immediately before this report. Open the overview, click the nine-dot Show Applications button at the bottom, and observe that the resulting screen does not work as an application launcher.

Existing logs to inspect before adding diagnostics:

- `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`
- `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`

## LLM efforts

### 2026-10-12 09:39 report created

Created as a separate bug from overview workspace selection and window dragging. No product code or reproduction code has been changed for this failure.
