# Overview thumbnail drag

**Status:** ✅ closed 2026-10-18. Signed off on the desktop. Dropping a window preview on another workspace thumbnail moves the window, and the picture in the old place is gone.

**Cause:** Stage `get_actor_at_pos` picks in the compositor. `Shell.util_set_hidden_from_pick` stopped `pick` only on the client proxy, so the drop hit the dragged preview and `acceptDrop` treated it as the window's own workspace. After the move worked, `Meta.Compositor.get_window_actors` minted a new `Meta.Window` for a lease the preview already held. `window-removed` carried that new object, `===` missed the preview, and `restoreOnSuccess` eased it back to the old slot.

**Fix:** `Gsr-Clutter-Actor.hidden` stores bool `shell-hidden-from-pick`. One `pick` class handler, installed when the server registers, skips that actor while the bool is set and chains to the original pick when the key is gone. `Shell.util_set_hidden_from_pick` calls that RPC. `get_window_actors` and `list_all_windows` return the proxy already stored for the lease.

**Proof:** `overview-drop-workspace-smoke` printed `ok` (`pick-hidden hit=pick-bottom`, `change_workspace_by_index index=1`). The leftover preview was signed off on the desktop 2026-10-18.

```bash
GI_META_SMOKE=overview-drop-workspace-smoke \
GI_META_SMOKE_CMD='gedit --new-window' \
GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
GSR_NESTED_TIMEOUT=90 \
./scripts/agent-nested-smoke-prove.sh
```

The old long log is
[`2026-10-12-overview-thumbnail-drag.md`](2026-10-12-overview-thumbnail-drag.md).

## Proposal

The 18:04 smoke passed by wrapping `get_actor_at_pos` in the test. That
wrapper is gone.

Stage pick runs in the compositor. The drag preview is a stock
`St.Widget` and the window picture is a stock `Clutter.Clone`, so an
`Actor` constructor never runs for them. The handler is installed once
at register. `hidden` only stores or removes the bool.

Clutter emits `pick` only when a handler is pending
(`clutter_actor_continue_pick`). An emission hook is not a handler, so
the vfunc runs and the hook never sees the pick. GLib also rejects
`g_signal_stop_emission` from an emission hook. The register-time
class handler is pending for every actor. A set bool returns. A missing
bool chains to the original pick.

### `src/server/libmutter-clutter-16/ClutterActor.vala` — register the handler

**Why:** `get_actor_at_pos` runs in this process. One class handler at register covers every actor, including stock widgets and clones.

**Where:** `Actor.rpc_register`, and the `"hidden"` entry in `add_class`.

**Depends on:** nothing

#### Remove

```vala
				"add_signals", "S",
				"add_properties", "",
```

#### Replace with

```vala
				"add_signals", "S",
				"hidden", "b",
				"add_properties", "",
```

#### Remove

```vala
			OLLMrpc.Request.register_live("Gsr-Clutter-Actor", helper);
			ActorVfuncIds.register_vfunc_ids();
```

#### Replace with

```vala
			OLLMrpc.Request.register_live("Gsr-Clutter-Actor", helper);
			ActorVfuncIds.register_vfunc_ids();
			/* get_actor_at_pos picks in this process. The drag actor is a
			 * stock St.Widget and the window picture is a stock Clone, so
			 * an Actor constructor never runs for them. Clutter emits
			 * pick only when a handler is pending, and an emission hook
			 * is not one. One class handler here covers every actor.
			 * shell-hidden-from-pick set means skip this pick; the key
			 * removed means chain to the original handler. */
			GLib.Signal.override_class_handler("pick", typeof(global::Clutter.Actor), (GLib.Callback) pick_hidden);
```

### `src/server/libmutter-clutter-16/ClutterActor.vala` — set or remove the key

**Why:** The class handler is already installed. This call only puts the bool on the actor or takes it off.

**Where:** `Actor.add_signals`, after its reply.

**Depends on:** the class handler and the `add_class` entry above

#### Add

```vala
		/**
		 * Class handler installed once from {@link rpc_register}.
		 * A set {@code shell-hidden-from-pick} skips this actor.
		 * Otherwise the original pick runs.
		 */
		static void pick_hidden(global::Clutter.Actor actor, global::Clutter.PickContext pick_context)
		{
			if (actor.get_data<bool>("shell-hidden-from-pick")) {
				return;
			}
			GLib.Signal.chain_from_overridden_handler(actor, pick_context);
		}

		/**
		 * ''Gsr-Clutter-Actor.hidden'' — set or remove
		 * {@code shell-hidden-from-pick} on the leased actor.
		 *
		 * The pick class handler is already installed. This call
		 * only stores the bool or removes it.
		 *
		 * @param request inbound RPC; lease is the actor
		 * @param hidden true stores the bool, false removes the key
		 */
		public void hidden(OLLMrpc.Request request, bool hidden)
		{
			var actor = request.connection.leases.get((int) request.lease_id) as global::Clutter.Actor;
			if (actor == null) {
				request.connection.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			if (hidden) {
				actor.set_data<bool>("shell-hidden-from-pick", true);
			} else {
				actor.steal_data<bool>("shell-hidden-from-pick");
			}
			request.reply(new OLLMrpc.Response());
		}
```

### `src/client/libshell-16/Util.vala` — ask the compositor to stop pick

**Why:** `Shell.util_set_hidden_from_pick` is what `dnd.js` and the window clone call. The connect has to be the server one above.

**Where:** `util_set_hidden_from_pick` and `stop_pick`.

**Depends on:** `Gsr-Clutter-Actor.hidden`

#### Remove

