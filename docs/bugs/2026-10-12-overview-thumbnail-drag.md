# Overview thumbnail drag and click

**Status:** click is fixed on the hand session. Drag is not. Diagnosis is from the 09:57 log below. Not yet shrunk into the reentrancy gate.

Hand check on the Weston debug session, 2026-10-14 ~09:57: a click on a window preview selects it and leaves the overview. Pressing and moving a preview does not start a drag. Slider grab is fixed on that same session. The update menu and the expand overlap are still broken, and they are not this bug.

## Diagnosis

The drag dies inside `long-press(CANCEL)`, before `startDrag`. `Clutter.get_current_event()` is null, so `dnd.js` throws at the line that reads the event sequence:

```text
09:57:54.644  notification method=captured-event
09:57:54.644  method=RPC-Live-Callback.reply
09:57:54.647  notification method=long-press
09:57:54.647  method=Gsr-Clutter.get_current_event
09:57:54.648  JS ERROR: TypeError: event is null
             addClickAction/<@resource:///org/gnome/shell/ui/dnd.js:151:13
09:57:54.648  method=RPC-Live-Callback.reply
```

`dnd.js` `addClickAction` calls `get_current_event()` only when the state is `Clutter.LongPressState.CANCEL`. The other `long-press` notifications in this session reply at once and never call it: 09:57:50.972, 09:57:51.475, 09:57:54.275, 09:57:56.769, and 09:57:57.271. The last pair is about 502ms apart, which is the long-press activate timeout, not a drag cancel. Only the 09:57:54.647 notification is the drag attempt.

Nothing else arrives between that notification and the throw. No `before-update`, no `clicked`, no nested signal. The handler asks for the current event as its first call, the server reply is empty (`event_from_values` returns null when the packed args are short), and the handler then replies. `long-press` is already a blocking subscription. The wait is still open when the null comes back.

This is not the click-gap reentrancy. That bug was a `before-update` running after `long-press` had returned and before `clicked` set `_actionClicked`. The applied `event-reschedule` change covers that gap, the Weston click smoke printed `ok`, and this hand click no longer starts a drag. Stock Clutter still has a current event during `long-press(CANCEL)` (`clutter-event-frame-order-gate`, `current=1,1,0`). On this RPC drag the same call sees none.

Log: `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`, session still running at 09:59. After the throw, pointer `captured-event`, `leave-event`, and `enter-event` continue. There is no `startDrag`, no `clicked`, and no second `get_current_event`.

`event-reschedule` remains the landed click fix. A frame that becomes ready while the pointer event is open is not relayed on that stack. It requests one follow-up frame instead. An idle flush was written into `Connection.vala` and removed. Idle is out of the question. Do not use it to deliver a held notification. It causes other problems.

## Applied stage 6 change

The proposal applies `event-reschedule`. A one-way `before-update` notification that is emitted while Clutter still has a current input event is consumed on the server. The stage requests a follow-up frame. No notification or boxed `Clutter.Frame` argument is retained, no idle source is added, and other notifications keep their existing order.

### 1. `src/server/rpc/Connection.vala` — `filter_notification`: allow a server module to consume one notification

**Why:** the generic connection owns the final `write()` boundary, while the Clutter module owns the event/frame policy. The passing gate requires the frame notification to be suppressed before it reaches the client.

**Where:** class signals after `stopping`, then the start of `write()`.

**Depends on:** none.

#### Add — after `stopping`, declare the per-connection notification filter

```vala
		/**
		 * Consume a notification before it is written.
		 *
		 * @param notification outbound notification
		 * @return true when the notification was consumed
		 */
		public signal bool filter_notification(OLLMrpc.Notification notification);
```

#### Remove

```vala
		{
			if (!this.channel_open || this.bin == null) {
```

#### Replace with

```vala
		{
			var notification = gobject as OLLMrpc.Notification;
			if (notification != null && this.filter_notification(notification)) {
				return;
			}
			if (!this.channel_open || this.bin == null) {
```

### 2. `src/server/rpc/Server.vala` — `connection_ready`: reschedule a frame emitted during an input event

**Why:** `event-reschedule` passes the click and drag arms without retaining frame arguments. `clutter-event-frame-order-gate` proves that the click handlers have a current event, a normal frame does not, and a frame can request a non-recursive follow-up.

**Where:** `start()`, inside `this.listen.connection_ready`, immediately after the cast to `Gsr.Server.Rpc.Connection`.

