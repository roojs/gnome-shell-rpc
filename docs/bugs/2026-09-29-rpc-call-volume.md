# Boot sends 32k RPC calls before any input

**Status:** ⏳ open. A nested session that the user had not driven reached 32,000 client calls in 29 seconds. The log finished at 45,080. Most of that is a first write or a first subscribe per new actor, or a getter whose answer does not change until a signal we already receive.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Seen:** 2026-09-29 15:56:21–15:58:03. `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`. Nested `mutter-rpc` + `gnome-shell-rpc`. The user had not clicked or typed. Pointer `captured-event` was still zero when the call count crossed 32,000.

The log ends at 15:58:03 with `Unexpected early end-of-stream` after call id 45081. That abort is the unregistered `MetaWindowWayland` on [`2026-09-24-overview-picker-preview-gone.md`](2026-09-24-overview-picker-preview-gone.md). This bug is the call volume in the same log.

## What the log shows

45,080 lines are `Client.vala:1018` method calls. 32,000 of them had already happened at 15:56:50 (`Clutter-Actor.show`). Peak rate is about 2,300 calls per second.

| When | Calls | What |
| ---- | ----: | ---- |
| 15:56:22–28 | ~12,000 | Shell chrome (panel, menus, dash) |
| 15:56:44–50 | ~15,300 | App grid. Steady ~44 `St.Button.new` per second |
| 15:57:14 onward | the rest | Layout and pick once the pointer moves |

Whole-session split:

| Share | Bucket | Notes |
| ----: | ------ | ----- |
| 38% | setters and tree edits | `add_child` 2,330, style class, expand, align, `hide` |
| 30% | getters | sibling walks, preferred size, theme |
| 12% | subscribe | `RPC-Live-Subscribe.rpc_signal` 5,286, `unsubscribe` 35 |
| 9% | constructors | `St-Button.new` 503, `Helper-Actor.create` 711 |
| 5% | live callback | register / reply for vfunc hooks |

The 15:56:44–50 wave matches `AppViewItem` (`vendor/gnome-shell/js/ui/appDisplay.js`) plus `BaseIcon` (`iconGrid.js`): one `St.Button`, a square bin, a vertical `St.BoxLayout`, an icon `St.Bin`, a `St.Label`, `TextureCache.get_default` plus its `icon-theme-changed` subscribe, then `hide()`. About 54 calls per icon. `St.Icon.new` stays at 0 through the wave (the texture is created later). `remove_child` and `unsubscribe` stay at 0: this is one build of a few hundred apps, not a rebuild loop. At ~54 calls each and ~2,300 calls/sec, that build takes about six seconds.

After the grid exists, moving the pointer is a different pile: `get_next_sibling` 1,931 against `get_children` 267, `get_preferred_height` 1,244, `get_preferred_width` 1,087, `get_theme_node` 1,103, `St-ThemeNode.get_length` 870. `ActorIter` walks with `first_child` / `get_next_sibling` (`src/gi-stub/overrides-clutter/ActorIter.override.vala`), so one child walk is one RPC per sibling.

## Already cached

`src/gi-stub/overrides-clutter/Actor.override.vala` already keeps a few fields local: `visible`, `scale_x` / `scale_y`, `name` (fetch once), and `queue_relayout` (one RPC until allocate). Generated property accessors still call the wire on every get and every set.

## Cut

Scoreboard against this log's 45,080 client calls. Row 3 is a counted call that goes away. Row 1 keeps one call per batch, so its removed count is the extras, not the whole bucket. The bottom four keep a first fetch, and `style-changed` was firing in the same seconds as the layout bursts (283 notifications), so those rows do not get to claim every call they touch.

| | Change | Calls removed | Share |
| - | ------ | ------------: | ----: |
| 1 | Four calls per new actor: create, signals, hooks, properties | every signal after the first, every hook register after the first, every initial setter after the property call | |
| 2 | `add_child` / `set_child` stay their own call | | |
| 3 | Local child list: `get_next_sibling`, `get_first_child`, `get_parent` | 2,813 | 6% |
| 4 | Preferred size until `queue_relayout`, a child change, or `style-changed` | a few hundred of 2,331 | |
| 5 | Theme node and `ThemeNode.get_length` until `style-changed` | a few hundred of 1,973 | |
| 6 | `get_text_direction` and `St.Settings` until the matching notify | 331, plus settings getters each under 300 | ~1% |
| 7 | Skip a setter when the cached value already matches | a few hundred | <1% |

