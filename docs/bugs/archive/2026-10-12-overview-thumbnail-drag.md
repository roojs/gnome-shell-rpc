# Archived log — overview thumbnail drag and click

Archived 2026-10-14. This is the pre-split file. Do not continue it.

Current report:

- [`../2026-10-14-drag-scale-gone.md`](../2026-10-14-drag-scale-gone.md)

The text below is the file as it stood when it was split.

---

# Overview thumbnail drag and click

**Review:** not done. There is no fix to accept. The pause in `Actor.get_transition` is removed.

**Status:** click is fixed. A press that leaves the preview starts a drag, then `startDrag` throws and the grab stays. `dnd.js:522` calls `get_transition('scale-x')` after the 250ms scale has already stopped. `scale-transition-gap-smoke` passed at 16:37:39 only while `get_transition` paused the timeline and `run_main_loop` started it later. That used a new `paused_transitions` field and an `if` with no braces. Both are forbidden. The code is out. The overview smoke at 16:38:42 printed `ok` and still threw `transition-gone` at `dnd.js:522`, with no `Clutter-Timeline.pause` in the log. A move that stays on the preview still does not start a drag (13:33 `miss drag-begin`).

The smoke turns animations on and waits 400ms on the `dnd.js` `get_transition`. The prove is SIGKILL'd at about 13s (`exit 137`) and the latest runs die during startup, before that gesture. One run with animations still off, 15:49:02, threw `miss transition-gone` at `dnd.js:522` because `enable-animations` made the duration 0, so no timeline existed to pause.

Hand session 2026-10-14 14:40, `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` line 97450 and `mutter-rpc.debug.log`:

```text
14:39:59.937  Clutter-Actor.set_scale (ease starts, SCALE_ANIMATION_TIME is 250)
14:39:59.959  Clutter-Actor.get_transition id=42401 (object returned)
14:39:59.979  Clutter-Actor.get_transition id=42403 (object returned)
14:40:00.212  Clutter-Actor.get_transition id=42412
14:40:00.213  JS ERROR: TypeError: this._dragActor.get_transition(...) is null
              startDrag@resource:///org/gnome/shell/ui/dnd.js:522
```

The server frame clock kept running during the RPCs between those two `get_transition` calls (longest gap 79ms, id 42403 to 42404). The 250ms scale finished and was removed before `dnd.js:522`. Two `stopped` notifications are at 14:40:00.212. After the throw the client only logs the clock (`St-Label.set_text` at 15:17). `192.168.88.197` does not answer.

The leave smoke at 13:35:50 printed `after began=true inDrag=true dx=108.09375` and `ok` with no `event is null`. That run was fast enough that `scale-x` was still alive at `dnd.js:522`. It does not cover this hang.

```bash
GI_META_SMOKE=scale-transition-gap-smoke GSR_WESTON_PIXMAN=1 ./scripts/agent-nested-smoke-prove.sh
```

Fail line: `scale-transition-gap-smoke: miss transition-gone`. The 16:24 run printed that with an extra `miss` and `duration=250`. The overview smoke is the same gap inside `dnd.js`, and its proves were killed during shell startup.

## Diagnosis

`startDrag` calls `_grabEvents`, reparents the preview, eases `scale-x` / `scale-y` over 250ms, then calls `get_transition('scale-x')` and connects `new-frame`. In-process Clutter does not tick that timeline until the handler returns. Here `before-update` is one-way, so the server frame clock advances the timeline while `startDrag` is still in its RPCs. `clutter_actor_get_transition` is null once the timeline stops. The throw is after the grab.

A press that stays on the preview still never emits `type=3` after the press, so the long-press cancel that starts the drag does not run. The 13:33 smoke is that miss.

`event-reschedule` remains the landed click fix. Do not deliver a held notification from idle.

## Earlier leave cancel

The drag used to die inside `long-press(CANCEL)`, before `startDrag`. That path is the 11:05 log below. `get_current_event` now returns a copy of that crossing. The 13:35 leave smoke started the drag.

Weston, `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` line 86482, and `mutter-rpc.debug.log` line 69140, 2026-10-14 11:05:05:

```text
11:05:04.684  captured-event type=6 (button press) on WindowPreview
11:05:04.685  notification method=long-press
11:05:04.685  method=RPC-Live-Callback.reply
11:05:04.829  motion x=433 … 11:05:05.114 motion x=640
11:05:05.118  captured-event type=5 (leave) on WindowPreview
11:05:05.118  notification method=long-press
11:05:05.118  method=Gsr-Clutter.get_current_event id=38506
11:05:05.119  JS ERROR: TypeError: event is null
             addClickAction/<@resource:///org/gnome/shell/ui/dnd.js:151:13
11:05:05.121  notification method=leave-event
```

No `type=3` (motion) was delivered to any actor between that press and that leave. The X motion is only the backend log. `192.168.88.197` did not answer. The guest `alan@192.168.122.52` `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` has the same throw at 11:05:49.315 (line 38500) and 11:05:51.760 (line 39800): `captured-event` reply, `long-press`, `Gsr-Clutter.get_current_event`, `event is null`, then `leave-event`.

`clutter_stage_handle_event` updates the device, and that update emits the leave, before it pushes `current_event`. `clutter_stage_emit_crossing_event` does not push it either. `ClickAction` cancels the long press from that leave. The motions that would have cancelled it from `clutter_stage_process_event`, where `current_event` is set, are still queued. The queue drops a motion when the next event is a leave.

The 09:57 session is the same throw. `dnd.js` calls `get_current_event()` only for `Clutter.LongPressState.CANCEL`.

```text
09:57:54.644  notification method=captured-event
09:57:54.644  method=RPC-Live-Callback.reply
09:57:54.647  notification method=long-press
09:57:54.647  method=Gsr-Clutter.get_current_event
09:57:54.648  JS ERROR: TypeError: event is null
             addClickAction/<@resource:///org/gnome/shell/ui/dnd.js:151:13
09:57:54.648  method=RPC-Live-Callback.reply
```

Nothing else arrives between that notification and the throw. The server reply is empty. `long-press` is already a blocking subscription. The wait is still open when the null comes back. Stock Clutter still has a current event during a release cancel (`clutter-event-frame-order-gate`, `current=1,1,0`). The drag cancel is the leave path, which does not.

`event-reschedule` remains the landed click fix. A frame that becomes ready while the pointer event is open is not relayed on that stack. It requests one follow-up frame instead. An idle flush was written into `Connection.vala` and removed. Idle is out of the question. Do not use it to deliver a held notification. It causes other problems.

## Applied stage 6 change

The proposal applies `event-reschedule`. A one-way `before-update` notification that is emitted while Clutter still has a current input event is consumed on the server. The stage requests a follow-up frame. No notification or boxed `Clutter.Frame` argument is retained, no idle source is added, and other notifications keep their existing order.

The two hunks are applied in `src/server/rpc/Connection.vala` (`filter_notification` at the start of `write()`) and `src/server/rpc/Server.vala` (`connection_ready`). The Weston click smoke printed `ok`. The verbatim proposal fences were in the pre-split file and match the code that landed. Plan: `docs/plans/1.4-signal-reentrancy.md`.

## Problem

Expected: clicking a window preview selects that window, leaves the overview, and does not start a drag.

Actual, before `event-reschedule`: selection succeeds. The same click still starts the preview drag. On the 2026-10-13 guest the drag throws because `get_transition('scale-x')` is null, the grab stays, and further clicks stop. The clock keeps updating.

This was not a failure to activate the selected window. The BEFORE_REDRAW later still ran before the `clicked` handler that sets `_actionClicked`.

## Reproduction that fixed the click

`press-gap` fails and stays an expected failure:

```bash
meson compile -C build tests/call-sync-repro/signal-reentrancy-gate
timeout 5 ./build/tests/call-sync-repro/signal-reentrancy-gate press-gap
```

```text
FAIL press-gap: frame between long-press and clicked started the drag
```

`server-gap` fails the same way. `event` passes (`frame waited until clicked set the flag`). `event-no-click` fails on purpose: holding until `clicked` never sends the frame when the user drags. `event-scope` passes. `event-reschedule` passes: event frames coalesce into one follow-up frame.

```bash
timeout 20 ./build/tests/call-sync-repro/clutter-event-frame-order-gate
```

```text
PASS clutter-event-frame-order-gate: cancel=1 first=2 second=3 frame=4 current=1,1,0
```

Guest `alan@192.168.122.52`, session from 17:05, binaries 17:05:31:

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

No `clicked` or `button-press-event` after 17:07:56. Both processes stayed in `do_poll`. Server journal: `Can't update stage views ... needs an allocation` for the reparented drag actor, then the null transition.

