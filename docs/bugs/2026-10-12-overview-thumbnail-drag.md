# Overview thumbnail drag and click

**Status:** ⏳ open. Clicking an overview window thumbnail starts a drag. The thumbnail stays at drag opacity 100 and the overview stays up. `clicked` is on the blocking list with `long-press`. The Weston abort is the allocate that returned a preferred height of -12, not a reason to drop `clicked`.

Weston `overview-window-activate-smoke` at 15:13: `selected=true overview=true inDrag=true` and the preview `opacity=100`. Stock `dnd.js` queues a `BEFORE_REDRAW` later from `ClickAction::long-press` CANCEL, then relies on the `clicked` handler to set `_actionClicked` before that later runs. The later ran while `clicked` was still inside `Meta.Workspace.index` (`ClickAction.release` at 15:13:56.957839, after `clicked` at 15:13:56.957136). Drag opacity 100 is `DRAGGING_WINDOW_OPACITY`.

The Ubuntu VM (`alan@192.168.88.197`) did not answer (`No route to host`). The earlier hand drag still has `TypeError: event is null` at `dnd.js:151` when long-press CANCEL cannot read `Clutter.get_current_event()` during press-and-move. That path is not what this click reproduced.

## Reproduction

Hand: open Activities with more than one window. Click a thumbnail to go to that application. The window that appears is slightly ghosted. Press and drag a thumbnail toward another workspace. It does not drop there.

Click gate:

```bash
GI_META_SMOKE=overview-window-activate-smoke \
  GI_META_SMOKE_CMD='gedit --new-window' \
  GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
  GSR_NESTED_TIMEOUT=90 \
  ./scripts/agent-nested-smoke-prove.sh
```

Drag gate that does not match the hand path (immediate click, current event is set):

```bash
GI_META_SMOKE=current-event-long-press-smoke \
  GSR_WESTON_PIXMAN=1 GSR_NESTED_TIMEOUT=60 \
  ./scripts/agent-nested-smoke-prove.sh
```

## Debug-code cleanup ledger

- `tests/gjs-embed/current-event-long-press-smoke.js` — drag current-event check. Immediate click only.
- `tests/gjs-embed/overview-window-activate-smoke.js` — click a real window thumbnail.
- `Gsr-Clutter-Actor.pointer_click` stamps the press and release with `CLUTTER_CURRENT_TIME` (0). Literal 1µs and 2µs are already in the past, so the button never reached the thumbnail. That change is in the tree. The later-deferral change is not.

## LLM efforts

### 2026-10-12 09:39 report created

Created as a separate bug from thumbnail rendering. No product code or reproduction code has been changed for this failure.

### 2026-10-12 09:41 installed-session logs name the drag boundary

During the hand interaction, four `ClickAction::long-press` notifications called `Gsr-Clutter.get_current_event`; each reply was followed by `JS ERROR: TypeError: event is null` at `addClickAction/<@resource:///org/gnome/shell/ui/dnd.js:151`. Two occurred during press-and-move intervals. Raw pointer press, motion, and release continued on the server, but stock DND could not read the event sequence, time, or device needed to start the drag.

### 2026-10-12 09:45 simple release does not reproduce the missing event

The focused smoke created a stock draggable, attached its click action, and generated an immediate pointer click. Its long-press cancellation saw `Clutter.get_current_event()` set and printed `ok`; this refutes a general long-press signal or current-event RPC failure. The hand failure is narrower and occurs when long-press is cancelled by pointer motion while the button remains held. The run later exited `139` during teardown after the smoke had passed; this does not reproduce the hand path and is not a drag result.

### 2026-10-12 15:05 click-to-activate merged in; VM log unavailable

Hand report: clicking the terminal thumbnail in the overview, with terminal, files, and help open, leaves a slightly ghosted window. Same thumbnail is what does not drag between workspaces, so both stay in this bug. `ssh alan@192.168.88.197` returned `No route to host`. `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` (14:50, 2.7MB) has no `dnd.js`, `event is null`, or window-preview activation line. Added `tests/gjs-embed/overview-window-activate-smoke.js` to click a launched window's thumbnail and record overview visibility, focus, actor opacity, and scale.

### 2026-10-12 15:13 click starts a drag; later-deferral reverted

First click missed the thumbnail: `pointer_click` used button times 1µs and 2µs. Motion at time 0 is `CLUTTER_CURRENT_TIME` and is restamped to now, so the pointer entered the preview and the press never landed. Press and release now also use 0.

Second run, `overview-window-activate-smoke: miss Error: miss overview-stayed`. Log line: `after selected=true overview=true focus="Untitled Document 1 - gedit" inDrag=true actor opacity=255 scale=1,1 800x568 unmapped visible preview opacity=100`. Client log: `long-press`, `Gsr-Clutter.get_current_event` id=15951, then `clicked`, then `Clutter-ClickAction.release` while `Meta-Workspace.index` was still in flight. `clicked` is connected to `_activate` before `addClickAction` sets `_actionClicked`. The before-redraw later ran in that gap and called `startDrag`. A depth counter on `Shell.Signals.emit` plus a deferral in `Meta.Laters` was compiled and then removed. It is not the change to land without a decision.

### 2026-10-12 15:20 deferred-later build hung

That build was already running when the deferral was removed from the source. `nested-weston-prove: stop (timeout) after 90s`, exit 137. The click at 15:20:02 did not return before the kill. The line flushed on the way out was `selected=true overview=true focus="(none)" inDrag=false actor opacity=0 scale=1,1 -1x-1`. The drag flag stayed clear. The overview did not hide, and the smoke never printed `ok` or `miss`.

### 2026-10-12 15:21 `clicked` added to the blocking list

`long-press` was already blocking. `clicked` was not, and the before-redraw later ran while that handler was still in `Meta.Workspace.index`. `clicked` is now in the `add_signals` switch next to `long-press`. `before-update` stays off the list.

### 2026-10-12 15:25 Weston abort; `clicked` removed

User ran Weston. `gsr-client` pid 1124015 SIGILL at 15:24:59. Restarted client 1124440. `gsr-server` pid 1123982 SIGTRAP at 15:25:09 in `g_log` from `clutter_actor_allocate`, while `oll_mrpc_live_hook_emit` was in `emit_wait_poll`. Mutter log: `ClutterBoxLayout child unnamed [GsrServerClutterActor] minimum height: -12.000000 < 0 for width 182.000000`. The blocking name `clicked` also covers `St.Button`. That handler allocates during the wait. `clicked` is off the list again. Server rebuilt without it.

### 2026-10-12 15:56 `clicked` put back

Unblocking `clicked` was the wrong response. It stays on the list. The abort is the allocate relay returning `min=-12` for an `StWidget` inside a `BoxPointer` while that click was still waiting. That height is the allocation bug.