**Depends on:** ### 1.

#### Add — consume only one-way `before-update` during a current event

```vala
				conn.filter_notification.connect((notification) => {
					if (notification.method != "before-update"
							|| notification.reply_id != 0
							|| global::Clutter.get_current_event() == null) {
						return false;
					}
					((global::Clutter.Stage) stage).schedule_update();
					return true;
				});
```

These two hunks are applied. The full build and 34-check `signal-reentrancy` suite pass. The Weston click smoke prints `ok`; the installed guest remains the final check for the deterministic `press-gap` order.

## Problem

🔷 Expected: clicking a window preview selects that window, leaves the overview, and does not start a drag.

🔷 Actual: selection succeeds. The same click still starts the preview drag. On the 2026-10-13 guest the drag throws because `get_transition('scale-x')` is null, the grab stays, and further clicks stop. The clock keeps updating.

This is not a failure to activate the selected window. The BEFORE_REDRAW later still runs before the `clicked` handler that sets `_actionClicked`. The applied queue does not cover that slot: no handler is on the stack between the two signals.

## Reproduction

`press-gap` is the order from the guest log. It fails:

```bash
meson compile -C build tests/call-sync-repro/signal-reentrancy-gate
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate press-gap
```

```text
FAIL press-gap: frame between long-press and clicked started the drag
```

`meson test -C build signal-reentrancy-press-gap` expects that failure (`should_fail: true`).

`server-gap` runs the passing server rule on that same order. A frame is held only while a signal is still open, and every signal waits for a reply. It fails the same way:

```bash
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate server-gap
```

```text
FAIL server-gap: frame between long-press and clicked started the drag
```

`server` still passes. Removing the name list was not the check that failed.

`event` passes. The frame stays held until `clicked` has replied. The signal caused by that click is still sent at once.

```bash
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate event
```

```text
PASS event: frame waited until clicked set the flag
```

`meson test -C build signal-reentrancy-event` is Ok.

`event-no-click` shows why a hold started by `long-press` cannot simply wait for `clicked` to release it (`should_fail: true`). When the user drags and no `clicked` follows, the held frame is never sent:

```bash
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate event-no-click
```

```text
FAIL event-no-click: frame after long-press without clicked was never sent
```

`event-scope` holds the frame while the pointer event is open and flushes it
when that event finishes: after `clicked` replies on a click, and after
`long-press` replies on a drag. Boolean and void click completion use the same
order. On the click arm, one frame arrives in the gap before `clicked` and a
second arrives during its nested call. Both wait. A later frame with no event
open runs immediately:

```bash
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate event-scope
```

```text
PASS event-scope: frame waited for click and drag events, then idle frame ran
```

`meson test -C build signal-reentrancy-event-scope` is Ok. The server does not do this yet.

`event-reschedule` does not retain the frame notification or its boxed frame
argument. A frame that becomes ready during the event requests one follow-up
frame. The click arm supplies two arrivals, before `clicked` and during its
nested call; they coalesce into one follow-up:

```bash
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate event-reschedule
```

```text
PASS event-reschedule: event frames coalesced into one follow-up frame
```

The real-Clutter gate schedules a frame from `long-press(CANCEL)`:

```bash
timeout 20 ./build/tests/call-sync-repro/clutter-event-frame-order-gate
```

```text
PASS clutter-event-frame-order-gate: cancel=1 first=2 second=3 frame=4 current=1,1,0
```

Guest log, `alan@192.168.122.52`, `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`, session from 17:05, binaries 17:05:31:

```text
17:07:55.975  notification method=long-press
17:07:55.975  method=RPC-Live-Callback.reply
17:07:55.977  notification method=before-update
17:07:55.991  notification method=clicked
17:07:56.435  method=Meta-Display.set_cursor
17:07:56.647  JS ERROR: TypeError: this._dragActor.get_transition(...) is null
             startDrag@dnd.js:522
             addClickAction longPressLater@dnd.js:166
```

No `clicked` or `button-press-event` after 17:07:56. `gsr-client` 21773 and `gsr-server` 21427 stayed in `do_poll`. The next client lines are the clock, once a minute. Server journal at 17:07:56: `Can't update stage views ... needs an allocation` for the reparented drag actor, then the null transition.

`overview-window-activate-smoke` printed `ok` at 17:06 on Weston. That script does not put a frame in this gap.

## Evidence