`overview-window-activate-smoke` after the stage 6 change printed `after selected=true overview=false focus="Untitled Document 1 - gedit" inDrag=false` and `ok`. `stop (smoke-ok) after 21s`. Exit 137 on that run is Weston teardown after the smoke.

```bash
GI_META_SMOKE=overview-window-activate-smoke \
  GI_META_SMOKE_CMD='gedit --new-window' \
  GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
  GSR_NESTED_TIMEOUT=90 \
  ./scripts/agent-nested-smoke-prove.sh
```

Before that fix the same smoke printed `miss drag-on-click` with `inDrag=true` and preview opacity 100. The wire order was `long-press`, `get_current_event`, `schedule_update`, `clicked`, `Meta-Workspace.index` still in flight, then `before-update`, then `Clutter-ClickAction.release`, then `Meta-Window.activate`. `Signals.emit` of `clicked` was still inside `WindowPreview._activate` when `before-update` ran the BEFORE_REDRAW later. `_actionClicked` was still unset, so `startDrag` ran. `redraw_depth` does not describe the outer `clicked` signal.

`clicked` and `long-press` are already blocking in `ClutterActor.vala` `add_signals`. `before-update` stays off that list. `Connection.emit_wait_poll()` drains requests and does not run `MainContext.iteration()`.

## Click path in stock JS

`windowPreview.js` connects `clicked` to `_activate` before `addClickAction`. `dnd.js` `addClickAction` connects `clicked` to set `_actionClicked`. Long-press CANCEL queues a BEFORE_REDRAW later that calls `startDrag` unless `_actionClicked` is set. On a normal desktop that later cannot run until `clicked` has finished. Here a nested `before-update` during the activation RPC ran it early.

## Separate unresolved paths at the time of the split

Leave cancel (`event is null` at `dnd.js:151`) was fixed after this section was written. See the status at the top of the pre-split account, and `2026-10-14-drag-scale-gone.md`.

In-preview drag never started. This is now consolidated in
`2026-10-14-drag-scale-gone.md`.

The scale hang is the 14:40 log. See `2026-10-14-drag-scale-gone.md`.

## LLM efforts

### 2026-10-12 09:39 report created

Created as a separate bug from thumbnail rendering.

### 2026-10-12 09:41 installed-session logs name the drag boundary

Four `ClickAction::long-press` notifications called `Gsr-Clutter.get_current_event`. Each reply was followed by `JS ERROR: TypeError: event is null` at `dnd.js:151`.

### 2026-10-12 09:45 simple release does not reproduce the missing event

An immediate pointer click saw a current event and printed `ok`. The hand failure is long-press cancelled by motion while the button stays held. Later exit 139 was teardown, not the drag.

### 2026-10-12 15:05 click-to-activate merged in

`ssh alan@192.168.88.197` returned `No route to host`. Added `overview-window-activate-smoke.js`.

### 2026-10-12 15:13 click starts a drag

`pointer_click` times of 1µs and 2µs never reached the thumbnail. Press and release now use `CLUTTER_CURRENT_TIME` (0). The next run was `miss overview-stayed` with `inDrag=true` and preview opacity 100. `before-update` ran while `Meta.Workspace.index` was in flight. A depth counter plus a later deferral was compiled and removed.

### 2026-10-12 15:20 deferred-later build hung

`stop (timeout) after 90s`, exit 137. The click did not return.

### 2026-10-12 15:21 `clicked` added to the blocking list, then the box-layout abort

`gsr-client` SIGILL, `gsr-server` SIGTRAP in `clutter_actor_allocate`. `ClutterBoxLayout` minimum height `-12`. `clicked` was taken off the list and put back. The abort is the allocation bug, not a reason to unblock `clicked`.

### 2026-10-13 09:15 clean reproduction

The smoke hides panel menus before `setMenu` so startup can finish. `overview-window-activate-smoke` then reported `miss drag-on-click`. A signal-depth candidate was added to `src/` before it passed, including an invalid `libmutter-rpc` to `libshell` dependency. Those edits were reverted.

### Off-code signal-ordering gate

`tests/call-sync-repro/signal-reentrancy-gate.vala`. Two pipes, no shell. `current` fails with `before-update started drag inside clicked`. `later-depth`, `signal-queue`, `transport-queue`, and `server-delay` pass. `later-reentry` passes with one callback at depth one. The suite then reported 12 passes and one expected failure.