Row 3 removes **2,813** calls (6%). Row 1 is the init spike. It does not fold those calls into `.new`. Row 2 stays one call per `add_child` / `set_child` (2,330 + 681).

Row 1's inputs are 5,286 `RPC-Live-Subscribe.rpc_signal`, the per-vfunc `RPC-Live-Callback.register`, and 8,949 counted setters: `set_style_class_name` 1,740, `set_x_expand` 1,139, `set_y_expand` 1,006, `set_x_align` 923, `set_y_align` 821, `set_can_focus` 639, `set_layout_manager` 596, `set_reactive` 564, `St-Label.set_text` 462, `set_orientation` 397, `set_label_actor` 361, `set_pivot_point` 301. The `.new` itself stays. Initial `hide` is another 667, as the `visible` property on the property call.

Row 2 is `add_child` 2,330 and `St-Bin.set_child` 681.

Row 3 is `get_next_sibling` 1,931, `get_first_child` 503, `get_parent` 379. The client already sent the `add_child`. `child-added` (257 notifications) covers a child the server inserts itself. `get_children` was under 300 and drops with the same list.

## Four calls

One app icon at 16:56:16, ids 37377–37411, is 35 calls from one `St-Button.new` to the next:

```text
St-Button.new
RPC-Live-Subscribe.rpc_signal
set_reactive, set_can_focus, set_track_hover, set_style_class_name
St-BoxLayout.new, set_style_class_name, set_orientation, set_x_align, set_x_expand, set_y_expand
St-Bin.set_child
… icon, label, add_child, set_text, hide, show, get_first_child
```

That button is one create, one signal, and four setters. The box is one create and five setters. A subclass adds one `RPC-Live-Callback.register` per vfunc inside `create_with_overrides`, then `Helper-Actor.create` carries the resulting ids. The cut is those N calls down to four per actor:

| Call | What it replaces | When it is sent |
| ---- | ---------------- | --------------- |
| create | `St-*.new` or `Helper-Actor.create` | `construct`, as now |
| signals | every `rpc_signal` for this actor's initial names | same `construct`, after the lease exists |
| hooks | every `RPC-Live-Callback.register` for this actor's vfuncs | same `construct`, only when the list is non-empty |
| properties | the initial `set_*` / `hide` / `show` | before the first call that is not one of those sets |

A stock icon has no vfunc hooks, so it is three calls. An empty signal list sends no signal call. Create does not take the other three.

**🚫** Fields on `Clutter.Actor` for this. No `minted`, no `pack_alias`, no hook variants, no method list, no signal list stored on the instance. Signals and hooks are locals in the method that already walks them. The property batch is one map, allocated with the actor. `prop_batch_open` turns on at the end of construct and off when that call is sent. The map is cleared then.

**🚫** New methods around the four calls. `mint_stock`, `mint_helper`, `send_initial_signals`, `subscribe_many`, `remember`, `begin_hook_batch`, `finish_hook_batch`, `drop_hook_batch`, `queue_property`, `flush_properties`, `property_variant`. `create`, `rpc_signal`, `add_hooks`, and `add_properties` are the calls. `set_` is reserved, so these are not `set_hooks` or `set_properties`. The lines go in those methods.

**🚫** Arguments on generated `St-Button.new`. Gi owns that signature.

**🚫** `Helper-St.pack`, an `a(sv)` of setter names, and an allow-list of `set_*` tails.

**🚫** Queue getters, `allocate`, `add_child`, or `set_child` into any of the four. Those stay their own call. The property call is sent first when one of them runs.

## Proposed code

Each block is one edit. **Replace** removes the first fence and puts in the second. **Add** inserts the fence after the anchor. `create_with_overrides` is replaced once, under Hooks.

### ⏳ 🔷 Create

**Where:** `src/gi-stub/overrides-clutter/Actor.override.vala` `construct`. The helper arms stop calling `signal_overrides` here. That call moves into `create_with_overrides`, replaced under Hooks.

**Replace:**

```vala
				case "St-Widget":
					this.create_with_overrides();
					this.signal_overrides(this.get_type());
					return;
				case "Clutter-Actor":
					/* Exact Actor → .new. GJS/Vala subclasses need Helper hooks. */
					if (this.get_type() != typeof(Actor)) {
						this.create_with_overrides();
						this.signal_overrides(this.get_type());
						return;
					}
					break;
```

