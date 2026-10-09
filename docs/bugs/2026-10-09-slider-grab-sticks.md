# Volume grab still owns the pointer when the microphone slider is used

**Status:** Open. Product code is unchanged. `src/client/libshell-16/Signals.vala` matches git HEAD.

After a click on the volume slider, the next click still belongs to that slider. Dragging the microphone slider moves the volume slider.

The small program that shows this is `tests/gjs-embed/slider-grab-smoke.js`. It puts two sliders on the stage, clicks the left one, then clicks the right one.

```bash
GI_META_SMOKE=slider-grab-smoke ./scripts/weston-gsr-prove.sh
```

2026-10-09 15:39, product code unchanged. The log is `~/.cache/gnome-shell-rpc/nested-weston-prove.tee.log`. The run printed `slider-grab-smoke: miss left=0.5 right=0.2`.

## What the log shows

Gnome Shell's slider, on mouse down, calls `global.stage.grab(this)` and stores the result in `this._grab`. On mouse up it calls `this._grab.dismiss()`, which releases the pointer. In a normal session that grab call returns before the mouse-up handler runs, so the handler still has the grab and can dismiss it.

In this run the mouse-up handler ran while the grab call was still waiting for its answer. `this._grab` was still empty, so the handler ended the drag and did not call dismiss. The grab call then returned, and the slider stored a grab that nothing dismisses. The second click was delivered to the left slider. The right slider stayed at 0.2.

The client log, in order:

```text
left release beforeDrag=true beforeGrab=null afterDrag=false afterGrab=null
left press before=false after=false grab=set
```

The server received `Clutter-Stage.grab` id=120 after that release had already been handled. The second click then hit the left slider again (`beforeGrab=set`, `Clutter-Grab.dismiss` id=178, then another grab).

## Proposed fix

Not applied. `Shell.Signals` re-emits a notification as soon as the grab call reads it. An input event is a notification whose arguments include `Gsr.Shared.ClutterEventState`. That is the mark from Clutter's event dispatch. No signal name is checked.

While one of those is being handled, the next one waits. Replies and hook callbacks are not notifications of that shape, so they still run. `slider-grab-smoke` passes when the left press stores the grab, the left release then clears it, and the right press is the right slider.

### 1. `src/client/libshell-16/Signals.vala` — fields on `Signals`

**Why:** The wait needs a count and a list. The count is the situation. The list is the input events that arrived during it.

**Where:** After `notification_hooked`.

**Depends on:** none.

#### Add — after `private static bool notification_hooked = false;`

The count, the list, and the drain flag.

```vala
		/**
		 * Input-event emissions currently inside {@link emit}.
		 *
		 * A notification that carries {@link Gsr.Shared.ClutterEventState}
		 * is an input event. While this count is non-zero, another such
		 * notification waits in {@link held_events}.
		 */
		private static int event_depth = 0;

		/**
		 * Input events that arrived during {@link event_depth}.
		 *
		 * Run when the outer event emission returns.
		 */
		private static Gee.ArrayList<OLLMrpc.Notification> held_events
			= new Gee.ArrayList<OLLMrpc.Notification>();

		/**
		 * True while the outer event emission is running {@link held_events}.
		 */
		private static bool draining_events = false;
```

### 2. `src/client/libshell-16/Signals.vala` — `connect()` notification handler

**Why:** This is where a socket read becomes a signal. An input event that arrives during another input event is stored. Anything else is still emitted now.

**Where:** The `notification.connect` callback, after the lease check, before `Signals.emit`.

**Depends on:** §1.

#### Remove

```vala
					if (!Gsr.Client.Rpc.client.proxies.has_key(notif.id)) {
						return;
					}
					var target = Gsr.Client.Rpc.client.proxies.get(notif.id);
					Signals.emit(target, notif.method, notif.args);
```

#### Replace with

```vala
					if (!Gsr.Client.Rpc.client.proxies.has_key(notif.id)) {
						return;
					}
					if (Signals.event_depth > 0
							&& Signals.event_args(notif.args)) {
						Signals.held_events.add(notif);
						return;
					}
					var target = Gsr.Client.Rpc.client.proxies.get(notif.id);
					Signals.emit(target, notif.method, notif.args);
```

### 3. `src/client/libshell-16/Signals.vala` — `event_args()`