```vala
	public void util_set_hidden_from_pick(Clutter.Actor actor, bool hidden)
	{
		const string key = "shell-stop-pick";
		if (hidden) {
			if (actor.get_data<void*>(key) != null) {
				return;
			}
			actor.signal_pick.connect(stop_pick);
			actor.set_data(key, (void*) 0x1);
		} else {
			if (actor.get_data<void*>(key) == null) {
				return;
			}
			actor.signal_pick.disconnect(stop_pick);
			actor.set_data(key, null);
		}
	}

	static void stop_pick(Clutter.Actor actor, Clutter.PickContext pick_context)
	{
		GLib.Signal.stop_emission_by_name(actor, "pick");
	}
```

#### Replace with

```vala
	public void util_set_hidden_from_pick(Clutter.Actor actor, bool hidden)
	{
		try {
			Gsr.Client.Rpc.call_value("Gsr-Clutter-Actor.hidden", actor, OLLMrpc.args("b", hidden));
		} catch (GLib.Error e) {
			GLib.warning("hidden: %s", e.message);
		}
	}
```

Applied. `installPickSkip` is gone. The smoke still records
`get_actor_at_pos` so the pointer can steer, and it does not hide
actors. The check is that smoke without the hide wrapper.

The sustained motion smoke is:

```bash
GI_META_SMOKE=overview-thumbnail-drag-smoke \
GI_META_SMOKE_CMD='gedit --new-window' \
GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
GSR_NESTED_TIMEOUT=90 \
./scripts/agent-nested-smoke-prove.sh
```

16:22, `nested-weston-prove: stop (smoke-fail) after 12s`:

```text
overview-thumbnail-drag-smoke: motion offset=20 dx=93.22265625
overview-thumbnail-drag-smoke: motion offset=40 dx=93.22265625
...
overview-thumbnail-drag-smoke: motion offset=200 dx=93.22265625
overview-thumbnail-drag-smoke: after began=true inDrag=true dx=93.22265625
overview-thumbnail-drag-smoke: miss Error: miss drag-end ended=false inDrag=true
```

`Clutter-Actor.set_position` stops at 16:22:44.698. Virtual motion continues
until the release at 16:22:45.509. Each of those later `event` notifications
is answered with no further RPC. `dnd.js::_onEvent()` returns before
`_updateDragPosition()` and `_dragActorDropped()` when
`event.get_device() !== this._grabbedDevice`. Both unpack paths construct a
new client `InputDevice` from `device_type` alone:
`Event.read_scroll_tail()` for `get_current_event()`, and
`Event.apply_state()` for the `event` signal.

The in-preview case failed because client GJS gesture subclasses were
represented by a stock server `ClutterGestureAction`. Their GJS
`vfunc_gesture_prepare()` overrides never ran. The stock capture actions
therefore consumed post-press pointer motion before the stage, preview, and
DND click action received it. Disabling all six stage gesture actions for
one diagnostic run made the same reproduction pass with
`began=true inDrag=true dx=93.22`. Disabling only all four `swipe` actions,
only `unfullscreen`, or only `osk` still failed. This was class-vfunc
parity, not a special case for one named shell gesture.

## Remaining failure: motion stays inside the preview

A press followed by a move that remains on the overview preview reports
`began=false inDrag=false dx=0`. The filter sees the expected coordinates,
but the implicit-grab chain reaches capture-phase stage gesture actions
before actor capture. The server peers are stock `ClutterGestureAction`
objects, so the GJS subclass preparation checks are absent and actor
delivery stops:

```text
12:12:51.637  button press on the preview
12:12:51.641  notification method=long-press
12:12:51.737  one actor type=3 cluster, then no further preview motion
              backend motions continue from x=327 to x=586

overview-thumbnail-drag-smoke: after began=false inDrag=false dx=0
overview-thumbnail-drag-smoke: miss Error: miss drag-begin
nested-weston-prove: stop (smoke-fail) after 11s
```

Moving outside the preview is different: it emits leave, the copied
`open_event` supplies the long-press cancel event, and drag starts.

The 12:00 diagnostic run narrowed the loss. Every post-press virtual motion
arrived outside an RPC signal wait (`emit-depth=0`), became backend raw
motion, and entered the global Clutter filter as `type=3` with
`queued_flush_depth=0`. A later diagnostic identified the target as the
server peer for the preview itself
(`GsrServerClutterActor`, client type
`Gjs_ui_windowPreview_WindowPreview`). No actor `type=3` followed:

```text
12:00:49.136  notify_absolute_motion emit-depth=0
12:00:49.137  raw motion
12:00:49.137  event filter type=3 flush-depth=0
12:00:49.237  notify_absolute_motion emit-depth=0
12:00:49.238  raw motion
12:00:49.238  event filter type=3 flush-depth=0
...
12:00:49.648  after began=false inDrag=false dx=0
```

This disproves the nested `Connection.emit_wait_poll()` and queue-flush
theories. Mutter's event-emission chain puts capture actions before each
actor. The six named stage actions are `unfullscreen`, four `swipe` actions,
and `osk`; each is a GJS `Clutter.GestureAction` subclass on the client but a
stock base action on the server.

The off-code Clutter control without that filter passes:

```text
PASS clutter-drag-leave-gate inside-no-filter: motion cancel type=3 count=1
```

## Implemented fix

The all-stage-actions-disabled diagnostic proves that preserving the GJS
gesture subclass vfuncs is the relevant strategy. It is not the proposed
product behavior: stage gestures must remain enabled. The proposal gives
`Clutter.GestureAction` the same client-subclass/server-helper split already
used by `Clutter.Actor` and `Clutter.LayoutManager`.

The stock client and wire class `Clutter.GestureAction` already exists. The
new Vala class below is only the missing server peer subclass. Its
`Gsr-Clutter-GestureAction` wire prefix is deliberate: `create` and
`add_hooks` are project RPC methods, not stock Clutter API. Registering them
under `Clutter-GestureAction` would make the stock wire class claim methods
that do not exist in the typelib.

### 1. `src/client/libmutter-clutter-rpc-16/Clutter.overrides` — generate GestureAction relay IDs