**Replace with:**

```vala
				case "St-Widget":
					this.create_with_overrides();
					return;
				case "Clutter-Actor":
					/* Exact Actor → .new. GJS/Vala subclasses need Helper hooks. */
					if (this.get_type() != typeof(Actor)) {
						this.create_with_overrides();
						return;
					}
					break;
```

**Where:** the stock arm in that same `construct`, the `signal_overrides` call.

**Replace:**

```vala
			GnomeShellRpc.GiStub.Runtime.register_handle(this);
			this.signal_overrides(this.get_type());
			return;
```

**Replace with:**

```vala
			GnomeShellRpc.GiStub.Runtime.register_handle(this);
			this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
			this.prop_batch_open = true;
			return;
```

**Where:** `src/rpc/helper/ClutterActor.vala` `rpc_register`, then `create`.

**Replace:**

```vala
			OLLMrpc.Request.add_class(
				"Helper-Actor", typeof(Actor),
				"create", "sSvv",
				"add_hook", "it",
```

**Replace with:**

```vala
			OLLMrpc.Request.add_class(
				"Helper-Actor", typeof(Actor),
				"create", "s",
				"add_hook", "it",
				"add_hooks", "Sv",
				"add_properties", "",
```

`add_hook` stays `it`. `Global.bind_display` still sends one vfunc id and one hook id. The construct hook call is `add_hooks`. `RPC-Live-Callback.register` stays one callback id and does not touch the actor.

**Replace:**

```vala
		public void create(
			OLLMrpc.Request request,
			string type_name,
			string[] names,
			GLib.Variant vfunc_ids,
			GLib.Variant hook_ids
		) {
			var created = new Actor();
			created.client_type_name = type_name;
			var n = (int) vfunc_ids.n_children();
			for (var i = 0; i < n; i++) {
				var id = vfunc_ids.get_child_value(i).get_int32();
				created.vfuncs.set(id,
					request.connection.callbacks.get(
						(int) hook_ids.get_child_value(i).get_uint64()));
				if (i < names.length) {
					created.method_names.set(id, names[i]);
				}
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(created)),
			});
		}
```

**Replace with:**

```vala
		public void create(OLLMrpc.Request request, string type_name)
		{
			var created = new Actor();
			created.client_type_name = type_name;
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(created)),
			});
		}
```

`add_hook` stays for one later vfunc. It is not the construct call.

### ⏳ 🔷 Signals

`signal_overrides` already walks the names and calls `ensure_signal_subscribe` once per name. That is `Signals.connect`, which sends `rpc_signal`. The walk keeps a local list. One `rpc_signal` sends it. `connect` is the method that already writes `subs` / `refs`.

**Where:** `src/gi-stub/overrides-clutter/Actor.override.vala` `signal_overrides`. The signature gains the list. The leaf frame, which already returns after the parent walk, sends.

**Replace:**

```vala
	private void signal_overrides(GLib.Type t)
	{
		if (t == GLib.Type.INVALID) {
			return;
		}
		this.signal_overrides(t.parent());
		if (t == this.get_type()) {
			return;
		}
```

**Replace with:**

```vala
	private void signal_overrides(GLib.Type t, Gee.ArrayList<string> names)
	{
		if (t == GLib.Type.INVALID) {
			return;
		}
		this.signal_overrides(t.parent(), names);
		if (t == this.get_type()) {
			if (names.size == 0) {
				return;
			}
			string[] pending_signals = {};
			foreach (var name in names) {
				pending_signals += name;
			}
			Shell.Signals.pending_signals = pending_signals;
			Shell.Signals.connect(this, pending_signals[0], 0);
			return;
		}
```

**Replace:**

```vala
			GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(this, signal_name);
```

**Replace with:**

```vala
			names.add(signal_name);
```

**Where:** `src/shell-gi/Signals.vala`, the `subs` and `refs` fields. Nothing assigns either back to null. `disconnect` only removes keys.

**Replace:**

```vala
		private static Gee.HashMap<int, Gee.HashMap<string, int>>? subs = null;

		/**
		 * Our handler id → how many local {@code .connect()}s share that name.
		 * Last drop (count 0) sends {@code RPC-Live-Subscribe.unsubscribe}.
		 */
		private static Gee.HashMap<int, int>? refs = null;
```

