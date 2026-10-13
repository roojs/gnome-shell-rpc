# Overview thumbnail drag and click

**Status:** ⏳ open. The click failure is reproduced and its call ordering is identified. No product fix is proposed or present in `src/`.

## Problem

🔷 Expected: clicking a window preview selects that window, leaves the overview, and does not start a drag.

🔷 Actual: selection succeeds, the overview closes, and the correct window gains focus, but the same click also starts the preview's drag path. The selected window is left looking ghosted because the preview has opacity `100`, the stock `DRAGGING_WINDOW_OPACITY`, and `_draggable._dragInProgress` remains true.

This is not a failure to activate the selected window. The failure is that the long-press cancellation callback runs in the middle of the click signal, before the click handler that suppresses that callback has run.

## Evidence

✔️ `overview-window-activate-smoke` reproduced the failure on Weston at 09:15:05 on 2026-10-13:

```text
overview-window-activate-smoke: previews=1 ... matched=true
overview-window-activate-smoke: click 399.28125,273.21484375 ...
overview-window-activate-smoke: after selected=true overview=false
  focus="Untitled Document 1 - gedit"
  inDrag=true
  actor opacity=255 ...
  preview opacity=100 scale=0.544...
overview-window-activate-smoke: miss Error: miss drag-on-click
```

The proof stopped as `smoke-fail` after 14 seconds. The complete RPC trace is in `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`, around lines 40329661–40329730.

✔️ The relevant wire order is:

```text
09:15:05.729344 notification method=long-press
09:15:05.729400 id=19820 method=Gsr-Clutter.get_current_event
09:15:05.731106 id=19824 method=Clutter-Stage.schedule_update
09:15:05.732155 notification method=clicked
09:15:05.732228 id=19827 method=Meta-Workspace.index
09:15:05.732771 replied id=19827
09:15:05.733331 notification method=before-update
09:15:05.733367 id=19830 method=Clutter-ClickAction.release
...
09:15:06.062354 id=20464 method=Meta-Window.activate
```

`Meta-Workspace.index` has replied before `before-update`; the important point is that the first `clicked` handler has not returned. It continues through the activation RPC path until `Meta-Window.activate`, while incoming notifications are dispatched during those synchronous calls.

## Call trace

1. `WindowPreview` constructs one `Clutter.ClickAction`. It first connects its own `clicked` handler to `_activate()`, then passes the action to `DND._Draggable.addClickAction()`. The DND `clicked` handler that sets `_actionClicked = true` is therefore second in signal order (`windowPreview.js:116–124`, `dnd.js:144–146`).

2. For an ordinary click, Clutter cancels the possible long press before emitting `clicked`. The DND `long-press` handler receives `CANCEL`, calls `Clutter.get_current_event()`, and queues a `Meta.LaterType.BEFORE_REDRAW` callback. `Meta.Laters.add()` subscribes to `before-update` and calls `Clutter.Stage.schedule_update()` (`dnd.js:146–174`).

3. The server emits `clicked`. Client `Signals.emit()` starts the handlers in connection order. The first handler is `WindowPreview._activate()`, which emits `selected` with `global.get_current_time()` (`windowPreview.js:554–556`).

4. `Workspace._onCloneSelected()` receives `selected`, calls `Meta.Workspace.index()`, and calls `Main.activateWindow()` (`workspace.js:1397–1404`). `Main.activateWindow()` calls `Meta.Window.activate()`, then `overview.hide()` and `panel.closeCalendar()` (`main.js:848–865`). These proxy operations are synchronous RPC calls.

5. Before that first `clicked` handler returns, the client receives `before-update` while processing the nested RPC traffic. The `Meta.Laters.run_before_redraw()` callback immediately drains the queued BEFORE_REDRAW later.

6. Stock DND expects all `clicked` handlers to have run before the later. They have not: the second `clicked` handler has not yet set `_actionClicked`. The callback therefore takes the non-click branch, calls `Clutter.ClickAction.release()`, obtains the coordinates, and calls `startDrag()` (`dnd.js:159–170`).