**Why:** the client and server must use the real typelib vfunc offsets for
all five `Clutter.GestureAction` class slots.

**Where:** the helper and relay declarations after `LayoutManager`.

**Depends on:** none.

#### Add — mark GestureAction as a helper and relay its five real vfuncs

```text
GestureAction helper=1
GestureAction.gesture_begin    relay=object-bool
GestureAction.gesture_progress relay=object-bool
GestureAction.gesture_end      relay=object-void
GestureAction.gesture_cancel   relay=object-void
GestureAction.gesture_prepare  relay=object-bool
```

### 1b. `src/client/libmutter-clutter-rpc-16/Clutter.deny` — suppress the stock constructor

**Why:** the generator's stock `GestureAction.new` construct would add a
second construct block and mint a stock peer. The helper construct owns
peer creation and hook registration.

#### Add

```text
GestureAction.new
```

### 2. `src/generator/Generator.vala` — generate simple object-argument relays

**Why:** all five client relay bodies are mechanical. The existing C
trampolines already call bool/void vfunc slots with one pointer argument.
The generator should emit these adapters instead of putting five wrappers
in `GestureAction.override.vala`.

**Where:** `emit_class_struct_slots()`, where `relay=1` is collected and
`bind_vfunc()` is emitted.

**Depends on:** §1.

##### Part 1 — accept typed relay policies

#### Remove

```vala
								&& this.overrides.get(symbol).get("relay") == "1") {
```

#### Replace with

```vala
								&& this.overrides.get(symbol).get("relay") != "") {
```

Apply the same replacement to the second relay-policy check later in
`emit_class_struct_slots()`:

#### Remove

```vala
						&& this.overrides.get(@"$(class_name).$(fname)").get("relay") == "1") {
```

#### Replace with

```vala
						&& this.overrides.get(@"$(class_name).$(fname)").get("relay") != "") {
```

##### Part 2 — emit object-bool and object-void callback adapters

#### Add — after the generated `bind_vfunc()` block and before helper-ID collection

```vala
				foreach (var rname in relayed) {
					var symbol = @"$(class_name).$(rname)";
					var relay = this.overrides.get(symbol).get("relay");
					var vala = this.vala_ident(rname);
					if (relay == "object-bool") {
						stream.puts(@"
		internal uint64 relay_$(vala)()
		{
			return Gsr.Client.Rpc.callback_bind((call) => {
				var argument = call.args.get(0).get_object();
				var result = Gsr.Client.Rpc.vfunc_call_bool_pointer(this,
					OLLMrpc.Gi.vfunc_offset(\"$(ns)\", \"$(class_name)\", \"$(rname)\"), (void*) argument);
				return OLLMrpc.args(\"b\", result);
			});
		}
");
						continue;
					}
					if (relay == "object-void") {
						stream.puts(@"
		internal uint64 relay_$(vala)()
		{
			return Gsr.Client.Rpc.callback_bind((call) => {
				var argument = call.args.get(0).get_object();
				Gsr.Client.Rpc.vfunc_call_void_pointer(this,
					OLLMrpc.Gi.vfunc_offset(\"$(ns)\", \"$(class_name)\", \"$(rname)\"), (void*) argument);
				return OLLMrpc.args(\"\");
			});
		}
");
					}
				}
```

Existing `relay=1` entries remain handwritten because their argument or
return packing is specialized.

### 3. `src/server/libmutter-clutter-16/ClutterGestureAction.vala` — add the server helper peer

**Why:** a stock server `ClutterGestureAction` uses base vfuncs instead of
the client GJS subclass overrides. The helper keeps stock behavior when a
slot is not overridden and blocks for the client result when it is.

**Where:** new file.

**Depends on:** §§1–2.

#### Add — create the complete helper class

```vala
/**
 * Clutter GestureAction peer for a client GJS subclass.
 * Class slots hook back to the client's real Clutter vfunc overrides.
 */
namespace Gsr.Server.Clutter
{
	public class GestureAction : global::Clutter.GestureAction
	{
		public Gee.HashMap<int, OLLMrpc.Live.Hook> vfuncs {
			get; set; default = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
		}

		public static void rpc_register()
		{
			var helper = new GestureAction();
			OLLMrpc.Request.add_class(
				"Gsr-Clutter-GestureAction", typeof(GestureAction),
				"create", "",
				"add_hooks", "v",
				null);
			OLLMrpc.Request.register_live("Gsr-Clutter-GestureAction", helper);
			GestureActionVfuncIds.register_vfunc_ids();
		}

		public void create(OLLMrpc.Request request)
		{
			var created = new GestureAction();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", (uint64) request.connection.export(created)),
			});
		}

		public void add_hooks(OLLMrpc.Request request, GLib.Variant vfunc_ids)
		{
			var created = request.connection.leases.get((int) request.lease_id) as GestureAction;
			if (created == null) {
				request.connection.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var n = (int) vfunc_ids.n_children();
			var ids = new GLib.VariantBuilder(new GLib.VariantType("at"));
			for (var i = 0; i < n; i++) {
				var id = request.connection.next_handle;
				request.connection.next_handle++;
				var hook = new OLLMrpc.Live.Hook() {
					connection = request.connection,
					id = id
				};
				request.connection.callbacks.set(id, hook);
				ids.add("t", (uint64) id);
				var vfunc_id = vfunc_ids.get_child_value(i).get_int32();
				created.vfuncs.set(vfunc_id, hook);
			}
			request.reply(new OLLMrpc.Response() {
				args = OLLMrpc.args("v", ids.end()),
			});
		}

		public override bool gesture_begin(global::Clutter.Actor actor)
		{
			var hook = this.vfuncs.get(GestureActionVfuncIds.gesture_begin_id);
			if (hook == null) {
				return base.gesture_begin(actor);
			}
			hook.emit(OLLMrpc.args("o", actor));
			if (hook.reply_args.size < 1) {
				return false;
			}
			return hook.reply_args.get(0).get_boolean();
		}

		public override bool gesture_progress(global::Clutter.Actor actor)
		{
			var hook = this.vfuncs.get(GestureActionVfuncIds.gesture_progress_id);
			if (hook == null) {
				return base.gesture_progress(actor);
			}
			hook.emit(OLLMrpc.args("o", actor));
			if (hook.reply_args.size < 1) {
				return false;
			}
			return hook.reply_args.get(0).get_boolean();
		}

		public override void gesture_end(global::Clutter.Actor actor)
		{
			var hook = this.vfuncs.get(GestureActionVfuncIds.gesture_end_id);
			if (hook == null) {
				return;
			}
			hook.emit(OLLMrpc.args("o", actor));
		}

		public override void gesture_cancel(global::Clutter.Actor actor)
		{
			var hook = this.vfuncs.get(GestureActionVfuncIds.gesture_cancel_id);
			if (hook == null) {
				return;
			}
			hook.emit(OLLMrpc.args("o", actor));
		}

		public override bool gesture_prepare(global::Clutter.Actor actor)
		{
			var hook = this.vfuncs.get(GestureActionVfuncIds.gesture_prepare_id);
			if (hook == null) {
				return base.gesture_prepare(actor);
			}
			hook.emit(OLLMrpc.args("o", actor));
			if (hook.reply_args.size < 1) {
				return false;
			}
			return hook.reply_args.get(0).get_boolean();
		}
	}
}
```

