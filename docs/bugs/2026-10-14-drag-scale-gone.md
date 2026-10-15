# Drag scale is gone before dnd.js connects it

Split from [`2026-10-12-overview-thumbnail-drag.md`](2026-10-12-overview-thumbnail-drag.md) on 2026-10-14. That file is only a pointer. The long log is [`archive/2026-10-12-overview-thumbnail-drag.md`](archive/2026-10-12-overview-thumbnail-drag.md). Do not continue the old file.

**Review:** the global transition hold is rejected and out of `src/`. Its
stand-alone gate did not exercise the product hook, and its guest install
regressed startup. The guest was still running the 17:50 install at the last
reachable check. Do not `gdm3 restart` to try that install.

**Status:** ✔️ the scale-gone failure is fixed in nested Weston with the
2026-10-15 libocrpc void-signal fix and `before-update` on the consumer
blocking list. The 400ms forced gap at `dnd.js:522` still returned the
`scale-x` transition; `new-frame` connected and fired. There was no
`transition-gone` error. The smoke continued and failed separately with
`miss preview-moved dx=0` after `drag-begin`. `Actor.set_scale` remains the
single RPC only; the rejected transition hold stays out.

## Rejected proposal

`pause-on-ease` on the gate: pause the timeline when ease returns, leave it paused across the quiet gap, and start it when the handler returns. The scale is still at its start for the second read, `new-frame` can connect, and the scale then finishes.

`startDrag` runs inside `Shell.Signals.emit` (before-update, then the before-redraw later). `emit_depth` is already that nesting. When it returns to 0, `drain_notifs` already runs. The start goes there. `Meta.Context.run_main_loop` stays `loop.run()`. Nothing uses `GLib.Idle`. `Actor.get_transition` is not changed.

The list is `Shell.Signals.held_timelines`. It is the same kind of memory as `held_notifs`, and it lives for the open `emit` only. It is not a field on `Gsr.Client.Rpc`, and nothing walks it from the main loop. The clutter client does not link shell-gi, so `set_scale` reaches it through a C trampoline, the same way `pending_signals` already works.

A timeline that has already advanced more than 32ms is left alone, so a later `set_scale` during the drag does not pause the scale that already started. 32 is one or two frames between the setter's return and the elapsed read. `get_transition` of each axis is an extra RPC on every `set_scale`.

### 1. `src/client/libshell-16/Signals.vala` — `held_timelines`

**Why:** `emit` has to start the timelines it paused, and only those. `held_notifs` is the existing list with the same lifetime.

**Where:** static fields, immediately after `held_notifs`.

**Depends on:** none.

#### Add

After the `held_notifs` field. Timelines paused while `emit` is open.

```vala
		/**
		 * Timelines paused while {@link emit} is still running.
		 *
		 * {@link hold_transition} appends. {@link release_timelines}
		 * starts them when {@link emit_depth} is back to zero.
		 * Created with the other tables on the first {@link connect}.
		 */
		private static Gee.ArrayList<GLib.Object>? held_timelines;
```

#### Remove

```vala
			Signals.held_notifs = new Gee.ArrayList<OLLMrpc.Notification>();
```

#### Replace with

```vala
			Signals.held_notifs = new Gee.ArrayList<OLLMrpc.Notification>();
			Signals.held_timelines = new Gee.ArrayList<GLib.Object>();
```

### 2. `src/client/libshell-16/Signals.vala` — `hold_transition`, `release_timelines`

**Why:** pause a timeline that has just started, and start it only when the outermost `emit` has returned.

**Where:** new methods on `Shell.Signals`, after `emit`. `hold_transition` is the C symbol the clutter client calls. `release_timelines` stays in this file.

**Depends on:** §1.

#### Add

New methods after `emit`, still inside `class Signals`.