**Replace with:**

```vala
		private static Gee.HashMap<int, Gee.HashMap<string, int>> subs
			= new Gee.HashMap<int, Gee.HashMap<string, int>>();

		/**
		 * Our handler id → how many local {@code .connect()}s share that name.
		 * Last drop (count 0) sends {@code RPC-Live-Subscribe.unsubscribe}.
		 */
		private static Gee.HashMap<int, int> refs = new Gee.HashMap<int, int>();
		/* Notification handler is connected on the first subscribe. */
		private static bool notification_hooked = false;
```

**Add** in `src/shell-gi/Signals.vala`, after `notification_hooked`.

**Anchor:**

```vala
		private static bool notification_hooked = false;
```

**Add:**

```vala
		/* Names signal_overrides has not sent yet. */
		public static string[] pending_signals = {};
```

**Where:** `src/shell-gi/Signals.vala` `Signals.connect`, from the already-subscribed check through `return hid`.

**Replace:**

```vala
			if (Signals.subs != null
					&& Signals.subs.has_key(lid)
					&& Signals.subs.get(lid).has_key(signal_name)) {
				var hid = Signals.subs.get(lid).get(signal_name);
				Signals.refs.set(hid, Signals.refs.get(hid) + 1);
				if (gjs_handler_id != 0) {
					if (Signals.gjs_ids == null) {
						Signals.gjs_ids = new Gee.HashMap<int, Gee.HashMap<int, int>>();
					}
					if (!Signals.gjs_ids.has_key(lid)) {
						Signals.gjs_ids.set(lid, new Gee.HashMap<int, int>());
					}
					Signals.gjs_ids.get(lid).set(gjs_handler_id, hid);
				}
				return hid;
			}
			GnomeShellRpc.GiStub.Runtime.client.proxies.set(lid, obj);
			GnomeShellRpc.call_value(
					"RPC-Live-Subscribe.rpc_signal", obj, OLLMrpc.args("s", signal_name));
			if (Signals.subs == null) {
				Signals.subs = new Gee.HashMap<int, Gee.HashMap<string, int>>();
				Signals.refs = new Gee.HashMap<int, int>();
				GnomeShellRpc.GiStub.Runtime.client.notification.connect((notif) => {
					if (Signals.subs == null
							|| !Signals.subs.has_key(notif.id)
							|| !Signals.subs.get(notif.id).has_key(notif.method)) {
						return;
					}
					if (!GnomeShellRpc.GiStub.Runtime.client.proxies.has_key(notif.id)) {
						return;
					}
					var target = GnomeShellRpc.GiStub.Runtime.client.proxies.get(notif.id);
					Signals.emit(target, notif.method, notif.args);
				});
			}
			if (!Signals.subs.has_key(lid)) {
				Signals.subs.set(lid, new Gee.HashMap<string, int>());
			}
			var hid = Signals.next_handler_id++;
			Signals.subs.get(lid).set(signal_name, hid);
			Signals.refs.set(hid, 1);
			if (gjs_handler_id != 0) {
				if (Signals.gjs_ids == null) {
					Signals.gjs_ids = new Gee.HashMap<int, Gee.HashMap<int, int>>();
				}
				if (!Signals.gjs_ids.has_key(lid)) {
					Signals.gjs_ids.set(lid, new Gee.HashMap<int, int>());
				}
				Signals.gjs_ids.get(lid).set(gjs_handler_id, hid);
			}
			return hid;
```

**Replace with:**