### 4. `src/client/libmutter-clutter-rpc-16/overrides/GestureAction.override.vala` — mint the helper

**Why:** GJS subclasses must construct the helper peer and bind the generated
relays only for vfunc slots they actually override.

**Where:** before the existing `enabled` property.

**Depends on:** §§1–3.

`construct` is intentional here. GJS creates several different subclasses,
so there is no single explicit constructor call to override. The
`rpc_lid != 0` branch prevents a deserialized proxy from minting a second
peer. The empty-hook branch covers an exact base `GestureAction`, and the
handler-map initialization is required before storing callback rows.

#### Add — construct the server peer and bind the real vfunc callbacks

```vala
	construct {
		if (this.rpc_lid != 0) {
			return;
		}
		Gsr.Client.Rpc.hook_rows = new Gee.ArrayList<Gsr.Client.Rpc.InvokeRow>();
		string[] always = {};
		var overridden = Gsr.Client.Rpc.VfuncRelay.overridden(
			this.get_type(), "Clutter", "GestureAction", typeof(GestureAction).name(), always);
		var vfunc_ids = new GLib.VariantBuilder(new GLib.VariantType("ai"));
		foreach (var name in overridden) {
			var vfunc_id = -1;
			var hook_id = this.bind_vfunc(name, out vfunc_id);
			if (hook_id == 0) {
				continue;
			}
			vfunc_ids.add("i", vfunc_id);
		}
		var response = Gsr.Client.Rpc.call_value("Gsr-Clutter-GestureAction.create");
		this.rpc_lid = response.args.get(0).get_uint64();
		Gsr.Client.Rpc.register_handle(this);
		if (Gsr.Client.Rpc.hook_rows.size == 0) {
			Gsr.Client.Rpc.hook_rows = null;
			return;
		}
		var hooks = Gsr.Client.Rpc.call_value(
			"Gsr-Clutter-GestureAction.add_hooks", this, OLLMrpc.args("v", vfunc_ids.end()));
		var ids = hooks.args.get(0).get_variant();
		if (Gsr.Client.Rpc.handlers == null) {
			Gsr.Client.Rpc.handlers = new Gee.HashMap<int, Gsr.Client.Rpc.InvokeRow>();
		}
		var n = (int) ids.n_children();
		for (var i = 0; i < n; i++) {
			var id = ids.get_child_value(i).get_uint64();
			Gsr.Client.Rpc.handlers.set((int) id, Gsr.Client.Rpc.hook_rows.get(i));
		}
		Gsr.Client.Rpc.hook_rows = null;
	}
```

### 5. `src/server/libmutter-clutter-16/namespace.vala` — register and alias the helper

**Why:** construction needs the custom live endpoint, and later stock
`Clutter-GestureAction.*` calls must dispatch against the helper lease.

**Where:** `rpc_register()`, beside the Actor and LayoutManager setup.

**Depends on:** §3.

#### Add — register the helper after Actor

```vala
		GestureAction.rpc_register();
```

#### Add — alias the helper type after the existing Clutter aliases

```vala
		OLLMrpc.Bin.register_alias(
			"Clutter-GestureAction", typeof(GestureAction));
```

### 6. `src/meson.build` — compile the helper

**Why:** the new server peer must be part of `gsr-server`.

**Where:** `compositor_sources`, after `ClutterLayoutManager.vala`.

**Depends on:** §3.

#### Add — include the new server source

```meson
  'server/libmutter-clutter-16/ClutterGestureAction.vala',
```

After implementation, the bar is the unchanged stay-inside Weston command
printing `began=true`, `inDrag=true`, and `ok`, followed by the off-preview
and click controls and the signal-reentrancy suite. No stage action may be
disabled in product code.

## 2026-10-17 implementation and proof

### First test: FAIL

The first unchanged stay-inside test did not reach its result assertion.
`gsr-server` crashed during the pointer sequence:

```text
overview-thumbnail-drag-smoke: drag 399.4765625,296.162109375
nested-weston-prove: mutter exited ec=139 after 9s
```

The same crash reproduced on the next diagnostic run. The core is for
`gsr-server`, not the client or `libocrpc`. GDB showed:

```text
#0 0x0
#1 Gsr.Server.Clutter.GestureAction.gesture_cancel
   ClutterGestureAction.vala:100
parent gesture_end=0x0 gesture_cancel=0x0
```