✔️ `overview-window-activate-smoke` reproduced the failure on Weston:

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

The proof stopped as `smoke-fail`. The complete RPC trace is in `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`, around lines 40329661–40329730.

✔️ The relevant wire order is:

```text
notification method=long-press
method=Gsr-Clutter.get_current_event
method=Clutter-Stage.schedule_update
notification method=clicked
method=Meta-Workspace.index
reply method=Meta-Workspace.index
notification method=before-update
method=Clutter-ClickAction.release
...
method=Meta-Window.activate
```

`Meta-Workspace.index` has replied before `before-update`; the important point is that the first `clicked` handler has not returned. It continues through the activation RPC path until `Meta-Window.activate`, while incoming notifications are dispatched during those synchronous calls.

✔️ `tests/call-sync-repro/signal-reentrancy-gate.vala` reproduces the ordering
with pure Vala and two pipes. `current`, `press-gap`, and `server-gap` retain
the failure boundaries. `event-no-click` rejects a hold that depends on
`clicked`. `event-reschedule` passes the click, drag, causal nested-signal,
boolean, void, coalescing, and idle-frame checks. The Meson suite reports 24 passes, 10 expected
failures, no unexpected failures, and no timeouts. These are policy and
RPC-regression results, not product fixes.

## Steps

### 1. Connect the activation handler before the DND click marker

**Client** `vendor/gnome-shell/js/ui/windowPreview.js`

```js
let clickAction = new Clutter.ClickAction();
clickAction.connect('clicked', () => this._activate());
this._draggable.addClickAction(clickAction);
```

**Client** `vendor/gnome-shell/js/ui/dnd.js`

```js
addClickAction(action) {
    action.connect('clicked', () => (this._actionClicked = true));
```

On a normal desktop the first `clicked` handler activates the window, then the second sets `_actionClicked`. The signal completes before any BEFORE_REDRAW callback runs.

Here the handlers are connected in the same order. This step works as expected.

### 2. Cancel the long press and queue the BEFORE_REDRAW callback

**Client** `vendor/gnome-shell/js/ui/dnd.js`

```js
const event = Clutter.get_current_event();
const laters = global.compositor.get_laters();
this._longPressLater = laters.add(Meta.LaterType.BEFORE_REDRAW, () => {
    if (this._actionClicked)
        return GLib.SOURCE_REMOVE;
    action.release();
    this.startDrag(...action.get_coords(), event.get_time(),
        this._dragTouchSequence, event.get_device());
});
```

`Clutter.get_current_event()` is an RPC override.

**Client** `src/client/libmutter-clutter-rpc-16/overrides/Clutter.override.vala`

```vala
var response = Gsr.Client.Rpc.call_value(
    "Gsr-Clutter.get_current_event");
current_event_cache = event_from_values(response.args);
```

**RPC** `Gsr-Clutter.get_current_event`

**Server** `src/server/libmutter-clutter-16/Clutter.vala`

```vala
unowned var ev = global::Clutter.get_current_event();
this.reply_event(request, ev);
```

- ✔️ `long-press(CANCEL)` notification
- ✔️ `Gsr-Clutter.get_current_event` → event reply
- ✔️ `Meta-Compositor.get_laters` → laters-object reply
- ✔️ `Meta-Display.get_compositor` → compositor-object reply
- ✔️ `Meta-Compositor.get_stage` → stage-object reply
- ✔️ `Clutter-Stage.schedule_update` → empty reply
- ✔️ `RPC-Live-Callback.reply` → empty reply

On a normal desktop these calls queue the callback for the next BEFORE_REDRAW. They do not run it during the current input signal.

Here the same calls and responses complete. This step works as expected.

### 3. Enter the first clicked handler and select the window

**Client** `vendor/gnome-shell/js/ui/windowPreview.js`

```js
_activate() {
    this.emit('selected', global.get_current_time());
}
```

**Client** `vendor/gnome-shell/js/ui/workspace.js`

```js
_onCloneSelected(clone, time) {
    const wsIndex = this.metaWorkspace?.index();
    Main.activateWindow(clone.metaWindow, time, wsIndex);
}
```

**Client** `vendor/gnome-shell/js/ui/main.js`

```js
let activeWorkspaceNum = workspaceManager.get_active_workspace_index();
window.activate(time);
overview.hide();
panel.closeCalendar();
```