```vala
			if (Signals.subs.has_key(lid)
					&& Signals.subs.get(lid).has_key(signal_name)) {
				var hid = Signals.subs.get(lid).get(signal_name);
				Signals.refs.set(hid, Signals.refs.get(hid) + 1);
				if (gjs_handler_id != 0) {
					if (Signals.gjs_ids == null) {
						Signals.gjs_ids = new Gee.HashMap<int, Gee.HashMap<int, int>>();
					}
					if (!Signals.gjs_ids.has_key(lid)) {
						Signals.gjs_ids.set(lid, new Gee.HashMap<int, int>());
					}
					Signals.gjs_ids.get(lid).set(gjs_handler_id, hid);
				}
				return hid;
			}
			string[] signal_names = { signal_name };
			if (Signals.pending_signals.length > 0) {
				signal_names = Signals.pending_signals;
				Signals.pending_signals = {};
			}
			GnomeShellRpc.GiStub.Runtime.client.proxies.set(lid, obj);
			GnomeShellRpc.call_value("RPC-Live-Subscribe.rpc_signal", obj,
				OLLMrpc.args("S", signal_names));
			if (!Signals.notification_hooked) {
				Signals.notification_hooked = true;
				GnomeShellRpc.GiStub.Runtime.client.notification.connect((notif) => {
					if (!Signals.subs.has_key(notif.id)
							|| !Signals.subs.get(notif.id).has_key(notif.method)) {
						return;
					}
					if (!GnomeShellRpc.GiStub.Runtime.client.proxies.has_key(notif.id)) {
						return;
					}
					var target = GnomeShellRpc.GiStub.Runtime.client.proxies.get(notif.id);
					Signals.emit(target, notif.method, notif.args);
				});
			}
			var hid = 0;
			foreach (var name in signal_names) {
				if (!Signals.subs.has_key(lid)) {
					Signals.subs.set(lid, new Gee.HashMap<string, int>());
				}
				hid = Signals.next_handler_id++;
				Signals.subs.get(lid).set(name, hid);
				Signals.refs.set(hid, 1);
				if (gjs_handler_id == 0 || name != signal_name) {
					continue;
				}
				if (Signals.gjs_ids == null) {
					Signals.gjs_ids = new Gee.HashMap<int, Gee.HashMap<int, int>>();
				}
				if (!Signals.gjs_ids.has_key(lid)) {
					Signals.gjs_ids.set(lid, new Gee.HashMap<int, int>());
				}
				Signals.gjs_ids.get(lid).set(gjs_handler_id, hid);
			}
			return hid;
```

**Where:** libocrpc `libocrpc/Live/Subscribe.vala` `rpc_signal`. The signature is `S`. The body loops [`Live.Subscription.connect`](../../../OLLMchat/docs/bugs/2026-09-29-subscribe-without-reply.md) and replies once. That method is applied. It writes no reply.

**Replace:**

```vala
				"rpc_signal", "s",
```

**Replace with:**

```vala
				"rpc_signal", "S",
```

**Replace:**

```vala
		public void rpc_signal(Request request, string name)
		{
			if (!request.connection.live_handles) {
				GLib.error("Subscribe.signal requires live_handles");
			}
			var subscription = new Subscription() {
				connection = request.connection,
				method = name,
				id = (int) request.lease_id
			};
			if (!subscription.connect()) {
				request.connection.reply_error(request, (int) RpcErrorCode.INVALID_PARAMS);
				return;
			}
			request.reply(new Response());
		}
```

**Replace with:**

```vala
		public void rpc_signal(Request request, string[] names)
		{
			if (!request.connection.live_handles) {
				GLib.error("Subscribe.signal requires live_handles");
			}
			foreach (var name in names) {
				var subscription = new Subscription() {
					connection = request.connection,
					method = name,
					id = (int) request.lease_id
				};
				if (!subscription.connect()) {
					request.connection.reply_error(request,
						(int) RpcErrorCode.INVALID_PARAMS);
					return;
				}
			}
			request.reply(new Response());
		}
```

A false `connect` is `reply_error` `-32602` and no success reply. An empty `method` or a missing lease is that false.

**🚫** `Subscribe.attach`. The connect is `new OLLMrpc.Live.Subscription()`.

### ⏳ 🔷 Hooks

`add_hook` is unchanged. `Global.bind_display` still sends one vfunc id and one hook id. `RPC-Live-Callback.reply` is unchanged.

**Add** in `src/gi-stub/Runtime.vala`, after `handlers`. `handlers` and `InvokeRow` become `internal` in the same edit so `create_with_overrides` can file the rows.

**Replace:**

```vala
		private class InvokeRow : GLib.Object
		{
			public InvokeHandler handler;
		}

		private static Gee.HashMap<int, InvokeRow>? handlers = null;
```

**Replace with:**

```vala
		internal class InvokeRow : GLib.Object
		{
			public InvokeHandler handler;
		}

		internal static Gee.HashMap<int, InvokeRow>? handlers = null;
		/* Non-null only while create_with_overrides is inside bind_vfunc. */
		internal static Gee.ArrayList<InvokeRow>? hook_rows;
```

**Where:** `src/gi-stub/Runtime.vala` `callback_bind`. This replaces the whole method.

**Replace:**

