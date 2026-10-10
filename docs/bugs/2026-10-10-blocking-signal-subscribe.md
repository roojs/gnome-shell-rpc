# Blocking signal subscribe

**Status:** Applied in this tree and built. `Shell.Signals.connect` always calls `Gsr-Clutter-Actor.add_signals`. `add_signals` sets `Subscription.blocking` for the hand list. `LiveCallback.reply` marks the mailbox when `reply_id` matches and `Hook.complete` does not. `Shell.Signals.emit` returns the handler bool for a `BOOLEAN` signal, and the notification handler sends it on `RPC-Live-Callback.reply` when `reply_id` is non-zero. `emitv`'s fourth argument is `void*`, so that call passes `&ret` for a boolean return and `null` otherwise. `GLib.Value` cannot be inited from `G_TYPE_NONE`.

`Shell.Signals.connect` sends every name through `Gsr-Clutter-Actor.add_signals`, one array, including a single name. `add_signals` is hand-written. A hand list there sets `blocking` on `OLLMrpc.Live.Subscription` when that object is created. When `blocking` is set, `emit` waits the way `OLLMrpc.Live.Hook.emit` waits, and the client sends the handler bool back on `RPC-Live-Callback.reply` before that wait ends. `rpc_signal` is not on this path. The `action` / `no_hooks` / `watch_signal` writeup is withdrawn.

`Subscription.blocking` and `Notification.reply_id` are [Subscription.emit drops the handler bool](../../../OLLMchat/docs/bugs/2026-10-10-subscription-emit-drops-handler-bool.md). The client reply is in this tree.

The volume click that needs this is [Volume slider](done/2026-10-08-volume-slider-drawing.md). The 08:50 `slider-click-smoke` miss (`presses=0`) is a pointer miss on that bug, not this one.

## Proposed changes

`ClickAction` does not extend `Clutter.Actor` (`Action`, then `ActorMeta`). `.connect('long-press')` still reaches `add_signals` with that lease. `long-press` is in the same hand list. The list runs once, when the subscription is created.

### 1. `src/client/libshell-16/Signals.vala` — one `add_signals` call

**Why:** One name and many names are the same registration. `rpc_signal` is not this path.

**Where:** `connect`, the call after `signal_names` is chosen. The comments that still say one name is `rpc_signal`.

**Depends on:** none.

#### Remove

```vala
 * class records the name, tells the server
 * {@code RPC-Live-Subscribe.rpc_signal}, and re-emits on Notification.
```

#### Replace with

```vala
 * class records the name, tells the server
 * {@code Gsr-Clutter-Actor.add_signals}, and re-emits on Notification.
```

#### Remove

```vala
		 * First connect of a name sends ''RPC-Live-Subscribe.rpc_signal''.
```

#### Replace with

```vala
		 * First connect of a name sends ''Gsr-Clutter-Actor.add_signals''.
```

#### Remove

```vala
		 * list. More than one name is one ''Gsr-Clutter-Actor.add_signals''.
		 * One name is ''RPC-Live-Subscribe.rpc_signal''.
```

#### Replace with

```vala
		 * list. Every connect sends that array as
		 * ''Gsr-Clutter-Actor.add_signals''. One name is still an array.
```

#### Remove

```vala
		 * The list is cleared first. More than one name is one
		 * ''Gsr-Clutter-Actor.add_signals''. One name is
		 * ''RPC-Live-Subscribe.rpc_signal''. A name already in
```

#### Replace with

```vala
		 * The list is cleared first. The array, one name or many, is
		 * one ''Gsr-Clutter-Actor.add_signals''. A name already in
```

#### Remove

```vala
			if (signal_names.length > 1) {
				Gsr.Client.Rpc.call_value("Gsr-Clutter-Actor.add_signals", obj,
					OLLMrpc.args("S", signal_names));
			} else {
				Gsr.Client.Rpc.call_value("RPC-Live-Subscribe.rpc_signal", obj,
					OLLMrpc.args("s", signal_names[0]));
			}
```

#### Replace with

```vala
			Gsr.Client.Rpc.call_value("Gsr-Clutter-Actor.add_signals", obj, OLLMrpc.args("S", signal_names));
```

### 2. `src/server/libmutter-clutter-16/ClutterActor.vala` — hand list sets `blocking`

**Why:** `add_signals` is hand-written. The bool-return names are a switch in that method. `long-press` is on `ClickAction` and uses the same lease id.

**Where:** `add_signals`, the loop that builds each `Subscription`.

**Depends on:** `blocking` on `OLLMrpc.Live.Subscription` in [Subscription.emit drops the handler bool](../../../OLLMchat/docs/bugs/2026-10-10-subscription-emit-drops-handler-bool.md).

#### Remove

```vala
		 * replies once after the list. An empty name or a missing
		 * lease is ''-32602'' and no success reply.
```

#### Replace with

