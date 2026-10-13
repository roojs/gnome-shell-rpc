# Applications picker does not work

**Status:** ⏳ open. Clicking the nine-dot Show Applications button opens an applications screen, but the screen does not provide a usable application picker. The current installed-session logs contain no `clutter_margin_copy`, `IconGridLayout.adaptToSize`, or `appDisplay.js` exception, so the older app-grid failures are not yet proved to be this hand symptom.

## Reproduction

The failure was reproduced by hand in the installed session immediately before this report. Open the overview, click the nine-dot Show Applications button at the bottom, and observe that the resulting screen does not work as an application launcher.

Existing logs to inspect before adding diagnostics:

- `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`
- `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`

## Debug-code cleanup ledger

- `tests/gjs-embed/applications-picker-smoke.js` is the clean reproduction. It clicks the real Show Applications button and observes state, display mapping, grid page size, item count, and pickable app icons without priming the grid or forcing state.
- No product code or `src/` diagnostics have been added.

## LLM efforts

### 2026-10-12 09:39 report created

Created as a separate bug from overview workspace selection and window dragging. No product code or reproduction code has been changed for this failure.

### 2026-10-12 09:41 installed-session logs do not yet name the picker failure

The current hand-test logs were searched for the previously observed `clutter_margin_copy` symbol failure, `IconGridLayout.adaptToSize` allocation failure, and `appDisplay.js` errors; none occurred. The session did contain four `dnd.js` current-event errors and a later unrelated shutdown error after the server socket closed. A clean picker reproduction must identify whether the button changes the overview state, whether the app display maps, and whether icons are pickable without the workarounds in `picker-second-launch.js`.