- ✔️ `clicked` notification
- ✔️ First handler calls `WindowPreview._activate`
- ✔️ Local `selected` signal calls `Workspace._onCloneSelected`
- ✔️ `Meta-Workspace.index` → workspace-index reply
- ✔️ `Meta-WorkspaceManager.get_active_workspace_index` → active-index reply
- ✔️ `Meta-Window.activate` → empty reply

On a normal desktop `Main.activateWindow` returns, then signal delivery proceeds to the second `clicked` handler and sets `_actionClicked`.

Here `Signals.emit()` is still inside `WindowPreview._activate`. The second handler has not run, so `_actionClicked` is still unset.

### 4. Deliver `before-update` inside the first clicked handler

This is the first point where the RPC path differs from the expected path.

**Client** `src/client/libshell-16/Signals.vala`

```vala
if (notif.reply_id == 0) {
    Signals.emit(target, notif.method, notif.args);
} else {
    Gsr.Client.Rpc.call_value("RPC-Live-Callback.reply", null,
        OLLMrpc.args("tb", (uint64) notif.reply_id,
            Signals.emit(target, notif.method, notif.args)));
}
```

An RPC call made from the outer `Signals.emit(..., "clicked", ...)` can receive another notification. The client immediately calls `Signals.emit()` again for that notification.

**Client** `src/client/libmutter-rpc-16/overrides/Laters.override.vala`

```vala
stage.signal_before_update.connect((view, frame) => {
    this.run_before_redraw();
});
```

```vala
private void run_before_redraw()
{
    if (this.redraw_depth > 0) {
        this.redraw_pending = true;
        return;
    }
    this.redraw_depth++;
    this.dispatch_before_redraw();
```

On a normal desktop `Clutter.Stage::before-update` cannot interrupt `Clutter.ClickAction::clicked`. The second click handler sets `_actionClicked` before `dispatch_before_redraw()` invokes the DND callback. The callback takes the `_actionClicked` branch and does not drag.

Here:

- 🚫 Outer client signal: `Signals.emit(clickAction, "clicked", ...)`
  - First handler: `WindowPreview._activate()`
    - Synchronous activation RPC is in progress
      - Nested `before-update` notification arrives
        - Nested client signal: `Signals.emit(stage, "before-update", ...)`
          - `run_before_redraw()`
            - `dispatch_before_redraw()`
              - DND callback reads `_actionClicked`

`redraw_depth` is zero because no later is currently being dispatched. It does not describe the outer `clicked` signal, so `run_before_redraw()` dispatches immediately. `_actionClicked` is still unset.

### 5. Take the drag branch before the click marker is set

**Client** `vendor/gnome-shell/js/ui/dnd.js`

```js
if (this._actionClicked) {
    delete this._actionClicked;
    return GLib.SOURCE_REMOVE;
}
action.release();
this.startDrag(
    ...action.get_coords(),
    event.get_time(),
    this._dragTouchSequence,
    event.get_device());
```

On a normal desktop `_actionClicked` is true. The callback removes the marker and returns.

Here `_actionClicked` is unset:

- 🚫 `Clutter-ClickAction.release` → empty reply
- 🚫 `Clutter-ClickAction.get_coords` → coordinate reply
- 🚫 `DND._Draggable.startDrag(...)`
- 🚫 `Clutter-Actor.set_opacity` sets the drag actor to `DRAGGING_WINDOW_OPACITY`

The nested `before-update` then returns. The outer `clicked` handler continues, activates the correct gedit window, and hides the overview. The second `clicked` handler eventually sets `_actionClicked`, but the callback has already started the drag.

The final state is therefore:

- ✔️ `selected=true`
- ✔️ `overview=false`
- ✔️ focus is `"Untitled Document 1 - gedit"`
- 🚫 `inDrag=true`
- 🚫 preview opacity is `100`

## Root cause

✔️ Stock gnome-shell relies on a same-process ordering guarantee: the `BEFORE_REDRAW` later queued by long-press cancellation cannot run until the current `clicked` signal emission has completed. Its `_actionClicked` guard is correct under that guarantee.

🔷 The RPC client breaks that ordering. A blocking `clicked` notification is dispatched synchronously by `src/client/libshell-16/Signals.vala`, but RPC calls made by its first JavaScript handler can deliver another signal notification. Here that notification is `before-update`. `src/client/libmutter-rpc-16/overrides/Laters.override.vala` immediately drains BEFORE_REDRAW callbacks when it receives `before-update`, even though the outer `clicked` emission is still active. The later overtakes the remaining `clicked` handler.

