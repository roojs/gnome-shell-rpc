# Volume grab still owns the pointer when the microphone slider is used

**Status:** Open. Product code is unchanged. `src/client/libshell-16/Signals.vala` matches git HEAD. The code below is for discussion. It is not applied.

After a click on the volume slider, the next click still belongs to that slider. Dragging the microphone slider moves the volume slider. Output and input are separate sliders.

The small program that shows this is `tests/gjs-embed/slider-grab-smoke.js`. It puts two sliders on the stage, clicks the left one, then clicks the right one.

```bash
GI_META_SMOKE=slider-grab-smoke ./scripts/weston-gsr-prove.sh
```

## What is wrong

Gnome Shell's slider, on mouse down, calls `global.stage.grab(this)` and stores the result in `this._grab`. On mouse up it calls `this._grab.dismiss()`, which releases the pointer. In a normal session that grab call returns before the mouse-up handler runs, so the handler still has the grab and can dismiss it.

Here the mouse-up handler runs while that grab call is still waiting for its answer. `this._grab` is still empty, so the handler ends the drag and does not call dismiss. The grab call then returns, and the slider stores a grab that nothing dismisses. The next click is delivered to the volume slider.

The mouse-up is already on the socket because the press and the release are both written before the press handler returns. The grab call reads the socket while it waits, and the client emits that release as soon as it is read.

2026-10-09 15:39, product code unchanged. The log is `~/.cache/gnome-shell-rpc/nested-weston-prove.tee.log`. The run printed `slider-grab-smoke: miss left=0.5 right=0.2`. The right slider stayed at 0.2.

The client log, in order:

```text
left release beforeDrag=true beforeGrab=null afterDrag=false afterGrab=null
left press before=false after=false grab=set
```

The server received `Clutter-Stage.grab` id=120 after that release had already been handled. The second click then hit the left slider again (`beforeGrab=set`, `Clutter-Grab.dismiss` id=178, then another grab).

## Proposed fix

Not applied. The RPC library stores a bool the caller set. It does not mention Clutter. This server sets that bool when the signal it is subscribing takes a Clutter event. The client only reads the bool.

A notification without the bool is still emitted immediately. Replies are not notifications. The count is only how many marked handlers are on the stack. Mouse-up waits until the press handler returns, which is after the slider has stored the grab. The hold list is created the first time something waits.

### 1. `OLLMchat/libocrpc/Notification.vala` — the bool on the message

**Why:** The writer puts the mark on the message. The library does not decide what the mark means.

**Where:** On `Notification`, after `action_label`.

**Depends on:** none.

#### Add — after `public string action_label`

```vala
		/**
		 * True when the writer asked for this notification to be
		 * delivered one at a time.
		 *
		 * Copied from {@link Live.Subscription.ordered}. False
		 * unless that caller set it.
		 */
		public bool ordered { get; set; default = false; }
```

### 2. `OLLMchat/libocrpc/Live/Subscription.vala` — copy the caller's bool

**Why:** `emit` creates the notification. It copies the bool the caller stored on this subscription. It does not look at the signal or the arguments.

**Where:** Field on `Subscription`, and the `write` in `emit`.

**Depends on:** §1.

##### Part 1 — field

#### Add — after `public ulong hid`

```vala
		/**
		 * Copied onto each notification this subscription writes.
		 *
		 * The caller sets it before {@link connect}. This class
		 * does not.
		 */
		public bool ordered { get; set; default = false; }
```

##### Part 2 — the write

#### Remove

```vala
			subscription.connection.write(new Notification() {
				method = subscription.method,
				id = subscription.id,
				args = packed
			});
```

#### Replace with

```vala
			subscription.connection.write(new Notification() {
				method = subscription.method,
				id = subscription.id,
				args = packed,
				ordered = subscription.ordered
			});
```

### 3. `src/server/libmutter-clutter-16/ClutterActor.vala` — `add_signals()`

**Why:** This is the code that subscribes the signal, so this is where the bool is set. A signal whose argument is a Clutter event is one-at-a-time. Anything else stays false.

**Where:** The `new OLLMrpc.Live.Subscription` inside the name loop.

**Depends on:** §2.

#### Remove

