# Overview thumbnail cannot be dragged

**Status:** ⏳ open. In the overview, a window thumbnail is visible but cannot be dragged to another workspace. The installed-session log records `TypeError: event is null` at stock `dnd.js:151` when `addClickAction` handles `ClickAction::long-press` and calls `Clutter.get_current_event()`.

## Reproduction

The failure was reproduced by hand in the installed session immediately before this report. Open Activities, press and drag a visible window thumbnail, and attempt to drop it on another workspace. The thumbnail does not perform the expected drag-and-drop behavior.

Existing logs to inspect before adding diagnostics:

- `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`
- `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`

Focused reproduction: `tests/gjs-embed/current-event-long-press-smoke.js`.

```bash
GI_META_SMOKE=current-event-long-press-smoke GSR_WESTON_PIXMAN=1 GSR_NESTED_TIMEOUT=60 ./scripts/agent-nested-smoke-prove.sh
```

## Debug-code cleanup ledger

- `tests/gjs-embed/current-event-long-press-smoke.js` is the only code added for this investigation. It is reproduction code, not product code.
- No `src/` diagnostics have been added.

## LLM efforts

### 2026-10-12 09:39 report created

Created as a separate bug from thumbnail rendering. No product code or reproduction code has been changed for this failure.

### 2026-10-12 09:41 installed-session logs name the drag boundary

During the hand interaction, four `ClickAction::long-press` notifications called `Gsr-Clutter.get_current_event`; each reply was followed by `JS ERROR: TypeError: event is null` at `addClickAction/<@resource:///org/gnome/shell/ui/dnd.js:151`. Two occurred during press-and-move intervals. Raw pointer press, motion, and release continued on the server, but stock DND could not read the event sequence, time, or device needed to start the drag.

### 2026-10-12 09:45 simple release does not reproduce the missing event

The focused smoke created a stock draggable, attached its click action, and generated an immediate pointer click. Its long-press cancellation saw `Clutter.get_current_event()` set and printed `ok`; this refutes a general long-press signal or current-event RPC failure. The hand failure is narrower and occurs when long-press is cancelled by pointer motion while the button remains held. The run later exited `139` during teardown after the smoke had passed; this does not reproduce the hand path and is not a drag result.