The helper called `base.gesture_cancel(actor)` when no client hook existed,
but stock `ClutterGestureActionClass.gesture_cancel` is NULL. Its
`gesture_end` slot is also NULL. This is the same invalid-base-vfunc shape
previously proved for `Helper.Actor.event`: Vala emits an indirect call
through the parent slot, and a NULL stock slot jumps to address zero.

The three boolean parent slots are non-NULL functions. The failure is
therefore specifically the void fallback calls, not callback transport,
signal reentrancy, or the generated vfunc offsets.

The missing cancel hook is an expected state. `VfuncRelay.overridden()`
only registers slots that differ from the stock client
`Clutter.GestureAction` class. GNOME Shell's `EdgeDragAction` overrides
prepare, progress, and end, but not cancel. Both the `unfullscreen` and
`osk` capture actions use `EdgeDragAction`, so either can legitimately
reach the helper's no-hook cancel path. `TouchSwipeGesture` does override
cancel. The core and existing logs do not identify which individual
server action emitted this cancel, so narrowing it further would require
new diagnostics.

The parent class contents confirm the stock fallback semantics:

```text
gesture_begin    = 0x7d27f73d66c0
gesture_progress = 0x7d27f73d66c0
gesture_end      = 0x0
gesture_cancel   = 0x0
gesture_prepare  = 0x7d27f73d66c0

0x7d27f73d66c0: mov $0x1,%eax
0x7d27f73d66c9: ret
```

Stock begin, progress, and prepare return true. Stock end and cancel have
no class handler and therefore mean no-op, not “call a parent function.”

### Subsequent correction and proof

`gesture_end` and `gesture_cancel` use their stock no-op behavior when the
client did not override them. The three boolean parent slots retain their
base fallback.

The rebuilt stay-inside reproduction passed without disabling any action:

```text
overview-thumbnail-drag-smoke: after began=true inDrag=true dx=93.22265625
overview-thumbnail-drag-smoke: ok
```

The off-preview control produced the same successful measurement. The
click control printed `overview-window-activate-smoke: ok`. The
signal-reentrancy suite completed with 25 passes, 10 expected failures,
zero failures, and zero timeouts.

## Rejected queue-flush candidate

The recursive queue flush was added in the same commit as the rejected
transition-hold experiment, but for the separate leave/motion investigation.
The crossing copy in that commit fixed the leave path. No result isolates
the recursive queue flush as necessary for that fix.

The standalone gate passes both with the current flush and without the
filter, so it does not reproduce the live distinction. Removing the
recursive flush while retaining `global::Clutter.Event.add_filter` and its
crossing copy was also tested on the real Weston smoke. It still printed
`began=false inDrag=false dx=0` and `miss drag-begin` at 12:58. The product
edit was reverted. This is not the fix.

## Rejected transition-hold experiment

The earlier scale-lifetime proposal added timeline storage, a
`hold_transition` trampoline, and extra RPC calls from `Actor.set_scale`.
It was removed after its gate failed to exercise that integration and its
guest installation regressed startup. None of those changes are part of the
current proposal. The investigation record remains below under
`2026-10-14 17:27 proposal`.

## What already landed

Click is fixed. Do not reopen it. `event-reschedule` is in `src/server/rpc/Server.vala` `filter_notification` and `src/server/rpc/Connection.vala` `write()`. A one-way `before-update` while `Clutter.get_current_event()` is set is consumed and `schedule_update()` is called. `overview-window-activate-smoke` printed `ok`. Plan [`docs/plans/1.4-signal-reentrancy.md`](../../plans/1.4-signal-reentrancy.md).

The leave cancel is fixed. Do not reopen it. `dnd.js:151` used to throw
`event is null` on long-press CANCEL.
`src/server/libmutter-clutter-16/Clutter.vala` copies that crossing into
`open_event` when `global::Clutter.get_current_event()` is null, and
`get_current_event` returns the copy. The 13:35 leave smoke printed
`after began=true inDrag=true dx=108.09375` and `ok` with no
`event is null`. That run was fast enough that `scale-x` was still alive.
It does not cover this hang.

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
- `before-update` is now blocking. The corrected libocrpc waits for blocking
  void signals without writing through a null GClosure return slot.
- Do not inhibit the frame clock for the whole drag. `new-frame` has to be connected, then the 250ms scale has to run.
- Do not hold every frame until `clicked`. That is the `event-no-click` failure. A drag has no `clicked`.
- Do not return STOP from the event filter. That drops the click sequence.
- Do not treat `drag-begin` alone as success. The 12:08 smoke printed `ok` while `dnd.js:522` threw.
- `ClutterBoxLayout` minimum height `-12` and `global.stage.context is null` are a different abort. The update menu and the expand overlap are different bugs.

## Where to start

The libocrpc fix and consumer `before-update` subscription are applied.
`get_transition` and `run_main_loop` are not consumer fix points. The
library-owned report is
[`2026-10-15-FIXED-blocking-void-signal-does-not-wait.md`](../../../../OLLMchat/docs/bugs/done/2026-10-15-FIXED-blocking-void-signal-does-not-wait.md).

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
`before-update` could not hold its emission before the library fix. The
library-owned report is
[`2026-10-15-FIXED-blocking-void-signal-does-not-wait.md`](../../../../OLLMchat/docs/bugs/done/2026-10-15-FIXED-blocking-void-signal-does-not-wait.md).

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
scale lifetime failure.

The zero displacement was a smoke error, not a product failure. The
threshold-crossing event is also the drag start point, where `dnd.js`
deliberately preserves the actor's original stage position. The harness now
sends a second motion after `startDrag()` returns. The rerun printed:

```text
10:04:10.647  Clutter-Actor.get_transition after the forced 400ms gap
10:04:10.714  notification method=new-frame
10:04:10.723  Clutter-Actor.set_position
10:04:10.930  overview-thumbnail-drag-smoke: after began=true inDrag=true dx=93.22265625
10:04:10.930  overview-thumbnail-drag-smoke: ok
10:04:10.930  overview-thumbnail-drag-smoke: done
              nested-weston-prove: stop (smoke-ok) after 11s
```