```vala
		/**
		 * Pause a timeline until the outermost {@link emit} returns.
		 *
		 * A call with no emit open does nothing, so an animation
		 * started from the main loop keeps playing. A timeline that
		 * has already advanced, or is not playing, is left alone.
		 *
		 * @param timeline leased timeline from get_transition
		 */
		[CCode (cname = "shell_signals_hold_transition")]
		public static void hold_transition(GLib.Object timeline)
		{
			if (Signals.emit_depth == 0) {
				return;
			}
			var playing = Gsr.Client.Rpc.call_value("Clutter-Timeline.is_playing", timeline);
			if (playing.retval.type() != GLib.Type.BOOLEAN || !playing.retval.get_boolean()) {
				return;
			}
			var elapsed = Gsr.Client.Rpc.call_value("Clutter-Timeline.get_elapsed_time", timeline);
			if (elapsed.retval.type() != GLib.Type.UINT || elapsed.retval.get_uint() > 32) {
				return;
			}
			Gsr.Client.Rpc.call_value("Clutter-Timeline.pause", timeline);
			if (Signals.held_timelines == null) {
				Signals.held_timelines = new Gee.ArrayList<GLib.Object>();
			}
			Signals.held_timelines.add(timeline);
		}

		/**
		 * Start timelines paused by {@link hold_transition}.
		 *
		 * A nested emit leaves them paused. The list is swapped
		 * out before the start calls, so a start that re-enters
		 * emit cannot start the same timeline twice.
		 */
		private static void release_timelines()
		{
			if (Signals.emit_depth != 0 || Signals.held_timelines == null) {
				return;
			}
			var pending = Signals.held_timelines;
			Signals.held_timelines = new Gee.ArrayList<GLib.Object>();
			foreach (var timeline in pending) {
				Gsr.Client.Rpc.call_value("Clutter-Timeline.start", timeline);
			}
		}
```

### 3. `src/client/libshell-16/Signals.vala` — `emit`

**Why:** both returns from `emit` already drop `emit_depth` and then deliver queued notifications. The paused scale starts at that same moment, after `startDrag` has connected `new-frame`.

**Where:** the two `emit_depth--` sites inside `emit`.

**Depends on:** §2.

#### Remove

```vala
				Signals.emit_depth--;
				Signals.drain_notifs();
				return false;
```

#### Replace with

```vala
				Signals.emit_depth--;
				Signals.release_timelines();
				Signals.drain_notifs();
				return false;
```

#### Remove

```vala
			Signals.emit_depth--;
			Signals.drain_notifs();
			return result;
```

#### Replace with

```vala
			Signals.emit_depth--;
			Signals.release_timelines();
			Signals.drain_notifs();
			return result;
```

### 4. `src/client/rpc/namespace.vala` — `hold_transition`

**Why:** `Actor.set_scale` lives in the clutter client, which does not link shell-gi. The trampoline is the same shape as `ensure_signal_subscribe`.

**Where:** extern next to `shell_signals_disconnect`. Public method next to `ensure_signal_unsubscribe`.

**Depends on:** §2.

#### Add

Extern immediately after `shell_signals_disconnect`.

```vala
	[CCode (cname = "shell_signals_hold_transition")]
	private extern void shell_signals_hold_transition(GLib.Object timeline);
```

#### Add

Public method immediately after `ensure_signal_unsubscribe`.

```vala
	/**
	 * Vala stub path into {@link Shell.Signals.hold_transition}.
	 *
	 * mutter-rpc / st-rpc cannot link shell-gi. Lazy-bound
	 * ({@code --unresolved-symbols}).
	 *
	 * @param timeline leased timeline from get_transition
	 */
	public void hold_transition(GLib.Object timeline)
	{
		shell_signals_hold_transition(timeline);
	}
```

### 5. `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` — `set_scale`

**Why:** ease sets `scale_x` and `scale_y`, and both setters call `set_scale`. The implicit timelines exist when that RPC returns. Holding them there is before the gap that removes them. `get_transition` is unchanged.

**Where:** end of `set_scale`, after the `Clutter-Actor.set_scale` call.

**Depends on:** §4.

#### Remove

```vala
		Gsr.Client.Rpc.call_value(
			"Clutter-Actor.set_scale", this,
			OLLMrpc.args("dd", scale_x, scale_y));
	}
```

#### Replace with

```vala
		Gsr.Client.Rpc.call_value(
			"Clutter-Actor.set_scale", this,
			OLLMrpc.args("dd", scale_x, scale_y));
		var x_transition = this.get_transition("scale-x");
		if (x_transition != null) {
			Gsr.Client.Rpc.hold_transition(x_transition);
		}
		var y_transition = this.get_transition("scale-y");
		if (y_transition != null) {
			Gsr.Client.Rpc.hold_transition(y_transition);
		}
	}
```