✔️ `clicked` and `long-press` are already blocking subscriptions in `src/server/libmutter-clutter-16/ClutterActor.vala`. Making `clicked` blocking is therefore not a fix. Blocking keeps the server waiting for the callback reply; it does not prevent the client from dispatching `before-update` during a nested RPC call.

ℹ️ Stock GNOME Shell has synchronous GObject signals; it has no blocking-versus-non-blocking notification model. `Subscription.blocking`, `Notification.reply_id`, and the hand list of boolean-return event names are this project's wire policy. Signals outside that list, including `before-update`, are currently relayed one-way. The design decision is whether to retain that name list, derive policy from the signal return type, or serialize relays on the server; it is not a stock Shell distinction.

✔️ `Connection.emit_wait_poll()` drains requests while waiting for a blocking callback but does not run `MainContext.iteration()`. The evidence does not support server main-loop pumping as the immediate cause.

## Weston click smoke

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

Second run, `overview-window-activate-smoke: miss Error: miss overview-stayed`. Log line: `after selected=true overview=true focus="Untitled Document 1 - gedit" inDrag=true actor opacity=255 scale=1,1 800x568 unmapped visible preview opacity=100`. Client log: `long-press`, `Gsr-Clutter.get_current_event`, then `clicked`, then `Clutter-ClickAction.release` while `Meta.Workspace.index` was still in flight. `clicked` is connected to `_activate` before `addClickAction` sets `_actionClicked`. The before-redraw later ran in that gap and called `startDrag`. A depth counter on `Shell.Signals.emit` plus a deferral in `Meta.Laters` was compiled and then removed. It is not the change to land without a decision.

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

### Off-code signal-ordering gate

Added `tests/call-sync-repro/signal-reentrancy-gate.vala`. It uses two pipes and pure Vala: the client enters `clicked` and makes a synchronous request; the server sends a blocking callback, waits for its reply, sends `before-update`, then sends the response.

`current` fails with `before-update started drag inside clicked`. `later-depth`, `signal-queue`, `transport-queue`, and `server-delay` pass with `clicked completed before before-update`. Every mode services the nested blocking callback before the server response, so the passing modes do not hide a deadlock by deferring all notifications.

The `later-reentry` mode covers the issue that originally required the `Meta.Laters.redraw_depth` guard: a later callback makes a synchronous request, receives nested `before-update`, and must finish without recursively invoking itself. It passes with one callback invocation at depth one and one deferred follow-up pass. The new signal-ordering design must retain that guard; signal-emission depth and later-dispatch depth protect different call stacks.

The `signal-reentrancy` Meson suite adds the existing `after-reply`, `buffer-invoke`, `reentrant-emit-call`, `outer-emit-reply`, `notif-nested-call`, `same-hook-reentrant-emit`, and `nested-relay-storm` gates. It reports 12 passes, one expected failure for `current`, no failures, and no timeouts. A product candidate must pass this suite and the Weston smoke.

### 2026-10-13 11:43 distributed call stack gate

Extended `tests/call-sync-repro/signal-reentrancy-gate.vala` with one remote signal frame. `stack-bool` and `stack-void` print `PASS ... nested rpc completed, causal signal nested, unrelated waited`. `stack` prints `PASS stack: boolean and void differ only in reply payload`. `stack-eager` prints `FAIL stack-eager: unrelated signal overtook the open remote frame`. `stack-defer` prints `FAIL stack-defer: causal signal waited until the outer frame closed`.

`meson test -C build --suite signal-reentrancy --print-errorlogs` reports 15 passes, three expected failures, no failures, and no timeouts. No product code changed.

### 2026-10-13 17:22 guest hang is this bug

Read `alan@192.168.122.52` `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` and `mutter-rpc.debug.log`, and `journalctl -b` for pids 21427 and 21773. `192.168.88.197` did not answer. Installed `/usr/bin/gsr-client`, `/usr/bin/gsr-server`, and `/usr/lib/x86_64-linux-gnu/libshell-16.so` are timestamped 17:05:31 and export `shell_signals_held_notifs`.

The 17:07:55 click replies to `long-press`, then receives `before-update`, then receives `clicked`. `Meta-Display.set_cursor` is at 17:07:56.435, inside `startDrag`, and `dnd.js:522` throws because `get_transition('scale-x')` is null. The server had already logged `needs an allocation` for the reparented actor. No later click notification arrives. Both processes stay in `do_poll`.