### 2026-10-15 click regression check

The first `overview-window-activate-smoke` run selected and focused the
window without starting a drag, but checked `overview.visible` at its fixed
three-second deadline and reported `miss overview-stayed`. A longer
reproduction showed that the overview completed hiding 3.24 seconds after
the click. The smoke now uses a configurable eight-second hide deadline.
The documented default run printed:

```text
11:37:48.328  overview-window-activate-smoke: click
11:37:51.752  after selected=true overview=false focus="Untitled Document 1 - gedit" inDrag=false
11:37:51.754  overview-window-activate-smoke: ok
               nested-weston-prove: stop (smoke-ok) after 16s
```

This covers the existing blocking `clicked` and `long-press` subscriptions
after the libocrpc correction made their configured wait effective.

### 2026-10-15 current in-preview reproduction

Added `GI_META_SMOKE_STAY_INSIDE=1` to select the existing in-preview path
without changing the default off-preview proof. With the corrected libocrpc,
two post-press motions still produced:

```text
11:42:12.423  overview-thumbnail-drag-smoke: drag
11:42:13.148  after began=false inDrag=false dx=0
11:42:13.149  miss Error: miss drag-begin
               nested-weston-prove: stop (smoke-fail) after 15s
```

The server received both virtual motion calls and its backend logged both
raw motions, but no actor `type=3` followed either one. Repeating four
post-press motions at 50ms intervals also ended `began=false inDrag=false`
and `smoke-fail`. The remaining failure therefore survives the libocrpc
void-signal fix and is not a single-motion smoke artifact.

### 2026-10-15 12:49–12:58 filter boundary and rejected removal

Temporary filter diagnostics showed that every post-press motion targets
the server peer for the preview itself:

```text
event filter type=3 actor=GsrServerClutterActor
client=Gjs_ui_windowPreview_WindowPreview coords=441.0,247.0 flush-depth=0
```

The preview actor's `event` override did not run afterwards. A smaller move
that stayed on the same target actor produced the same miss.

Mutter processes global filters before adding the current event to the stage
queue, so the recursive queue flush cannot process the event whose filter is
currently running. That made removal worth testing, but did not make it a
proved fix. The actual Weston A/B without the recursive flush still printed:

```text
12:58:23.744  after began=false inDrag=false dx=0
12:58:23.744  miss Error: miss drag-begin
```

The queue-flush removal and temporary filter diagnostics were reverted.
The C extern wrapper was separately renamed from `copy_clutter_event` to
`clutter_event_copy` so its exposed Vala name matches the real C symbol.
At 13:42 the entire global filter was removed for one Weston A/B, not just
its recursive flush. The in-preview smoke still reported
`began=false inDrag=false dx=0`. The filter was restored; it is outside the
remaining cause.

### 2026-10-15 13:01–13:38 event phases

Temporary smoke handlers on the preview showed the initial motion and
button press, but no post-press motion in `captured-event`, `event`, or
`motion-event`. The click action emitted long-press `QUERY` (`state=0`) and
then `ACTIVATE` (`state=1`) after 500ms. It never emitted `CANCEL`
(`state=2`), which is the state that starts DND.

Calling the real `Clutter.Stage.schedule_update()` immediately after every
virtual motion did not change the failure. `_clutter_stage_queue_event()`
already schedules an update when it enqueues an event, so this result is
consistent with Mutter's implementation.

The passing off-preview control receives no motion signal before drag start
either. Its leave crossing (`type=5`) immediately emits long-press
`CANCEL`, then the drag starts and the next move changes the preview by
94.6 pixels. This confirms that the two paths differ at motion delivery,
not in the DND cancel handler. The temporary smoke handlers and scheduling
mode were removed.

Relative virtual motion instead of absolute motion produced the same raw
XTEST positions and the same miss. Removing `before-update` from the
blocking subscription switch for one A/B also left the same
`began=false` result at 13:46. Both trials were reverted. The remaining
motion loss is not caused by the corrected blocking-void behavior.

A headless Clutter control then pressed with one virtual pointer and moved
with a second virtual pointer. It still delivered motion and cancelled the
long press, so differing press/motion device objects alone do not reproduce
the Weston loss. That temporary gate mode was removed.

`GI_META_SMOKE_MANUAL=1` was added for the required physical-input
comparison. Its first launch never reached `manual-ready`: Weston selected
display `:5`, but the run stalled during startup and was killed later. It
did not produce a drag result.

The second manual run reached `manual-ready` at 14:40. A physical drag in
the nested overview did not emit `drag-begin`; the smoke timed out after 30
seconds with `miss manual-drag-begin`. The failure is therefore not an
XTEST-only automation artifact.

The next candidate moved `_clutter_stage_process_queued_events()` from the
pre-queue global filter to a local server `before-update` handler. The
headless control with an event-vfunc actor and a stage grab delivered motion,
but the real Weston smoke still printed `began=false` at 14:51. The product
trial and proxy/grab gate additions were reverted.

### 2026-10-16 08:31–17:43 implicit-grab action boundary

The two `captured-event` notifications before the failure came from the real
`MetaStage` subscription, lease 8. They were the initial pointer crossing
and button press. No post-press motion reached that stage signal. This
rejects the earlier theory that a remote captured-event callback returned
STOP: capture-phase actor delivery was never entered.

The filter saw the requested stay-inside coordinates (`441`, `461`, `481`,
`501`, `521`) and the expected target peer while the stage grab was still
`MetaStage`. Mutter 48.1 builds the implicit-grab emission chain with
capture-phase actions before each actor. The pressed path contained:

```text
preview peer             ClutterClickAction
preview ancestor         ClutterClickAction
MetaStage                unfullscreen
MetaStage                swipe
MetaStage                osk
MetaStage                swipe
MetaStage                swipe
MetaStage                swipe
```

The six stage entries are capture-phase GJS `Clutter.GestureAction`
subclasses. The client stub currently constructs a stock server
`ClutterGestureAction`; `GestureAction.override.vala` only supplies the
client `enabled` property and has no vfunc relay.

Disabling all six stage gesture actions only for one diagnostic run changed
the same stay-inside reproduction to:

```text
after began=true inDrag=true dx=93.22265625
ok
```

Three narrower controls each still failed: disable all four `swipe` actions,
disable only `unfullscreen`, and disable only `osk`. Therefore this is not a
special-case bad action. Any remaining stock capture action can consume the
mouse sequence without its GJS `vfunc_gesture_prepare()` rejection. The
disable code and all filter, subscription, and smoke diagnostics were
removed. The proposed helper relays all five real GestureAction vfuncs so
normal shell gestures remain enabled.

### 2026-10-16 17:49 proposal review

Confirmed that the stock client and wire `Clutter.GestureAction` class is
already generated. The proposal adds only its missing server peer subclass.
The Vala class and file do not use a `Gsr` prefix; only the private wire
helper does, so `create` and `add_hooks` are not presented as stock Clutter
API. Removed the unused method-name map and names array, the duplicate
vfunc-name lookup, and redundant boolean type checks. Kept `construct`
because arbitrary GJS subclasses must mint the peer during GObject
construction. A second review corrected the proposal's over-wrapped
assignments, vfunc lookups, and calls; short expressions now stay on one
line and wrapped calls keep arguments grouped. A third review removed the
five mechanical client `relay_gesture_*` methods: typed `relay=object-bool`
and `relay=object-void` policies now generate them with the existing generic
vfunc trampolines. The five server overrides remain the peer's actual
virtual implementation and provide the required base fallback.

### 2026-10-17 physical drag invalidates the early smoke result

The successful smoke line was not a completed drag/drop test. It stopped
after `drag-begin` and one displacement:

```text
after began=true inDrag=true dx=93.22265625
ok
```

It never released the virtual button. In a physical nested-Weston drag, the
preview followed the pointer only through `10:38:17.761`. Raw pointer motion
continued through `10:38:19.062`, and the button was released at
`10:38:19.148`, but there were no further `Clutter-Actor.set_position` calls.
There was no client exception or process crash. Generic `event`
notifications continued after the last position update, while no further
`Clutter-GestureAction` callback was invoked.

The only startup critical in that sequence was:

```text
g_value_get_uint: assertion 'G_VALUE_HOLDS_UINT (value)' failed
```

It followed `Gsr-Clutter.get_current_event` during `startDrag()`. Whether it
is causal is not yet proved. The next stage is to make the smoke continue
motion beyond the scale transition, release, and assert drag completion,
then diagnose which event callback stops updating the drag actor.

Code inspection found that boundary. `dnd.js::_onEvent()` compares the
current event device with `_grabbedDevice` by object identity. The wire event
stores only `device_type`, and each call to `Event.apply_state()` executes
`new InputDevice()`. Consequently the later motion cannot have the saved
device's identity and is propagated without calling `_updateDragPosition()`.
This also explains why the last `set_position` coincided with transition
completion: those calls were transition-frame position updates.

The smoke was changed to send ten motions over one second, release the
button, and require `drag-end`. The obsolete transition timing monkeypatch
was removed.

### 2026-10-17 16:22 sustained smoke

```bash
GI_META_SMOKE=overview-thumbnail-drag-smoke \
GI_META_SMOKE_CMD='gedit --new-window' \
GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
GSR_NESTED_TIMEOUT=90 \
./scripts/agent-nested-smoke-prove.sh
```

Exit 137 is Weston auto-close after the smoke failure. The result is:

```text
motion offset=20 dx=93.22265625
motion offset=40 through offset=200 stay at dx=93.22265625
after began=true inDrag=true dx=93.22265625
miss Error: miss drag-end ended=false inDrag=true
nested-weston-prove: stop (smoke-fail) after 12s
```

`set_position` ends at 16:22:44.698. Motions and the button release continue
after that, and each `event` notification returns without another RPC.
`Event.read_scroll_tail()` and `Event.apply_state()` now keep one client
`InputDevice` per `device_type` in `devices_by_type`, so both unpack paths
return the object `startDrag()` stored. The smoke now also requires the
preview to move at least 30 pixels after its first measured position.

### 2026-10-17 16:36 device identity rerun

Rebuilt `src/libmutter-clutter-rpc-16.so` and reran the same command.

```text
motion offset=20 dx=424.52734375
motion offset=40 dx=444.52734375
motion offset=60 dx=464.52734375
motion offset=80 dx=484.52734375
motion offset=100 dx=504.52734375
motion offset=120 dx=524.52734375
motion offset=140 dx=528.52734375
motion offset=160 dx=528.52734375
motion offset=180 dx=528.52734375
motion offset=200 dx=528.52734375
after began=true inDrag=true dx=528.52734375 tracked=104
overview-thumbnail-drag-smoke: ok
nested-weston-prove: stop (smoke-ok) after 11s
```

The preview kept moving after the first sample, and the button release
ended the drag. The last four samples stay at 528 because the pointer
reached the edge of the nested stage.

### 2026-10-17 16:38 stay-inside control

Same smoke with `GI_META_SMOKE_STAY_INSIDE=1`.

```text
motion offset=20 dx=189.52734375
motion offset=40 dx=209.52734375
...
motion offset=200 dx=369.52734375
after began=true inDrag=true dx=369.52734375 tracked=180
overview-thumbnail-drag-smoke: ok
nested-weston-prove: stop (smoke-ok) after 10s
```

Every 20-pixel step moved the preview, and the release ended the drag.

### 2026-10-17 16:53 hand drops snap back