The other open drag failure, a move that stays on the preview and never starts a drag, is [`2026-10-14-drag-inside-preview.md`](2026-10-14-drag-inside-preview.md). Do not mix them.

## What already landed

Click is fixed. Do not reopen it. `event-reschedule` is in `src/server/rpc/Server.vala` `filter_notification` and `src/server/rpc/Connection.vala` `write()`. A one-way `before-update` while `Clutter.get_current_event()` is set is consumed and `schedule_update()` is called. `overview-window-activate-smoke` printed `ok`. Plan [`docs/plans/1.4-signal-reentrancy.md`](../plans/1.4-signal-reentrancy.md).

The leave cancel is fixed. Do not reopen it. `dnd.js:151` used to throw `event is null` on long-press CANCEL. `src/server/libmutter-clutter-16/Clutter.vala` copies that crossing into `open_event` when `clutter_get_current_event()` is null, and `get_current_event` returns the copy. The C symbol stays `_clutter_stage_process_queued_events`. The 13:35 leave smoke printed `after began=true inDrag=true dx=108.09375` and `ok` with no `event is null`. That run was fast enough that `scale-x` was still alive. It does not cover this hang.

## The failure

The cache logs are not on the next machine. The lines below are the record.

Hand drag, nested Weston, 2026-10-14 14:40. Copied from `org.gnome.ShellRpc.debug.log` and `mutter-rpc.debug.log` before those files were left behind:

```text
14:39:59.930  set_easing_duration, remove_transition, remove_transition,
              set_scale, set_scale, restore_easing_state
14:39:59.937  Clutter-Actor.set_scale
14:39:59.959  Clutter-Actor.get_transition id=42401   object returned, add_signals followed
14:39:59.979  Clutter-Actor.get_transition id=42403   object returned, add_signals followed
14:40:00.058  next RPC after 42403                    gap 79ms (42403 → 42404)
              later gaps in that chain: 18ms, 33ms, 49ms, 1ms, 1ms, 15ms, 34ms, 1ms
14:40:00.212  Clutter-Actor.get_transition id=42412   null
14:40:00.212  two notifications method=stopped
14:40:00.213  JS ERROR: TypeError: this._dragActor.get_transition(...) is null
              startDrag@resource:///org/gnome/shell/ui/dnd.js:522
              pageIndicators.js
              appDisplay.js:493
              iconGrid.js:1180 (_redisplay)
15:17         client still logging only St-Label.set_text (id=44832)
15:24:19      socket closed, session dead
```

Just before the throw: a `g_value_get_uint` assertion, and `property 'realized' of WindowPreview is not writable`. One `JS ERROR` in that window. After it, input is dead and the grab stays. `192.168.88.197` did not answer.

The same throw on the guest `alan@192.168.122.52`, binaries timestamped 17:05:31, session from 17:05:

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

No later click. Server journal at 17:07:56: `Can't update stage views ... needs an allocation` for the reparented drag actor, then the null transition. `gsr-client` 21773 and `gsr-server` 21427 stayed in `do_poll`.

`startDrag` (`vendor/gnome-shell/js/ui/dnd.js` around 511–525) grabs, reparents the preview, eases `scale-x` / `scale-y` for `SCALE_ANIMATION_TIME` (250), then calls `get_transition('scale-x')` and connects `new-frame`. `drag-begin` fires before that call. A smoke that only checks `drag-begin` can pass while this throw still happens, and the grab is already held.

In one process the frame clock does not tick until the handler returns. Here `before-update` is one-way. `OLLMchat/libocrpc/Live/Subscription.vala` `emit` waits for `RPC-Live-Callback.reply` only when `blocking` is set and `return_value` is non-null. `before-update` is void, so putting it on the blocking list does not hold the frame. `Connection.emit_wait_poll` polls the socket and does not iterate the main loop. The clock still runs in the gaps while the client is inside `startDrag` and the socket is empty.

`dnd.js` does not pass `animationRequired`. `environment.js` `set_easing_duration` goes through `adjustAnimationTime`. `St.Settings.enable-animations` is not writable. When that setting is false the duration becomes 0, no timeline is created, and `get_transition` is null for a different reason. The 14:40 log had a real timeline. A reproduction that does not force a 250ms duration is not this bug.

## Reproduction