Added `press-gap` to `tests/call-sync-repro/signal-reentrancy-gate.vala`. The server writes `L`, reads the reply, writes `U`, writes `O`, reads the reply, writes `D`. The client uses the applied queue rule: a frame runs immediately when no handler is active. The drag flag is set only when `O` is handled.

```bash
meson compile -C build tests/call-sync-repro/signal-reentrancy-gate
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate press-gap
```

Exit 1. `FAIL press-gap: frame between long-press and clicked started the drag`. `meson test -C build signal-reentrancy-press-gap` reports Expected Fail, exit status 1.

### 2026-10-13 17:45 name-list rule on the same gap

`proposal-during` and `proposal-noreply` were the checks cited when the name-list removal was dropped. `proposal-during` skips the hold while the server is inside the shell's call. `proposal-noreply` waits for a reply the client never sends. Neither one is "every signal waits, and a frame is held for the whole open signal". That rule is `server`, which still prints `PASS server: boolean and void use the same server decision`.

Added `server-gap`. After `long-press` replies, no signal is open, so the rule sends the frame and waits for its reply, then sends `clicked`.

```bash
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate server-gap
```

Exit 1. `FAIL server-gap: frame between long-press and clicked started the drag`. `meson test -C build signal-reentrancy-server-gap` reports Expected Fail.

### 2026-10-13 17:50 hold the frame until the click has replied

`event` keeps the frame until `clicked` has replied. The signal caused by that click is still sent at once.

```bash
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate event
```

Exit 0. `PASS event: frame waited until clicked set the flag`. `meson test -C build signal-reentrancy-event` is Ok.

A flush from `GLib.Idle` was added to `src/server/rpc/Connection.vala` and then removed. Idle is out of the question. Do not use it to deliver a held notification. It causes other problems. `Connection.vala` is back to writing each notification as it is emitted. The installed guest binary is still the 17:05 build.

### 2026-10-14 08:33 `event-no-click` and `event-scope` in `signal-reentrancy-gate`

Added `event-no-click` (`should_fail: true`) and `event-scope` to `tests/call-sync-repro/signal-reentrancy-gate.vala`.

`event-no-click` starts holding the frame when `long-press` finishes and releases it only when `clicked` replies. The click arm passes, and the drag arm (`long-press` without `clicked`) never sends the frame:

```bash
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate event-no-click
```

Exit 1. `FAIL event-no-click: frame after long-press without clicked was never sent`.

`event-scope` holds the frame while the pointer event is open (`in_event`) and flushes it synchronously when that event ends (`finish_event()`), with no `GLib.Idle`. On a click, `clicked` replies before `finish_event()`, so the frame runs after `clicked` sets `_actionClicked`. On a drag, no `clicked` runs, and `finish_event()` still sends the frame as soon as the event ends:

```bash
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate event-scope
```

Exit 0. `PASS event-scope: frame waited for the event to end on both click and drag`.

`meson test -C build --suite signal-reentrancy --print-errorlogs` reports 22 Ok, 10 Expected Fail, 0 Fail, 0 Timeout. No `src/` files changed.

### 2026-10-14 08:49 debugging procedure restored

Read `docs/debugging.md` in full and returned this bug to stage 5. Removed the
premature client code proposal from
`docs/plans/1.4-signal-reentrancy.md`. No product source was inspected or
changed.

Strengthened `event-scope` in
`tests/call-sync-repro/signal-reentrancy-gate.vala`. It now runs both boolean
and void click arms, the no-`clicked` drag arm, the causal nested signal, the
held frame, and a second frame after the event has closed. The two click arms
use the same schedule and different completion bytes. Each arm receives both
frames, and the post-event frame is immediate.

```bash
meson compile -C build tests/call-sync-repro/signal-reentrancy-gate
meson test -C build --suite signal-reentrancy --print-errorlogs
```

The gate compiled. The suite reports 22 Ok, 10 Expected Fail, 0 Fail, 0
Unexpected Pass, and 0 Timeout. `event-scope` prints `PASS event-scope: frame
waited for click and drag events, then idle frame ran`.

### 2026-10-14 09:18 two held-frame arrival points

Extended `event-scope` with a second frame that becomes ready during the
click's nested call. The first frame still becomes ready after `long-press`
and before `clicked`. Both remain held until the pointer event ends. The
causal signal runs before the nested call returns, and the frame after the
event remains immediate.