```vala
		public static uint64 callback_bind(owned InvokeHandler handler)
		{
			Runtime.register();
			if (Runtime.handlers == null) {
				Runtime.handlers = new Gee.HashMap<int, InvokeRow>();
			}
			var response = GnomeShellRpc.call_value("RPC-Live-Callback.register");
			var id = (int) response.args.get(0).get_uint64();
			var row = new InvokeRow();
			row.handler = (owned) handler;
			Runtime.handlers.set(id, row);
			return (uint64) id;
		}
```

**Replace with:**

```vala
		public static uint64 callback_bind(owned InvokeHandler handler)
		{
			if (Runtime.hook_rows != null) {
				var row = new InvokeRow();
				row.handler = (owned) handler;
				Runtime.hook_rows.add(row);
				return 1;
			}
			Runtime.register();
			if (Runtime.handlers == null) {
				Runtime.handlers = new Gee.HashMap<int, InvokeRow>();
			}
			var empty_ids = new GLib.Variant.array(
				new GLib.VariantType("i"), new GLib.Variant[] {});
			var response = GnomeShellRpc.call_value("RPC-Live-Callback.register",
				null, OLLMrpc.args("iSv", 1, new string[] {}, empty_ids));
			var id = response.args.get(0).get_child_value(0).get_uint64();
			var row = new InvokeRow();
			row.handler = (owned) handler;
			Runtime.handlers.set((int) id, row);
			return id;
		}
```

**Where:** `src/gi-stub/overrides-clutter/Actor.override.vala` `create_with_overrides`. This replaces the whole method. It is not a second copy of the `construct` edit above.

**Replace:**

```vala
	void create_with_overrides()
	{
		string[] always = {};
		var overridden = GnomeShellRpc.GiStub.VfuncRelay.overridden(
			this.get_type(), "Clutter", "Actor", "StWidget", always);
		/*
		 * Callbacks do not need a lease. Register them, then create the
		 * actor with the list already attached. The lease comes back
		 * only after the server has stored the map.
		 */
		string[] names = {};
		var vfunc_ids = new GLib.VariantBuilder(new GLib.VariantType("ai"));
		var hook_ids = new GLib.VariantBuilder(new GLib.VariantType("at"));
		foreach (var name in overridden) {
			var vfunc_id = -1;
			var hook_id = this.bind_vfunc(name, out vfunc_id);
			if (hook_id == 0) {
				continue;
			}
			var called = GnomeShellRpc.GiStub.VfuncRelay.name_of(
				"Clutter", "Actor", vfunc_id);
			if (called == "") {
				continue;
			}
			names += called;
			vfunc_ids.add("i", vfunc_id);
			hook_ids.add("t", hook_id);
		}
		var response = GnomeShellRpc.call_value("Helper-Actor.create",
			null,
			OLLMrpc.args("sSvv", this.get_type().name(), names,
				vfunc_ids.end(), hook_ids.end()));

		this.rpc_lid = response.args.get(0).get_uint64();
		this.helper_attached = true;
		GnomeShellRpc.GiStub.Runtime.register_handle(this);
	}
```

**Replace with:**

```vala
	void create_with_overrides()
	{
		GnomeShellRpc.GiStub.Runtime.hook_rows =
			new Gee.ArrayList<GnomeShellRpc.GiStub.Runtime.InvokeRow>();
		string[] always = {};
		var overridden = GnomeShellRpc.GiStub.VfuncRelay.overridden(
			this.get_type(), "Clutter", "Actor", "StWidget", always);
		string[] names = {};
		var vfunc_ids = new GLib.VariantBuilder(new GLib.VariantType("ai"));
		foreach (var name in overridden) {
			var vfunc_id = -1;
			var hook_id = this.bind_vfunc(name, out vfunc_id);
			if (hook_id == 0) {
				continue;
			}
			var called = GnomeShellRpc.GiStub.VfuncRelay.name_of(
				"Clutter", "Actor", vfunc_id);
			if (called == "") {
				continue;
			}
			names += called;
			vfunc_ids.add("i", vfunc_id);
		}
		var response = GnomeShellRpc.call_value("Helper-Actor.create", null,
			OLLMrpc.args("s", this.get_type().name()));
		this.rpc_lid = response.args.get(0).get_uint64();
		this.helper_attached = true;
		GnomeShellRpc.GiStub.Runtime.register_handle(this);
		this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
		if (names.length == 0) {
			GnomeShellRpc.GiStub.Runtime.hook_rows = null;
			this.prop_batch_open = true;
			return;
		}
		var hooks = GnomeShellRpc.call_value("Helper-Actor.add_hooks", this,
			OLLMrpc.args("Sv", names, vfunc_ids.end()));
		var ids = hooks.args.get(0);
		if (GnomeShellRpc.GiStub.Runtime.handlers == null) {
			GnomeShellRpc.GiStub.Runtime.handlers = new Gee.HashMap<int,
				GnomeShellRpc.GiStub.Runtime.InvokeRow>();
		}
		var n = (int) ids.n_children();
		for (var i = 0; i < n; i++) {
			var id = ids.get_child_value(i).get_uint64();
			GnomeShellRpc.GiStub.Runtime.handlers.set((int) id,
				GnomeShellRpc.GiStub.Runtime.hook_rows.get(i));
		}
		GnomeShellRpc.GiStub.Runtime.hook_rows = null;
		this.prop_batch_open = true;
	}
```