```vala
		 * replies once after the list. An empty name or a missing
		 * lease is ''-32602'' and no success reply. A name in the
		 * switch sets {@link OLLMrpc.Live.Subscription.blocking}.
```

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
			for (var i = 0; i < names.length; i++) {
				var subscription = new OLLMrpc.Live.Subscription() {
					connection = request.connection,
					method = names[i],
					id = (int) request.lease_id
				};
				switch (names[i]) {
					case "button-press-event":
					case "button-release-event":
					case "captured-event":
					case "enter-event":
					case "event":
					case "key-press-event":
					case "key-release-event":
					case "leave-event":
					case "motion-event":
					case "scroll-event":
					case "touch-event":
					case "long-press":
						subscription.blocking = true;
						break;

					default:
						break;
				}
```

`Subscription.emit` and `Notification.reply_id` are [Subscription.emit drops the handler bool](../../../OLLMchat/docs/bugs/2026-10-10-subscription-emit-drops-handler-bool.md). `Hook.complete` returns false for that wait, because it has no frame. The next edit marks the mailbox replied.

### 3. `src/server/rpc/LiveCallback.vala` — `reply` completes the mailbox

**Why:** `reply` today only walks `connection.callbacks` and calls `Hook.complete`. The mailbox in `Subscription.emit` is one of those rows, but nothing sets `replied` unless `complete` runs. `Hook.complete` returns false when the correlation is not one of its frames. This wait has no frame. Set `replied` and `reply_args` on a row whose `reply_id` matches.

**Where:** `reply`, the loop over `callbacks`.

**Depends on:** the mailbox in [Subscription.emit drops the handler bool](../../../OLLMchat/docs/bugs/2026-10-10-subscription-emit-drops-handler-bool.md).

#### Remove

```vala
			foreach (var id in request.connection.callbacks.keys) {
				var row = request.connection.callbacks.get(id);
				if (!row.complete(correlation, values)) {
					continue;
				}
```

#### Replace with

```vala
			foreach (var id in request.connection.callbacks.keys) {
				var row = request.connection.callbacks.get(id);
				if (row.complete(correlation, values)) {
					if (error_code != 0) {
						request.connection.reply_error(request, error_code);
						return;
					}
					request.reply(new OLLMrpc.Response());
					return;
				}
				if (row.reply_id != correlation) {
					continue;
				}
				row.reply_args.clear();
				foreach (var arg in values) {
					row.reply_args.add(arg);
				}
				row.replied = true;
```

### 4. `src/client/libshell-16/Signals.vala` — send the bool back

**Why:** The notification handler emits the local signal and drops the result (`emitv` is passed `null`). A `reply_id` means the server is inside `emit` until `RPC-Live-Callback.reply` arrives. The bool is the signal return from that `emitv`.

**Where:** the `notification.connect` handler inside `connect`, and `emit`.

**Depends on:** `Notification.reply_id` in [Subscription.emit drops the handler bool](../../../OLLMchat/docs/bugs/2026-10-10-subscription-emit-drops-handler-bool.md).

#### Remove

```vala
					Signals.emit(target, notif.method, notif.args);
```

#### Replace with

```vala
					if (notif.reply_id == 0) {
						Signals.emit(target, notif.method, notif.args);
					} else {
						Gsr.Client.Rpc.call_value("RPC-Live-Callback.reply", null,
							OLLMrpc.args("tb", (uint64) notif.reply_id,
								Signals.emit(target, notif.method, notif.args)));
					}
```

#### Remove

```vala
		private static void emit(
			GLib.Object obj,
			string signal_name,
			Gee.ArrayList<GLib.Value?> args
		) {
```

#### Replace with

```vala
		private static bool emit(
			GLib.Object obj,
			string signal_name,
			Gee.ArrayList<GLib.Value?> args
		) {
```

#### Remove

```vala
			Signals.emitv(vals, signal_id, detail, null);
```

#### Replace with

```vala
			var ret = GLib.Value(GLib.Type.BOOLEAN);
			if (query.return_type == GLib.Type.BOOLEAN) {
				Signals.emitv(vals, signal_id, detail, &ret);
			} else {
				Signals.emitv(vals, signal_id, detail, null);
			}
```

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
				return false;
			}
```

#### Add — at the end of `emit`, before the closing brace

The vfunc `closure.invoke` above stays. The bool is the one `emitv` collected.

```vala
			return query.return_type == GLib.Type.BOOLEAN && ret.get_boolean();
```

## LLM efforts

2026-10-10. Split out of [Volume slider](done/2026-10-08-volume-slider-drawing.md). The slider bug keeps the paint hook and the 08:50 coordinate miss. This file is the subscribe proposal: one `add_signals` path, a hand list in that method, and a `blocking` property on `OLLMrpc.Live.Subscription` set when the subscription is created. No `src/` edit.

2026-10-10. Replaced the subscribe sketch with the three edits above. No `src/` edit.

2026-10-10. The name list stays a switch in `add_signals`. Case labels are indented with the rest of the server switches. `blocking` is read in `Subscription.emit`: a non-zero `Notification.reply_id` makes the client send the handler bool on `RPC-Live-Callback.reply`, and `emit` waits for that before it writes `return_value`. No `src/` edit.

2026-10-10. Proposal code: no single-use locals (`blocking`, `correlation`, `stop`). `add_signals` is one `call_value`. The reply call wraps only because the nested `emit` does not fit on that line. No `src/` edit.

2026-10-10. `Subscription` and `Notification` moved to the OLLMchat bug [Subscription.emit drops the handler bool](../../../OLLMchat/docs/bugs/2026-10-10-subscription-emit-drops-handler-bool.md). The RPC-1.12 plan file is deleted. No `src/` edit.

2026-10-10. Applied the four hunks. `emitv` is bound as `void*`, so `ref ret` does not compile, and a void signal is not a `GValue`. Boolean returns pass `&ret`. The tree builds against the installed libocrpc that already has `Subscription.blocking` and `Notification.reply_id`.