### 2026-10-13 11:43 distributed call stack

`stack-bool`, `stack-void`, and `stack` pass. `stack-eager` and `stack-defer` fail on purpose. Suite: 15 passes, three expected failures.

### 2026-10-13 17:22 guest hang

`alan@192.168.122.52` 17:07:55 is `long-press`, reply, `before-update`, `clicked`, then `dnd.js:522` null `get_transition`. Added `press-gap`. `FAIL press-gap: frame between long-press and clicked started the drag`. Expected fail.

### 2026-10-13 17:45 `server-gap`

`FAIL server-gap: frame between long-press and clicked started the drag`. `server` still passes.

### 2026-10-13 17:50 `event` passes

`PASS event: frame waited until clicked set the flag`. An idle flush was added to `Connection.vala` and removed.

### 2026-10-14 08:33 `event-no-click` and `event-scope`

`event-no-click` fails on purpose. `event-scope` passes. Suite: 22 Ok, 10 expected fail. No `src/` change.

### 2026-10-14 08:49 through 09:36

`event-scope` grew a second frame during the nested call, boolean and void arms, and an idle frame after the event. `clutter-event-frame-order-gate` passes `cancel=1 first=2 second=3 frame=4 current=1,1,0`. `event-reschedule` passes. A nested `MainContext.iteration()` inside the Clutter gate timed out and was removed. Suite: 24 Ok, 10 expected fail.

### 2026-10-14 09:39 through 09:48 stage 6 applied

Follow-up `schedule_update` from the first `before-update` produced `follow-up=2` without reentering the callback. The proposal was applied. The stage from `Meta.Backend.get_stage()` is typed as `Clutter.Actor`, so the call casts to `global::Clutter.Stage`. Full build passed. Click smoke printed `ok`.

### 2026-10-14 10:05 through 11:06 leave cancel

Hand: click works, drag does not. `event is null` at `dnd.js:151`. `192.168.88.197` does not answer. Guest `192.168.122.52` and Weston 11:05 show the same throw on a leave (`type=5`) with no actor `type=3` between the press and the leave. `clutter-drag-leave-gate` batched run: `FAIL ... leave cancel had no current event type=-1`. Flushed run: `PASS ... type=3`.

### 2026-10-14 12:14 in-preview miss

12:12 hand: one `type=3` cluster, then long-press query and activate. No drag. A smoke that only required `drag-begin` had printed `ok` at 12:08 while `dnd.js:522` threw. The tightened in-preview smoke printed `miss drag-begin`, `began=false dx=0`. No `type=3` after the press.

### 2026-10-14 13:17 leave copy, then 13:35 pass

Three more `event is null` throws. `get_current_event` now returns `open_event`. In-preview runs still `miss drag-begin`. The leave smoke at 13:35 printed `began=true inDrag=true dx=108.09375` and `ok`.

### 2026-10-14 14:40 hang

Drag started, then `get_transition` id=42412 is null at `dnd.js:522`. `stopped` at the same instant. Clock keeps logging. Grab stays.

### 2026-10-14 15:49

With animations off, duration becomes 0 and `miss transition-gone` is a missing timeline, not a finished one. An idle resume and a `SpawnClient` `LD_LIBRARY_PATH` setenv were added and removed. Later overview proves were SIGKILL'd during startup (`hook` only). `St.Settings.enable-animations` is not writable.

### 2026-10-14 16:24 shrunk gap fails

`scale-transition-gap-smoke` with `{animationRequired: true}`: first `get_transition` returns an object, 400ms later `stopped` and `miss transition-gone duration=250`. `stop (smoke-fail) after 1s`.

### 2026-10-14 16:37 rejected hold

The smoke calling `pause()` then `start()` printed `ok` at 16:35:17. Moving that into `Actor.get_transition` plus a `context.iteration()` loop in `run_main_loop` printed `ok` at 16:37:39 (`pause` id=33, `get_transition` id=34, `start` id=36, `stopped`, `stop (smoke-ok) after 1s`). That change added `paused_transitions`, an `if` with no braces, and replaced `loop.run()`. It was removed.

The 16:38 overview smoke printed `ok` with `dx=93` and still threw `transition-gone` at `dnd.js:522`. No `Clutter-Timeline.pause`. The ease created no timeline. That `ok` is not a pass of the hang.
