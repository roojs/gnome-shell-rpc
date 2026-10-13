# Overview thumbnail drag and click

**Status:** ⏳ open. Same failure. The queue in `src/client/libshell-16/Signals.vala` holds a one-way frame only while a signal handler is still running. On the guest, `before-update` arrives after `long-press` has returned and before `clicked` arrives, so the drag still starts. `startDrag` then throws, and the pointer grab is not released.

`event` is the order that keeps that frame until `clicked` has replied, and still sends the signal that call caused at once. It passes. That order is not in the server. An idle flush was written into `Connection.vala` and removed. Idle is out of the question. Do not use it to deliver a held notification. It causes other problems.

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

`meson test -C build signal-reentrancy-event` is Ok. The server does not do this yet.

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

✔️ `tests/call-sync-repro/signal-reentrancy-gate.vala` reproduces the ordering with pure Vala and two pipes. `current` fails because `before-update` starts the drag inside `clicked`. The `later-depth`, `signal-queue`, `transport-queue`, and `server-delay` policy modes all preserve click run-to-completion while still replying to a nested blocking callback. `later-reentry` preserves the original `redraw_depth` behavior: a nested frame requests one follow-up pass without recursively invoking the active later. The `signal-reentrancy` Meson suite also passes the existing related real-RPC gates: 15 passes, three expected baseline failures (`current`, `stack-eager`, `stack-defer`), no failures, and no timeouts. `stack-bool`, `stack-void`, and `stack` pass the distributed call stack: nested RPC completes inside the open remote signal, the causal signal runs at depth 2, and the unrelated signal waits until that frame closes. Boolean and void replies differ only by completion byte. These are policy and RPC-regression results, not product fixes.

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