`tests/call-sync-repro/scale-gap-gate.vala`. No product source, no shell boot. `current` is the split: a 250ms timeline exists, the grab is already held, a 400ms quiet gap runs the clock in one frame because `before-update` does not wait, `stopped` is written with no reply, and the second read of `scale-x` is null. `new-frame` is not connected. `in-process` is the control, not a strategy: the clock does not tick until the handler returns, the second read is still the timeline, and the scale then finishes at 500.

```bash
meson compile -C build tests/call-sync-repro/scale-gap-gate
timeout 5 ./build/tests/call-sync-repro/scale-gap-gate current
timeout 5 ./build/tests/call-sync-repro/scale-gap-gate in-process
```

`current` exits 1: `FAIL current: scale-x gone before the handler returned`. `in-process` exits 0. A strategy passes only when the second read is still non-null, the scale is still at its start then, and it finishes after that. `pause-on-ease`, `pause-plain`, `pause-on-get`, and `start-on-frame` exit 0. `ease-gap`, `frame-plain`, `start-on-stopped`, `hold-until-click`, and `inhibit-drag` exit 1. Meson marks the exit-1 modes `should_fail: true`. Only a minor change that already passed here may be copied into `src/`. `pause-on-ease` is not minor.

The JavaScript smokes below are the hand evidence. They are not the suite to hack.

`tests/gjs-embed/scale-transition-gap-smoke.js` maps an actor, sets a 250ms scale with `{animationRequired: true}`, reads `scale-x`, busy-waits 400ms, reads `scale-x` again, then after another 400ms requires `scale_x` near 0.5.

```bash
GI_META_SMOKE=scale-transition-gap-smoke GSR_WESTON_PIXMAN=1 ./scripts/agent-nested-smoke-prove.sh
```

16:24:28, copied from `weston-autolaunch-prove.log`. This is the failure with `src/` unchanged:

```text
16:24:27.964  Clutter-Actor.get_transition id=30
16:24:27.964  Gsr-Clutter-Actor.add_signals id=31     object returned
16:24:28.365  Clutter-Actor.get_transition id=32
16:24:28.365  notification method=stopped
16:24:28.365  JS LOG: scale-transition-gap-smoke: miss miss transition-gone duration=250
             nested-weston-prove: stop (smoke-fail) after 1s
```

Fail line now, after the double `miss` was cleaned in the smoke: `scale-transition-gap-smoke: miss transition-gone`. That wording change has not been rerun.

16:35:17. The smoke itself called `pause()` then `start()`. Not a product fix:

```text
16:35:16.795  Clutter-Actor.get_transition id=33
16:35:16.795  Clutter-Timeline.start id=34
16:35:17.046  notification method=stopped
16:35:17.196  JS LOG: scale-transition-gap-smoke: ok
             nested-weston-prove: stop (smoke-ok) after 2s
```

16:37:39. The same pause and start were moved into `Actor.get_transition` and a `context.iteration()` loop in `run_main_loop`. Rejected and removed. `get_transition` only subscribes `stopped`. `run_main_loop` is `loop.run()` again.

```text
16:37:38.671  Clutter-Timeline.pause id=33
16:37:39.072  Clutter-Actor.get_transition id=34
16:37:39.072  Clutter-Timeline.is_playing id=35
16:37:39.072  Clutter-Timeline.start id=36
16:37:39.323  notification method=stopped
16:37:39.473  JS LOG: scale-transition-gap-smoke: ok
             nested-weston-prove: stop (smoke-ok) after 1s
```

`overview-thumbnail-drag-smoke` is the same gap inside real `dnd.js`. It launches gedit, opens the overview, and moves off the preview. It busy-waits 400ms on the `dnd.js` `get_transition('scale-x')` that is not the `environment.js` call. It now forces `animationRequired` on `set_easing_duration`, and it fails the smoke if that second read is null. That edit has not been run.

15:49:02, animations still off, so this is a missing timeline, not a finished one. Ease's own `get_transition` ids 17495 and 17496 returned null (no `add_signals`, next RPC was `disable_unredirect`). 400ms later the `dnd.js` read threw `miss transition-gone`. No `Clutter-Timeline.pause`.

16:38:42, before the `animationRequired` edit. `ok` here is not a pass. No `Clutter-Timeline.pause` anywhere in the run. `set_scale` is followed 2ms later by `get_transition` with no timeline:

```text
16:38:41.056  overview-thumbnail-drag-smoke: drag 399.4765625,296.162109375 size=478.203125x339.52734375
16:38:41.507  Clutter-Actor.set_scale id=17445
16:38:41.508  Clutter-Actor.set_scale id=17446
16:38:41.519  Clutter-Actor.set_easing_duration id=17468
16:38:41.562  Clutter-Actor.remove_transition id=17551
16:38:41.567  Clutter-Actor.remove_transition id=17552
16:38:41.569  Clutter-Actor.set_scale id=17554
16:38:41.570  Clutter-Actor.set_scale id=17555
16:38:41.571  Clutter-Actor.get_transition id=17557
16:38:41.572  Clutter-Actor.get_transition id=17558
16:38:41.974  Clutter-Actor.get_transition id=17562
16:38:41.984  JS ERROR: Error: miss transition-gone
              get_transition@tests/gjs-embed/overview-thumbnail-drag-smoke.js:164
              startDrag@resource:///org/gnome/shell/ui/dnd.js:522
              addClickAction/<@resource:///org/gnome/shell/ui/dnd.js:166
              OutputIndicator@resource:///org/gnome/shell/ui/status/volume.js:462
              _updateVolume@resource:///org/gnome/shell/ui/status/volume.js:233
              set stream@resource:///org/gnome/shell/ui/status/volume.js:102
              _readOutput@resource:///org/gnome/shell/ui/status/volume.js:479
              OutputIndicator@resource:///org/gnome/shell/ui/status/volume.js:454
              overview-thumbnail-drag-smoke.js:219
16:38:42.107  overview-thumbnail-drag-smoke: after began=true inDrag=true dx=93.22265625
16:38:42.107  overview-thumbnail-drag-smoke: ok
16:38:42.107  overview-thumbnail-drag-smoke: done
             nested-weston-prove: stop (smoke-ok) after 12s
```

The throw is inside a volume `startDrag`, so it did not fail the smoke promise. `drag-begin` had already fired.

```bash
GI_META_SMOKE=overview-thumbnail-drag-smoke GI_META_SMOKE_CMD='gedit --new-window' GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 GSR_WESTON_PIXMAN=1 GSR_NESTED_TIMEOUT=90 ./scripts/agent-nested-smoke-prove.sh
```

Prove exit 137 is an external SIGKILL, often around 13s, including after `stop (smoke-ok)`. The smoke line above is the result. `nested-weston-prove.sh` truncates the client log at the start of a run, so an old line will not still be there. Do not start a prove while a nested Weston session is up.

`dnd.js` as it stands. `SCALE_ANIMATION_TIME` is 250. `drag-begin` is emitted before this ease. Line 522 is the unguarded call:

```js
this._dragActor.ease({
    scale_x: scale * origScale,
    scale_y: scale * origScale,
    duration: SCALE_ANIMATION_TIME,
    mode: Clutter.AnimationMode.EASE_OUT_QUAD,
    onComplete: () => {
        this._updateActorPosition(origScale,
            origDragOffsetX, origDragOffsetY, transX, transY);
    },
});
this._dragActor.get_transition('scale-x').connect('new-frame', () => {
    this._updateActorPosition(origScale,
        origDragOffsetX, origDragOffsetY, transX, transY);
});
```

`vendor/gnome-shell/` is gitignored. Those lines are the copy.

## Do not repeat