The first full suite run printed `PASS same-hook-reentrant-emit-gate` but that
process did not exit before Meson's 20-second timeout. The focused retry
completed in 0.03 seconds. A second full run reports 22 Ok, 10 Expected Fail,
0 Fail, 0 Unexpected Pass, and 0 Timeout.

### 2026-10-14 09:36 stock event boundary and frame reschedule

Added `clutter-event-frame-order-gate.c`. It runs real Clutter under a headless
Mutter context. `long-press(CANCEL)` schedules a frame during button release.
Both `clicked` handlers finish before `before-update`. The cancellation and
both click handlers see `Clutter.get_current_event()` set; `before-update`
sees it clear:

```text
PASS clutter-event-frame-order-gate: cancel=1 first=2 second=3 frame=4 current=1,1,0
```

Added `event-reschedule` to the pure-Vala gate. The two click-arm frames become
one follow-up frame instead of retaining notification arguments. The drag arm
also gets a follow-up without `clicked`. The causal signal remains nested, and
the later idle frame remains immediate:

```text
PASS event-reschedule: event frames coalesced into one follow-up frame
```

A `before-update` handler was temporarily added to the Weston smoke to call
`Clutter.get_current_event()`. That added an RPC to every frame, changed the
timing, and the click passed with 112 observed frames and no current event.
The probe was removed. The next uninstrumented run also passed, so the Weston
click is not currently a deterministic failure marker. The installed guest
order and `press-gap` remain the deterministic failure.

An attempt to force `before-update` inside `clicked` with a nested
`MainContext.iteration()` in the Clutter gate did not produce a frame and
timed out. That test-only attempt was removed; nested main-context iteration
remains rejected.

The first expanded suite run printed `PASS buffer-invoke-gate` but timed out
during process exit. Its focused retry passed in 0.02 seconds. The next full
suite reports 24 Ok, 10 Expected Fail, 0 Fail, 0 Unexpected Pass, and 0
Timeout.

### 2026-10-14 09:39 follow-up frame and stage 6 proposal

Extended `clutter-event-frame-order-gate` to call `schedule_update()` from its
first `before-update`. Clutter emitted a second frame without recursively
entering the first callback:

```text
PASS clutter-event-frame-order-gate: cancel=1 first=2 second=3 frame=4 current=1,1,0 follow-up=2
```

The pure gate and the real-Clutter gate now prove every part of
`event-reschedule`: classify the input-event stack, suppress its frame relay,
coalesce multiple requests, and let the frame clock provide a later
notification. Added the stage 6 major-change proposal at the top of this file.
No `src/` file was changed.

### 2026-10-14 09:48 applied proposal; first build found the stage's declared type

Applied the two reviewed proposal hunks. The first full build failed because `Meta.Backend.get_stage()` is declared as `Clutter.Actor`, so Vala does not expose `schedule_update()` directly on the inferred local. The stage is the real `Clutter.Stage` already used by the frame signal and `peek_stage_views()`. Updated the call, and the proposal above, to cast that actor to `global::Clutter.Stage` before `schedule_update()`.

The next full build passed. `meson test -C build --suite signal-reentrancy --print-errorlogs` reports 24 Ok, 10 Expected Fail, 0 Fail, 0 Unexpected Pass, and 0 Timeout.

The Weston click proof printed `overview-window-activate-smoke: after selected=true overview=false focus="Untitled Document 1 - gedit" inDrag=false ... preview opacity=255`, then `overview-window-activate-smoke: ok`. The prove ended with `stop (smoke-ok) after 21s`. The script's exit 137 is its documented teardown of Weston after the successful smoke.

### 2026-10-14 10:05 drag hand log: current event is null on long-press cancel

Read `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` from the Weston debug session the user had just run. Hand report: click on the overview thumbnail works; drag does not. Slider grab works. Update menu and expand overlap are still broken and are not this bug.

The only `JS ERROR` in that window is at 09:57:54.648: `TypeError: event is null` at `dnd.js:151` (`event.get_event_sequence()`), immediately after `Gsr-Clutter.get_current_event` id=41605 inside `long-press`. The `captured-event` 3ms earlier replied with no nested call. No notification sits between `long-press` and the throw. Five other `long-press` notifications in the same minute reply without calling `get_current_event`. Wrote this at the top as the current diagnosis. Stopped before shrinking it into the gate. No `src/` change.