**Why:** The group is "this notification carries a Clutter event", not a method name.

**Where:** New method, immediately above `emit()`.

**Depends on:** none.

#### Add — immediately above `private static void emit(`

True when any argument is a `Gsr.Shared.ClutterEventState`.

```vala
		/**
		 * True when ''args'' carries one {@link Gsr.Shared.ClutterEventState}.
		 *
		 * That object is what the server writes for an input event.
		 *
		 * @param args notification arguments
		 * @return true when one argument is that object
		 */
		private static bool event_args(Gee.ArrayList<GLib.Value?> args)
		{
			if (args == null) {
				return false;
			}
			foreach (var arg in args) {
				if (arg == null || !arg.holds(typeof(GLib.Object))) {
					continue;
				}
				if (arg.get_object() is Gsr.Shared.ClutterEventState) {
					return true;
				}
			}
			return false;
		}
```

### 4. `src/client/libshell-16/Signals.vala` — `emit()`

**Why:** The count covers the handler. Mouse-up that was waiting runs after this call returns, which is after the slider has stored the grab. No `try`.

**Where:** Start of `emit()`, the parse-failure return, and the line after `release_params`.

**Depends on:** §1 and §3.

##### Part 1 — count

#### Add — first lines inside `emit()`, before `uint signal_id`

Raise the count for an input event.

```vala
			var input = Signals.event_args(args);
			if (input) {
				Signals.event_depth++;
			}
```

##### Part 2 — parse failure

#### Remove

```vala
			if (!GLib.Signal.parse_name(signal_name, obj.get_type(), out signal_id, out detail, false)
					|| signal_id == 0) {
				return;
			}
```

#### Replace with

```vala
			if (!GLib.Signal.parse_name(signal_name, obj.get_type(), out signal_id, out detail, false)
					|| signal_id == 0) {
				if (input) {
					Signals.event_depth--;
				}
				return;
			}
```

##### Part 3 — run what waited

#### Remove

```vala
			OLLMrpc.Bin.TypeOverride.release_params(query.param_types);
		}
```

#### Replace with

```vala
			OLLMrpc.Bin.TypeOverride.release_params(query.param_types);
			if (!input) {
				return;
			}
			Signals.event_depth--;
			if (Signals.event_depth > 0 || Signals.draining_events) {
				return;
			}
			Signals.draining_events = true;
			while (Signals.held_events.size > 0) {
				var notif = Signals.held_events.get(0);
				Signals.held_events.remove_at(0);
				if (Signals.subs == null
						|| !Signals.subs.has_key(notif.id)
						|| !Signals.subs.get(notif.id).has_key(notif.method)) {
					continue;
				}
				if (!Gsr.Client.Rpc.client.proxies.has_key(notif.id)) {
					continue;
				}
				var target = Gsr.Client.Rpc.client.proxies.get(notif.id);
				Signals.emit(target, notif.method, notif.args);
			}
			Signals.draining_events = false;
		}
```

## LLM efforts

2026-10-09 15:36. The nested session the user had been using was already gone. `weston-autolaunch-prove.log` was last written at 15:27, when Weston started, and it has no grab line and no button-release line. The debug logs were last written at 15:22 by the drawing-area smoke (`drawing-area-reenter-smoke: quit (ok)`). Product code was not changed.

2026-10-09 15:39. Ran the smoke above with product code unchanged. Result is the status section.

2026-10-09 15:44. Changed `Signals.vala` so it would hold input signals, and wrapped the emit function in `try`. That was a guess. The smoke then released the grab on the left slider, but the second click never arrived as a button press, and the line was still `miss left=0.5 right=0.2`. The `try` was rejected. `Signals.vala` was restored.

2026-10-09 15:51. Moved the right slider to x=280 and ran the smoke again without rebuilding. The binary was still the 15:44 one. The second click did land at x=390 and the right slider's press and release ran, but only after the smoke had already printed `miss`. This run does not count as product code unchanged.

2026-10-09 15:53. Rebuilt another hold inside `Signals.emit`. The left slider stored the grab and then dismissed it, and the right slider did the same. Values ended at left=0.5 and right=0.5. The smoke still printed `miss` because it recorded the left value before the press handler had updated it (`leftAfter=0.2`). Editing the shared signal code was rejected. `Signals.vala` is restored to git HEAD.