- Do not edit `src/` until the same change already passes in a Vala gate under `tests/call-sync-repro/`. Do not treat `scale-transition-gap-smoke` as that suite. A pause in `Actor.get_transition` and a hand-rolled loop in `run_main_loop` were written into `src/` while the only reproduction was JavaScript. Both were removed.
- Do not use `GLib.Idle` or `GLib.timeout` to resume a timeline or to deliver a held notification. An idle flush in `Connection.vala` was added and removed. `docs/plans/1.4-signal-reentrancy.md` forbids `GLib.Idle` and a nested `MainContext.iteration()`.
- Do not replace `Meta.Context.run_main_loop`'s `loop.run()` with `context.iteration()`. That was tried at 16:37 and rejected.
- Do not add a field or a method to remember paused timelines. `Gsr.Client.Rpc.paused_transitions` was added and removed. Coding standards forbid a new field or method unless the user or a plan names it. The `if` that filled that list also had no braces.
- Do not put `LD_LIBRARY_PATH` or `GSR_TYPELIB_DIR` into `SpawnClient`. The client already links `build/src/libmutter-clutter-rpc-16.so` via RUNPATH. That setenv was added and removed.
- Do not mark `before-update` blocking and expect the frame to wait. It is a void signal, so `Subscription.emit` does not wait. Do not edit OLLMchat. A filtered write returns before the wait; a blocking notification that was not written must not be left waiting. If that wait is in OPC, the stop is a FAIL gate under `tests/call-sync-repro/` plus the bug file.
- Do not inhibit the frame clock for the whole drag. `new-frame` has to be connected, then the 250ms scale has to run.
- Do not hold every frame until `clicked`. That is the `event-no-click` failure. A drag has no `clicked`.
- Do not return STOP from the event filter. That drops the click sequence.
- Do not rename `_clutter_stage_process_queued_events`.
- Do not treat `drag-begin` alone as success. The 12:08 smoke printed `ok` while `dnd.js:522` threw.
- `ClutterBoxLayout` minimum height `-12` and `global.stage.context is null` are a different abort. The update menu and the expand overlap are different bugs.

## Where to start

Do not reapply the proposal at the top. Continue from the FAIL-backed
libocrpc bug
[`2026-10-15-blocking-void-signal-does-not-wait.md`](2026-10-15-blocking-void-signal-does-not-wait.md).
`src/` stays as it is. `get_transition` and `run_main_loop` are not consumer
fix points.

## LLM efforts

### 2026-10-14 16:47 split out of the thumbnail-drag log

The previous file mixed the fixed click, the fixed leave cancel, this hang, and the in-preview miss. Those two open failures are now separate files. The pause / `run_main_loop` experiment is recorded above and is not in `src/`.

### 2026-10-14 16:55 Vala gate

`tests/call-sync-repro/scale-gap-gate.vala`. No product source. `current` is the quiet-gap clock. `in-process` does not tick until the handler returns.

```bash
meson compile -C build tests/call-sync-repro/scale-gap-gate
timeout 5 ./build/tests/call-sync-repro/scale-gap-gate current
timeout 5 ./build/tests/call-sync-repro/scale-gap-gate in-process
```

`FAIL current: scale-x gone before the handler returned` exit 1. `PASS in-process: scale-x stayed until the handler returned, then the scale finished` exit 0. `src/` was not edited.

### 2026-10-14 17:14 strategy modes

Same gate, no product source. Each mode is one idea. Pass means the second read is still the timeline, the scale is still at its start at that read, and the scale then reaches the end.

```bash
meson compile -C build tests/call-sync-repro/scale-gap-gate
GATE=./build/tests/call-sync-repro/scale-gap-gate
timeout 5 $GATE pause-on-ease
timeout 5 $GATE pause-plain
timeout 5 $GATE pause-on-get
timeout 5 $GATE ease-gap
timeout 5 $GATE start-on-frame
timeout 5 $GATE frame-plain
timeout 5 $GATE start-on-stopped
timeout 5 $GATE hold-until-click
timeout 5 $GATE inhibit-drag
```

| Mode | Exit | Line |
| --- | --- | --- |
| `pause-on-ease` | 0 | `PASS pause-on-ease: scale-x stayed across the gap, then the scale finished` |
| `pause-plain` | 0 | `PASS pause-plain: ordinary ease survived the gap and then finished` |
| `pause-on-get` | 0 | `PASS pause-on-get: scale-x stayed across the gap, then the scale finished` |
| `ease-gap` | 1 | `FAIL ease-gap: scale-x gone before the first get` |
| `start-on-frame` | 0 | `PASS start-on-frame: scale-x stayed across the gap, then the scale finished` |
| `frame-plain` | 1 | `FAIL frame-plain: scale never started without new-frame` |
| `start-on-stopped` | 1 | `FAIL start-on-stopped: subscribing stopped let the gap finish the timeline` |
| `hold-until-click` | 1 | `FAIL hold-until-click: scale never finished, drag has no clicked` |
| `inhibit-drag` | 1 | `FAIL inhibit-drag: scale did not run while the grab was held` |