```vala
			for (var i = 0; i < names.length; i++) {
				var subscription = new OLLMrpc.Live.Subscription() {
					connection = request.connection,
					method = names[i],
					id = (int) request.lease_id
				};
```

#### Replace with

```vala
			var obj = request.connection.leases.get((int) request.lease_id);
			for (var i = 0; i < names.length; i++) {
				var ordered = false;
				if (obj != null && !names[i].has_prefix("notify::")) {
					var signal_id = GLib.Signal.lookup(names[i], obj.get_type());
					if (signal_id != 0) {
						GLib.SignalQuery query;
						GLib.Signal.query(signal_id, out query);
						if (query.n_params > 0
								&& query.param_types[0].name() == "ClutterEvent") {
							ordered = true;
						}
					}
				}
				var subscription = new OLLMrpc.Live.Subscription() {
					connection = request.connection,
					method = names[i],
					id = (int) request.lease_id,
					ordered = ordered
				};
```

### 4. `src/client/libshell-16/Signals.vala` — fields on `Signals`

**Why:** Marked notifications that arrive during another marked one have to wait. The list is created on first use. The count is only those marked handlers.

**Where:** After `notification_hooked`.

**Depends on:** §1.

#### Add — after `private static bool notification_hooked = false;`

```vala
		/**
		 * Marked handlers currently inside {@link emit}.
		 *
		 * While this is non-zero, another notification with
		 * {@link OLLMrpc.Notification.ordered} waits in
		 * {@link held_events}. Other notifications are emitted
		 * immediately.
		 */
		private static int event_depth = 0;

		/**
		 * Marked notifications that arrived during {@link event_depth}.
		 *
		 * Null until the first one waits. Run when the outer marked
		 * handler returns.
		 */
		private static Gee.ArrayList<OLLMrpc.Notification>? held_events;

		/**
		 * True while the outer marked handler is running {@link held_events}.
		 */
		private static bool draining_events = false;
```

### 5. `src/client/libshell-16/Signals.vala` — `connect()` notification handler

**Why:** A marked notification that arrives during another marked one is stored. Anything else is emitted now.

**Where:** The `notification.connect` callback, after the lease check, before `Signals.emit`.

**Depends on:** §4.

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
					if (notif.ordered && Signals.event_depth > 0) {
						if (Signals.held_events == null) {
							Signals.held_events = new Gee.ArrayList<OLLMrpc.Notification>();
						}
						Signals.held_events.add(notif);
						return;
					}
					var target = Gsr.Client.Rpc.client.proxies.get(notif.id);
					Signals.emit(target, notif.method, notif.args, notif.ordered);
```

### 6. `src/client/libshell-16/Signals.vala` — `emit()`

**Why:** The count covers the marked handler, including the grab call and the assignment after it returns. Mouse-up that was waiting runs after this call returns. Unmarked signals do not touch the count.

**Where:** The `emit` signature, the start of the body, the parse-failure return, and the line after `release_params`.

**Depends on:** §4 and §5.

##### Part 1 — signature and count

#### Remove

```vala
		private static void emit(
			GLib.Object obj,
			string signal_name,
			Gee.ArrayList<GLib.Value?> args
		) {
			uint signal_id = 0;
```

#### Replace with

```vala
		private static void emit(
			GLib.Object obj,
			string signal_name,
			Gee.ArrayList<GLib.Value?> args,
			bool ordered
		) {
			if (ordered) {
				Signals.event_depth++;
			}
			uint signal_id = 0;
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
				if (ordered) {
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
			if (!ordered) {
				return;
			}
			Signals.event_depth--;
			if (Signals.event_depth > 0 || Signals.draining_events
					|| Signals.held_events == null) {
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
				Signals.emit(target, notif.method, notif.args, notif.ordered);
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

2026-10-09 16:53. Removed the written proposal. It had the client detect a Clutter event in the notification, a static list created in the field declaration, a process-wide hold on signals, and a Clutter event check inside the RPC library. All of that was rejected. Product code was not changed.

2026-10-09 16:55. Put a discussion draft back in the bug. The RPC library only copies a bool the caller set. This server sets that bool for a signal whose argument is a Clutter event. The client only reads the bool. Not applied.