The live nested session log, no new prove. Releases at 16:39:25 (782, 276)
and 16:39:31 (270, 104) both call `get_actor_at_pos`,
`transform_stage_point`, `Meta.Workspace.index`,
`located_on_workspace`, and `get_monitor`, then `set_x` / `set_y` /
`set_scale`. There is no `change_workspace_by_index`. The call order matches
`Workspace.acceptDrop()` when `_isMyWindow()` is true. A workspace-thumbnail
drop would call `located_on_workspace` before `index()`.

### 2026-10-17 17:05 pick stop moved to the compositor

The same log, read again. Both releases do two `get_parent` calls before
`Workspace.index`. That is the dragged preview's content clone and
`windowContainer`, then that preview's `acceptDrop`. The preview is the
drag actor (`WindowPreview` has no `getDragActor`, so `startDrag` reparents
the preview itself) and `Shell.util_set_hidden_from_pick` only connected
`pick` in the client. `get_actor_at_pos` never saw that handler.

`util_set_hidden_from_pick` now calls
`Gsr-Clutter-Actor.set_hidden_from_pick`, which connects the stop on the
server actor. Rebuilt `src/gsr-server` and `src/libshell-16.so`. Did not
start a prove: `weston-gsr-session.sh --debug` pid 1083535 is still up.

### 2026-10-17 17:43 drop smoke fails

```bash
GI_META_SMOKE=overview-drop-workspace-smoke \
GI_META_SMOKE_CMD='gedit --new-window' \
GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
GSR_NESTED_TIMEOUT=90 \
./scripts/agent-nested-smoke-prove.sh
```

`nested-weston-prove: stop (smoke-fail) after 10s`. Process exit 137 is
Weston auto-close after that stop.

```text
pick-hidden hit=pick-top at=140,260
n_workspaces=12
thumb index=0 .. thumb index=11
drag 399.4765625,296.162109375 -> thumb 559.5,108
drop moved=false pick=Clutter_Clone > Clutter_Actor > WindowPreview > uiGroup > Meta_Stage @521,49
miss Error: miss change_workspace_by_index pick=Clutter_Clone > Clutter_Actor > WindowPreview > uiGroup > Meta_Stage @521,49
```

Twelve workspaces were already present; this run did not append one.
The hidden actor was still the pick result. The last drop pick was the
dragged preview on `uiGroup`, and `change_workspace_by_index` did not run.
No `src/` edit.

### 2026-10-17 18:04 test pick skip passes

`installPickSkip` in `tests/gjs-embed/overview-drop-workspace-smoke.js`
records actors passed to `Shell.util_set_hidden_from_pick`. Its
`get_actor_at_pos` wrapper hides each recorded actor it hits, picks
again, and shows it. The smoke also drops the workspace count to 2 and
steers the virtual pointer until the pick chain contains
`WorkspaceThumbnail`. No `src/` edit.

```text
pick-hidden hit=pick-bottom at=140,260
n_workspaces=2
target index=1
step 3 Clutter_Actor > WorkspaceThumbnail > ThumbnailsBox > ... @414,108
acceptDropInternal mine=false ws=1
change_workspace_by_index index=1
box-accept ok=true dropWorkspace=1 x=63 y=14.296561241149902
drop moved=true pick=Clutter_Actor > WorkspaceThumbnail > ThumbnailsBox > ... @414,108
overview-drop-workspace-smoke: ok
```

The earlier 17:43 run, without this wrapper, picked `pick-top` and the
dragged preview and did not call `change_workspace_by_index`.

### 2026-10-17 17:32 reverted

That server method and the client call to it are removed.
`Shell.util_set_hidden_from_pick` again connects `pick` on the client
proxy. No gate or smoke has shown that a compositor-side stop changes
the drop target.

### 2026-10-17 18:30 emission hook does not stop pick

Applied `Gsr-Clutter-Actor.hidden` and a `Clutter.Actor.pick` emission
hook. `installPickSkip` was removed. `hidden` was received (ids 1249,
5470, 6153, …). The probe still hit `pick-top`, and the drop pick was
the dragged `WindowPreview`. `change_workspace_by_index` did not run.
`nested-weston-prove: stop (smoke-fail) after 9s`.

A separate program printed:

```text
GLib-GObject-CRITICAL: emission of signal "vpicked" cannot be stopped from emission hook
```

The class handler still ran. A normal handler on the same signal
skipped the class handler while a bool was set, and ran it after the
bool was removed.

### 2026-10-17 18:40 normal pick handler passes

The emission hook is not installed. `hidden` stores
`shell-hidden-from-pick` and connects `stop_pick` once. The handler
stops `pick` only while that bool is set.

```text
pick-hidden hit=pick-bottom at=140,260
acceptDropInternal mine=false ws=1
change_workspace_by_index index=1
box-accept ok=true dropWorkspace=1 x=63 y=14.296561241149902
drop moved=true
overview-drop-workspace-smoke: ok
```

`nested-weston-prove: stop (timeout) after 90s`. Process exit 137 is
Weston auto-close after that timer.

### 2026-10-18 10:18 old preview stays after the drop

Hand drop in `weston-gsr-session.sh --debug`. The window lands on the
other workspace and the old picture stays. Client log
`~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`:

```text
10:18:29.326 get_window_actors
10:18:30.394 get_window_actors
10:18:33.005 change_workspace_by_index
10:18:33.007 window-removed
10:18:33.007 window-added
10:18:33.012 set_position
```

No `Clutter-Actor.destroy` after `window-removed`.
`get_window_actors` did `new Window()` and `register_handle`, which
overwrites `proxies[lid]`. The preview still holds the earlier object.
`===` misses, so `_doRemoveWindow` returns before `destroy`.
`restoreOnSuccess` then eases that preview back to the old slot.

### 2026-10-18 closed

User: the drop is complete. Moved to `docs/bugs/done/`.