`pause-on-ease` pauses when ease returns, so a gap before the first get does not finish the timeline, and it starts when the handler returns. `pause-plain` is that pause with no `new-frame` connect, so an ordinary ease still finishes. `pause-on-get` only pauses after a successful get, and `ease-gap` shows a gap before that get still removes the timeline. `start-on-frame` stays paused until the `new-frame` subscribe `dnd.js` already does, and `frame-plain` shows an ease that never subscribes never starts. `start-on-stopped` starts at the `stopped` subscribe `get_transition` already does, which is before the killing gap. `hold-until-click` and `inhibit-drag` keep the second read alive and then never run the scale. `src/` was not edited.

### 2026-10-14 17:27 proposal

The hunks are the `## Proposal` section at the top of this file. Pause is in `Actor.set_scale` after the RPC returns. Start is `Shell.Signals.release_timelines` when `emit_depth` drops to 0. `held_timelines` sits next to `held_notifs`. The clutter client calls it through `shell_signals_hold_transition`, because that library does not link shell-gi. `get_transition` and `run_main_loop` are not in the hunks.

### 2026-10-14 17:37 applied

The `call_value` and `if` lines in `hold_transition` are one line each. Applied to `Signals.vala`, `namespace.vala`, and `Actor.override.vala`. `ninja -C build src/libshell-16.so src/libgsr-rpc-16.so src/libmutter-clutter-rpc-16.so` linked.

```bash
GI_META_SMOKE=scale-transition-gap-smoke GSR_WESTON_PIXMAN=1 ./scripts/agent-nested-smoke-prove.sh
```

`scale-transition-gap-smoke: ok` at 17:39:55.135. `stop (smoke-ok) after 2s`. Prove exit 137 after that line. `set_scale` id=28 at 17:39:54.331, then `get_transition` ids 29 and 31. No `Clutter-Timeline.is_playing`, `pause`, or `start`. The smoke runs from `GLib.idle_add`, so `emit_depth` is 0 and `hold_transition` returns before those calls. The second `get_transition` id=35 at 17:39:54.733 still returned, and `stopped` is at 17:39:54.736. That idle path is not the open `emit` inside `startDrag`.

### 2026-10-14 17:42 hand drag

Nested Weston, `nested-weston-prove.tee.log`. One `JS ERROR`, and it is `global.get_switcheroo_control is not a function` at 17:42:50.183 in `appMenu.js`. No `dnd.js:522` throw. The session socket closed at 17:42:53.884. The scale still finished during the ease:

```text
17:42:29.614  Clutter-Actor.set_scale id=16233
17:42:29.616  Clutter-Actor.get_transition id=16234
17:42:29.621  Clutter-Timeline.is_playing id=16236
17:42:29.622  Clutter-Timeline.get_elapsed_time id=16237
17:42:29.624  Clutter-Timeline.pause id=16238
17:42:29.627  Clutter-Actor.set_scale id=16240
17:42:29.631  Clutter-Timeline.is_playing id=16242
17:42:29.684  Clutter-Timeline.is_playing id=16245
17:42:29.716  Clutter-Timeline.get_elapsed_time id=16246
              no pause after this pair
17:42:29.885  notification method=stopped
17:42:29.988  Clutter-Actor.restore_easing_state id=16252
17:42:31.099  Clutter-Timeline.start id=16433
              between St-Adjustment.get_value and Clutter-Transition.set_to
```

`set_scale` at .614 to `stopped` at .885 is 271ms. `before-update` arrives between the hold's own RPCs (the `get_elapsed_time` reply is 64ms after the call). The elapsed read is already past 32ms, so that timeline is not paused, and it reaches the end while ease is still running. The one timeline that was paused is started at 17:42:31.099, 1.5s later, in the middle of another ease. The 17:43 session has `GSR_DEBUG=0` and an empty debug log.

### 2026-10-14 17:48 launch

Same log. A click calls `Gsr-Mutter-AppLaunch.launch_desktop_file` id=16473 at 17:48:15.594 and the reply is 17:48:15.621. No `returned false` warning. The only `window_created` after that is 17:48:29.958, `title=(null) frame=0,0 0x0`. No later `size-changed` and no second `window_created`. At that same second the nested bus activates `xdg-desktop-portal` and `org.freedesktop.secrets` exits 1. `JS ERROR: global.get_switcheroo_control is not a function` is 17:48:45.183 in `appMenu.js`. No application process was still running when the session was checked afterwards.