**Where:** `src/rpc/helper/ClutterActor.vala` `add_hooks`. `RPC-Live-Callback.register` stays the one-id allocator. It does not look up the actor.

**Add** after `add_hook`:

```vala
		public void add_hooks(
			OLLMrpc.Request request,
			string[] names,
			GLib.Variant vfunc_ids
		) {
			if (!request.connection.live_handles) {
				GLib.error("Actor.add_hooks requires live_handles");
			}
			var created = request.connection.leases.get(
				(int) request.lease_id) as Actor;
			if (created == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
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
				if (i >= names.length) {
					continue;
				}
				created.method_names.set(vfunc_id, names[i]);
			}
			request.reply(new OLLMrpc.Response() {
				args = OLLMrpc.args("v", ids.end()),
			});
		}
```

### ⏳ 🔷 Properties

One leased call. The map stores the property name and the `GLib.Value` the setter already built. `call_value` already sends those values. `hide` and `show` are `visible`. `set_style_class_name` is `style-class`. A set after the map has been sent is the normal setter. `set_pivot_point` has two arguments, so it does not join the map; the map is sent, then that call runs.

The map is allocated with the actor and stays empty after the call goes out. `prop_batch_open` starts false, turns on at the end of construct, and turns off when the map is sent. Empty means nothing is queued.

The first set of a property still crosses the wire, on this call. A construct default is not treated as already sent.

**Add** in `src/gi-stub/overrides-clutter/Actor.override.vala`, after `name_known`.

**Anchor:**

```vala
	string actor_name = "";
	bool name_known = false;
```

**Add:**

```vala
	/* Initial sets, until the first call that is not one of them. */
	internal Gee.HashMap<string, GLib.Value?> prop_batch {
		get; set; default = new Gee.HashMap<string, GLib.Value?>();
	}
	internal bool prop_batch_open = false;
```

**Where:** `src/namespace.vala` `call_value`, the whole function. A queued property returns before `lease_id_of`. From `lease_id` through `do_call` is the end, and it stays at that indent.

**Replace:**

```vala
	public OLLMrpc.Response call_value(
		string method,
		GLib.Object? instance = null,
		Gee.ArrayList<GLib.Value?>? args = null,
		OLLMrpc.Live.Buffer? buffer = null
	) throws GLib.Error {
		uint64 lease_id = 0;
		if (instance != null) {
			lease_id = GiStub.Runtime.lease_id_of(instance, method);
		}
		var req = new OLLMrpc.Request() {
			method = method,
			lease_id = lease_id,
			buffer = buffer,
		};
		if (args == null) {
			return GiStub.Runtime.do_call(req);
		}
		foreach (var val in args) {
			if (!val.type().is_a(GLib.Type.OBJECT)) {
				req.args.add(val);
				continue;
			}
			var obj = val.get_object();
			if (obj == null) {
				var zero = GLib.Value(GLib.Type.UINT64);
				zero.set_uint64(0);
				req.args.add(zero);
				continue;
			}
			var lease = GiStub.Runtime.lease_id_of(obj, method);
			var wire = GLib.Value(GLib.Type.UINT64);
			wire.set_uint64(lease);
			req.args.add(wire);
		}
		return GiStub.Runtime.do_call(req);
	}
```

**Replace with:**