7. The activation path still finishes, so the correct window is focused and the overview hides. The DND callback has nevertheless left the preview in drag state and changed its opacity to `100`.

## Root cause

✔️ Stock gnome-shell relies on a same-process ordering guarantee: the `BEFORE_REDRAW` later queued by long-press cancellation cannot run until the current `clicked` signal emission has completed. Its `_actionClicked` guard is correct under that guarantee.

🔷 The RPC client breaks that ordering. A blocking `clicked` notification is dispatched synchronously by `src/client/libshell-16/Signals.vala`, but RPC calls made by its first JavaScript handler can deliver another signal notification. Here that notification is `before-update`. `src/client/libmutter-rpc-16/overrides/Laters.override.vala` immediately drains BEFORE_REDRAW callbacks when it receives `before-update`, even though the outer `clicked` emission is still active. The later overtakes the remaining `clicked` handler.

✔️ `clicked` and `long-press` are already blocking subscriptions in `src/server/libmutter-clutter-16/ClutterActor.vala`. Making `clicked` blocking is therefore not a fix. Blocking keeps the server waiting for the callback reply; it does not prevent the client from dispatching `before-update` during a nested RPC call.

✔️ `Connection.emit_wait_poll()` drains requests while waiting for a blocking callback but does not run `MainContext.iteration()`. The evidence does not support server main-loop pumping as the immediate cause.

## Reproduction

Automated click proof:

```bash
GI_META_SMOKE=overview-window-activate-smoke \
  GI_META_SMOKE_CMD='gedit --new-window' \
  GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
  GSR_NESTED_TIMEOUT=90 \
  ./scripts/agent-nested-smoke-prove.sh
```

The smoke passes window selection, focus, and overview-close checks, then prints `miss drag-on-click` when `_dragInProgress` is true or the preview opacity is `100`.

Hand: open Activities with more than one window, then click a window preview. The correct window appears but looks slightly ghosted.

## Separate unresolved drag path

The earlier hand test of pressing and moving a preview did not reach the call ordering above. It failed at `dnd.js:151` with:

```text
TypeError: event is null
```

In that path, `Clutter.get_current_event()` was null during long-press cancellation, so DND could not read the event sequence used to start a drag. The current-event smoke below uses an immediate click, sees a current event, and passes. It therefore does not reproduce or explain the press-and-move failure:

```bash
GI_META_SMOKE=current-event-long-press-smoke \
  GSR_WESTON_PIXMAN=1 GSR_NESTED_TIMEOUT=60 \
  ./scripts/agent-nested-smoke-prove.sh
```

The two symptoms share the window-preview input path, but only the click-causes-drag path has been isolated.

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

### 2026-10-13 09:15 clean reproduction and narrower deferral

The rebuilt smoke first aborted on the unrelated Quick Settings `add_child`/`hide` gap because `gsr-smoke` starts `main.js` without the normal shell startup lock. The smoke now loads `panelMenu.js` after the module graph is initialized and hides a menu actor before delegating to stock `setMenu`; this is reproduction-only.

With that race isolated, `overview-window-activate-smoke` completed the click and reported `miss drag-on-click`. The selected-window checks had already passed. The client log then called `Meta.Context.terminate_with_error` with that exact failure.

The existing blocking `clicked` subscription is insufficient by itself. `Shell.Signals.emit` is still active when a nested RPC reply delivers `before-update`; `Meta.Laters.run_before_redraw` immediately dispatches the long-press CANCEL later. A normal `before-update` is itself one signal emission deep, which may explain why the earlier unconditional signal-depth deferral never completed.

A signal-depth candidate was briefly added to `src/` before it had passed the reproduction. Its first build also exposed an invalid `libmutter-rpc` → `libshell` dependency. The unproved product edits were reverted; only the passing reproduction harness remains.