## LLM efforts

### 2026-10-14 17:54 guest boot

`alan@192.168.122.52`. `192.168.88.197` has no route. Boot `-1` (`02c6358e952a4748a135e9f6219f3bb8`) ran from 2026-10-13 17:20 until 2026-10-14 17:52:06. At 17:50:55 `meson install --no-rebuild` from `/home/alan/gitlive/gnome-shell-rpc/build`. At 17:50:59 `/etc/init.d/gdm3 restart`. The new libraries are stamped 17:50:55 and export `shell_signals_hold_transition` and `gsr_client_rpc_hold_transition`. Journald at 17:52:00: `Suppressed 3275 messages from user@1000.service`. From 17:51:38 the new `gsr-server` logs `g_atomic_ref_count_dec: assertion 'old_value > 0' failed`, `gsignal.c:2699` no handler, and a `St-Widget.set_label_actor` `-32602` loop. No `Out of memory` line. Boot `0` started 17:53:00 and is the same libraries: every `Clutter-Actor.set_scale` is followed by two `Clutter-Actor.get_transition` calls, and `Clutter-Timeline.is_playing` / `pause` / `start` are absent while those scales are outside `emit`. Load on that boot was 3.25 at two minutes, `gsr-server` 24% and `gsr-client` 19%.

The hold is removed from `Signals.vala`, `namespace.vala`, and `Actor.override.vala`. The guest process is still the 17:50 binaries.

### 2026-10-15 gate/integration mismatch and void-signal boundary

The `pause-on-ease` gate manually performs `PAUSE` after `EASE` and `START`
after `HANDLER_DONE`. It does not link `Shell.Signals`, call
`Actor.set_scale`, exercise `emit_depth`, or cross the lazy C trampoline. It
therefore did not prove the integration that was copied into `src/`.

The copied integration intercepted every changed actor scale, not only DND.
Stock shell call sites include GDM timed-login/auth animations, panel,
window-manager effects, message list, dash, magnifier, workspace and app-grid
animations. Even when `emit_depth` was zero and no hold occurred, it added two
`get_transition` RPCs per `set_scale`. The guest logs prove that broad probing;
they do not isolate it as the cause of the startup failure.

`tests/call-sync-repro/blocking-void-signal-gate.vala` uses real libocrpc.
Direct run exited 1:

```text
FAIL blocking-void-signal-gate: blocking void signal was one-way tick=true reply-id=false observed-during-emit=false error=
```

`Subscription.emit` returns early when `return_value == null`; that is always
the GClosure shape for void signals. Thus setting `blocking = true` on
`before-update` cannot currently hold its emission. The dedicated bug is
[`2026-10-15-blocking-void-signal-does-not-wait.md`](2026-10-15-blocking-void-signal-does-not-wait.md).

### 2026-10-15 libocrpc fix and Weston proof

The OLLMchat build now waits for blocking void signals without writing a
boolean return through the null GClosure return slot. gnome-shell-rpc was
configured with:

```bash
meson configure build -Docrpc_libdir=/home/alan/gitlive/OLLMchat/build/libocrpc
```

`blocking-void-signal-gate` changed from the recorded FAIL to:

```text
PASS blocking-void-signal-gate: void signal waited for reply
```

Added `before-update` to `ClutterActor.vala`'s blocking subscription switch.
The full build passed. The signal-reentrancy suite reported 25 passes and 10
expected failures, with no unexpected failures or timeouts.

The overview drag smoke reached the forced 400ms gap:

```text
09:13:44.634  Clutter-Actor.get_transition id=19602
09:13:44.635  Clutter-Actor.get_transition id=19604
09:13:45.038  Clutter-Actor.get_transition id=19612
09:13:45.110  notification method=new-frame
09:13:45.120  overview-thumbnail-drag-smoke: after began=true inDrag=true dx=0
09:13:45.120  overview-thumbnail-drag-smoke: miss Error: miss preview-moved dx=0
```

The second read was 403ms after the transition was created and returned an
object. No `transition-gone` or `dnd.js:522` error occurred. This closes the
scale lifetime failure. The zero displacement is after `drag-begin` and after
`new-frame`; it is a separate drag-position failure.