```vala
	public OLLMrpc.Response call_value(
		string method,
		GLib.Object? instance = null,
		Gee.ArrayList<GLib.Value?>? args = null,
		OLLMrpc.Live.Buffer? buffer = null
	) throws GLib.Error {
		var actor = instance as Clutter.Actor;
		if (actor != null && actor.prop_batch_open
			&& (method.has_suffix(".hide") || method.has_suffix(".show"))) {
			var held = GLib.Value(typeof(bool));
			held.set_boolean(method.has_suffix(".show"));
			actor.prop_batch.set("visible", held);
			return new OLLMrpc.Response();
		}
		var name = "";
		if (actor != null && actor.prop_batch_open && args != null && args.size == 1) {
			var dot = method.last_index_of_char('.');
			var tail = dot < 0 ? method : method.substring(dot + 1);
			if (!tail.has_prefix("set_") || tail == "set_child") {
				tail = "";
			}
			if (tail != "") {
				name = tail.substring(4).replace("_", "-");
			}
		}
		if (name != "" && actor.get_class().find_property(name) == null) {
			name = "";
		}
		if (name != "") {
			actor.prop_batch.set(name, args.get(0));
			return new OLLMrpc.Response();
		}
		if (actor != null && actor.prop_batch_open) {
			actor.prop_batch_open = false;
			if (actor.prop_batch.size > 0) {
				var send = new Gee.ArrayList<GLib.Value?>();
				foreach (var entry in actor.prop_batch.entries) {
					var key = GLib.Value(typeof(string));
					key.set_string(entry.key);
					send.add(key);
					send.add(entry.value);
				}
				actor.prop_batch.clear();
				GnomeShellRpc.call_value("Helper-Actor.add_properties", actor, send);
			}
		}
		uint64 lease_id = 0;
		if (instance != null) {
			lease_id = GiStub.Runtime.lease_id_of(instance, method);
		}
		var req = new OLLMrpc.Request() {
			method = method,
			lease_id = lease_id,
			buffer = buffer,
		};
		if (args == null) {
			return GiStub.Runtime.do_call(req);
		}
		foreach (var val in args) {
			if (!val.type().is_a(GLib.Type.OBJECT)) {
				req.args.add(val);
				continue;
			}
			var obj = val.get_object();
			if (obj == null) {
				var zero = GLib.Value(GLib.Type.UINT64);
				zero.set_uint64(0);
				req.args.add(zero);
				continue;
			}
			var lease = GiStub.Runtime.lease_id_of(obj, method);
			var wire = GLib.Value(GLib.Type.UINT64);
			wire.set_uint64(lease);
			req.args.add(wire);
		}
		return GiStub.Runtime.do_call(req);
	}
```

`call_value` already turns an object argument into a lease id. A `set_child`, a getter, `add_child`, or `allocate` is not stored, so the map is sent and then that call runs. `set_pivot_point` has two arguments, so it takes that same path.

**Add** in `src/rpc/helper/ClutterActor.vala`, after `create`. The signature line is already in the `rpc_register` replace above.

**Anchor:** the `create` method this section already replaced.

**Add:**

```vala
		public void add_properties(OLLMrpc.Request request)
		{
			var obj = request.connection.leases.get((int) request.lease_id);
			if (obj == null || request.args.size % 2 != 0) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			for (var i = 0; i < request.args.size; i += 2) {
				var name = request.args.get(i).get_string();
				var value = request.args.get(i + 1);
				var pspec = obj.get_class().find_property(name);
				if (pspec == null) {
					request.connection.reply_error(request,
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
					return;
				}
				if (!pspec.value_type.is_a(GLib.Type.OBJECT)) {
					obj.set_property(name, value);
					continue;
				}
				var peer = request.connection.leases.get((int) value.get_uint64());
				var obj_value = GLib.Value(pspec.value_type);
				obj_value.set_object(peer);
				obj.set_property(name, obj_value);
			}
			request.reply(new OLLMrpc.Response());
		}
```

A missing property is `reply_error` `-32602` and no success reply.

### After that

**⏳ 🔷** Rows 4–6, same shape as `name` / `scale_x` in `Actor.override.vala`. Preferred size only with the invalidation in row 4. A stale size is a wrong allocation.

**🚫** Leave on the wire: `get_actor_at_pos` (330), `allocate` (513), `RPC-Live-Callback.reply` (2,034), `captured-event`, `before-update`. Those are the pointer and the frame.
