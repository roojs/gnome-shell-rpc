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

Scoreboard against this log's 45,080 client calls. Rows do not overlap, so the firm numbers add. The top three are counted calls that go away. The bottom four keep a first fetch, and `style-changed` was firing in the same seconds as the layout bursts (283 notifications), so those rows do not get to claim every call they touch.

| | Change | Calls removed | Share |
| - | ------ | ------------: | ----: |
| 1 | Pack each new actor's first property sets and its signal subscribes into that `.new` | 14,200 | 32% |
| 2 | Carry the initial `add_child` / `set_child` on that same create | 3,011 | 7% |
| 3 | Local child list: `get_next_sibling`, `get_first_child`, `get_parent` | 2,813 | 6% |
| 4 | Preferred size until `queue_relayout`, a child change, or `style-changed` | a few hundred of 2,331 | |
| 5 | Theme node and `ThemeNode.get_length` until `style-changed` | a few hundred of 1,973 | |
| 6 | `get_text_direction` and `St.Settings` until the matching notify | 331, plus settings getters each under 300 | ~1% |
| 7 | Skip a setter when the cached value already matches | a few hundred | <1% |

Rows 1–3 remove about **20,000** calls (44%). Row 7 does not shrink the app-grid spike: those sets happen once per new actor, which is why they belong in row 1.

Row 1 is 5,286 `RPC-Live-Subscribe.rpc_signal` plus 8,949 counted setters: `set_style_class_name` 1,740, `set_x_expand` 1,139, `set_y_expand` 1,006, `set_x_align` 923, `set_y_align` 821, `set_can_focus` 639, `set_layout_manager` 596, `set_reactive` 564, `St-Label.set_text` 462, `set_orientation` 397, `set_label_actor` 361, `set_pivot_point` 301. The `.new` itself stays. Initial `hide` is another 667 if `visible` rides along (not in the 14,200).

Row 2 is `add_child` 2,330 and `St-Bin.set_child` 681.

Row 3 is `get_next_sibling` 1,931, `get_first_child` 503, `get_parent` 379. The client already sent the `add_child`. `child-added` (257 notifications) covers a child the server inserts itself. `get_children` was under 300 and drops with the same list.

## Packing

`.new` cannot carry the later calls as it stands. `Actor.construct` sends `Helper-Actor.create` or `St-*.new` and returns the lease, then `signal_overrides` subscribes, then JavaScript sets properties and connects. One app icon at 16:56:16, ids 37377–37411, is 35 calls from one `St-Button.new` to the next:

```text
St-Button.new
RPC-Live-Subscribe.rpc_signal
set_reactive, set_can_focus, set_track_hover, set_style_class_name
St-BoxLayout.new, set_style_class_name, set_orientation, set_x_align, set_x_expand, set_y_expand
St-Bin.set_child
… icon, label, add_child, set_text, hide, show, get_first_child
```

Two different bags.

**Already known inside `construct`.** The vfunc hook list is already an argument of `Helper-Actor.create`. `signal_overrides` runs immediately after and is the `rpc_signal` on the next line. Those names can be a string list on that same create. The server subscribes before it returns the lease. No change to when `.new` is sent.

**Known only after JavaScript runs.** `set_reactive`, style class, `set_text`, and a later `connect` happen once the lease exists, so each is its own call. They join the create only if the create waits. Hold type, hooks, property writes, and signal names on the stub while `rpc_lid` is still 0. Flush on the first call that needs the server actor. In this trace that call is `St-Bin.set_child` / `add_child` (row 2). Setters and subscribes before that flush stay off the wire.

## Proposed code — pack into one create

**⏳ 🔷** One create per actor carries the construct-time signal list and the property writes JavaScript makes before the actor is parented. `add_child` / `set_child` stay their own call (row 2 is not in this diff). Row 3 is not in this diff.

**ℹ️** Stock icons take `alias + ".new"` (`St-Button.new`). GJS subclasses take `Helper-Actor.create`. Both then call `signal_overrides`, which is the `rpc_signal` on the next line. JavaScript setters run after the lease exists. `Signals.connect` returns 0 when `rpc_lid` is 0, so a connect during a delayed create would be dropped unless it is queued.

**⏳** Subscribing inside that create depends on [`OLLMchat` `docs/bugs/2026-09-29-subscribe-without-reply.md`](../../../OLLMchat/docs/bugs/2026-09-29-subscribe-without-reply.md). `Subscribe.attach` connects the signal and does not write a reply. This bug calls it. It does not add a second copy of the closure.

**🚫** Do not add arguments to generated `St-Button.new`. Gi owns that signature.

**🚫** Do not queue getters, `allocate`, `add_child`, or `set_child`. Those flush, then run. The allow-list is the switch below. A name that is not a case is not packed.

### ⏳ 🔷 `Actor` fields

**Where:** `src/gi-stub/overrides-clutter/Actor.override.vala`, the fields under `construct`.

**Replace:**

```vala
	protected bool helper_attached;
	bool relayout_queued;
	/* Stock ClutterActor:visible default TRUE — the flag, not is_visible(). */
	bool actor_visible = true;
	double cached_scale_x = 1.0;
	double cached_scale_y = 1.0;
	string actor_name = "";
	bool name_known = false;
```

**Replace with:**

```vala
	protected bool helper_attached;
	bool relayout_queued;
	/* Stock ClutterActor:visible default TRUE — the flag, not is_visible(). */
	bool actor_visible = true;
	double cached_scale_x = 1.0;
	double cached_scale_y = 1.0;
	string actor_name = "";
	bool name_known = false;
	bool minted;
	bool pack_helper;
	string pack_alias = "";
	string[] pack_hook_names = {};
	GLib.Variant? pack_vfunc_ids;
	GLib.Variant? pack_hook_ids;
	Gee.ArrayList<string> pack_methods = new Gee.ArrayList<string>();
	Gee.ArrayList<Gee.ArrayList<GLib.Value?>> pack_args =
		new Gee.ArrayList<Gee.ArrayList<GLib.Value?>>();
	Gee.ArrayList<string> pack_signals = new Gee.ArrayList<string>();
```

### ⏳ 🔷 `construct` records the create and returns

**Where:** `construct`, from the lease check through the alias switch.

**Replace:**

```vala
		if (this.rpc_lid != 0) {
			return;
		}
		var t = this.get_type();
		while (t != GLib.Type.INVALID) {
			if (OLLMrpc.Bin.gtype_to_alias == null
					|| !OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
				t = t.parent();
				continue;
			}
			var alias = OLLMrpc.Bin.gtype_to_alias.get(t);
			switch (alias) {
				case "Meta-BackgroundActor": // leaf Helper
				case "Clutter-Clone": // Clone.override new(source)
					return;
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
				default:
					break;
			}
			var response = GnomeShellRpc.call_value(alias + ".new");
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
			GnomeShellRpc.GiStub.Runtime.register_handle(this);
			this.signal_overrides(this.get_type());
			return;
		}
```

**Replace with:**

```vala
		if (this.rpc_lid != 0) {
			this.minted = true;
			return;
		}
		var t = this.get_type();
		while (t != GLib.Type.INVALID) {
			if (OLLMrpc.Bin.gtype_to_alias == null
					|| !OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
				t = t.parent();
				continue;
			}
			var alias = OLLMrpc.Bin.gtype_to_alias.get(t);
			switch (alias) {
				case "Meta-BackgroundActor": // leaf Helper
				case "Clutter-Clone": // Clone.override new(source)
					this.minted = true;
					return;
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
				default:
					break;
			}
			this.pack_alias = alias;
			this.signal_overrides(this.get_type());
			return;
		}
```

`create_with_overrides` collects the hook list and the signal names. The stock arm stores `pack_alias` and the same signal names. Neither sends `.new`.

### ⏳ 🔷 `create_with_overrides` stores the hook list

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
		string[] always = {};
		var overridden = GnomeShellRpc.GiStub.VfuncRelay.overridden(
			this.get_type(), "Clutter", "Actor", "StWidget", always);
		/*
		 * Callbacks do not need a lease. Register them now. The lease
		 * comes back from flush_pack, after the server has stored the map.
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
		this.pack_helper = true;
		this.pack_hook_names = names;
		this.pack_vfunc_ids = vfunc_ids.end();
		this.pack_hook_ids = hook_ids.end();
		this.signal_overrides(this.get_type());
	}
```

### ⏳ 🔷 `signal_overrides` records the name

**Replace:**

```vala
		foreach (var name in OLLMrpc.Gi.vfunc_names(ns, class_name)) {
			var ours = OLLMrpc.Gi.vfunc_slot(leaf, ns, class_name, name);
			var plain = OLLMrpc.Gi.vfunc_slot(t, ns, class_name, name);
			if (ours == plain) {
				continue;
			}
			var signal_name = name.replace("_", "-");
			if (GLib.Signal.lookup(signal_name, leaf) == 0) {
				continue;
			}
			GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(this, signal_name);
		}
	}
```

**Replace with:**

```vala
		foreach (var name in OLLMrpc.Gi.vfunc_names(ns, class_name)) {
			var ours = OLLMrpc.Gi.vfunc_slot(leaf, ns, class_name, name);
			var plain = OLLMrpc.Gi.vfunc_slot(t, ns, class_name, name);
			if (ours == plain) {
				continue;
			}
			var signal_name = name.replace("_", "-");
			if (GLib.Signal.lookup(signal_name, leaf) == 0) {
				continue;
			}
			this.pack_signals.add(signal_name);
		}
	}

	internal void flush_pack()
	{
		if (this.minted) {
			return;
		}
		this.minted = true;
		if (this.pack_helper) {
			this.flush_helper();
			return;
		}
		this.flush_stock();
	}

	void flush_helper()
	{
		var response = GnomeShellRpc.call_value(
			"Helper-Actor.create", null,
			OLLMrpc.args("sSvvSS",
				this.get_type().name(),
				this.pack_hook_names,
				this.pack_vfunc_ids,
				this.pack_hook_ids,
				this.pack_signal_names(),
				Actor.pack_blob(this.pack_methods, this.pack_args)));
		this.rpc_lid = response.args.get(0).get_uint64();
		this.helper_attached = true;
		this.finish_flush();
	}

	void flush_stock()
	{
		var response = GnomeShellRpc.call_value(
			"Helper-St.pack", null,
			OLLMrpc.args("sSS",
				this.pack_alias,
				this.pack_signal_names(),
				Actor.pack_blob(this.pack_methods, this.pack_args)));
		this.rpc_lid =
			(response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
		this.finish_flush();
	}

	void finish_flush()
	{
		GnomeShellRpc.GiStub.Runtime.register_handle(this);
		foreach (var name in this.pack_signals) {
			Shell.Signals.remember(this, name);
		}
	}

	string[] pack_signal_names()
	{
		string[] names = {};
		foreach (var name in this.pack_signals) {
			names += name;
		}
		return names;
	}
```

`pack_blob` is an `a(sv)`: method name, then that call's one argument as a variant. `flush_pack` does not take `add_child` or `set_child`. The caller flushes, then sends that call.

### ⏳ 🔷 `call_value` queues or flushes before `lease_id_of`

**Where:** `src/namespace.vala` `call_value`.

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
		if (actor != null && actor.queue_or_flush(method, args)) {
			return new OLLMrpc.Response();
		}
		uint64 lease_id = 0;
		if (instance != null) {
			lease_id = GiStub.Runtime.lease_id_of(instance, method);
		}
```

The rest of `call_value` stays. `queue_or_flush` on `Clutter.Actor`:

```vala
	internal bool queue_or_flush(string method, Gee.ArrayList<GLib.Value?>? args)
	{
		if (this.minted) {
			return false;
		}
		this.flush_arg_actors(args);
		if (!Actor.packable_setter(method, args)) {
			this.flush_pack();
			return false;
		}
		this.pack_methods.add(method);
		var stored = args;
		if (stored == null) {
			stored = new Gee.ArrayList<GLib.Value?>();
		}
		this.pack_args.add(stored);
		return true;
	}

	void flush_arg_actors(Gee.ArrayList<GLib.Value?>? args)
	{
		if (args == null) {
			return;
		}
		foreach (var val in args) {
			this.flush_arg_actor(val);
		}
	}

	void flush_arg_actor(GLib.Value val)
	{
		if (!val.type().is_a(GLib.Type.OBJECT)) {
			return;
		}
		var child = val.get_object() as Clutter.Actor;
		if (child == null || child.minted) {
			return;
		}
		child.flush_pack();
	}
```

### ⏳ 🔷 Which setters pack

The wire prefix is `St-Button`, `St-Widget`, `Clutter-Actor`, and the rest. The switch is the name after the last dot, split into the actor methods and the St methods. A getter, `add_child`, or `set_child` is the default and flushes.

```vala
	internal static bool packable_setter(
		string method,
		Gee.ArrayList<GLib.Value?>? args
	) {
		if (args == null || args.size != 1) {
			return false;
		}
		return Actor.packable_name(Actor.method_tail(method));
	}

	static string method_tail(string method)
	{
		var dot = method.last_index_of_char('.');
		if (dot < 0) {
			return method;
		}
		return method.substring(dot + 1);
	}

	static bool packable_name(string name)
	{
		if (Actor.packable_actor(name)) {
			return true;
		}
		return Actor.packable_st(name);
	}

	static bool packable_actor(string name)
	{
		switch (name) {
			case "set_reactive":
			case "set_x_expand":
			case "set_y_expand":
			case "set_x_align":
			case "set_y_align":
			case "set_pivot_point":
			case "set_layout_manager":
			case "hide":
			case "show":
				return true;
			default:
				return false;
		}
	}

	static bool packable_st(string name)
	{
		switch (name) {
			case "set_can_focus":
			case "set_track_hover":
			case "set_style_class_name":
			case "set_label_actor":
			case "set_orientation":
			case "set_text":
				return true;
			default:
				return false;
		}
	}
```

`hide` and `show` are actor cases. The 667 initial `hide` calls ride in the bag. A `show` before parenting stays as a later entry, in order.

### ⏳ 🔷 `Signals.connect` while there is no lease

**Where:** `src/shell-gi/Signals.vala` `connect`, after the `init-xserver` check.

**Replace:**

```vala
			GnomeShellRpc.GiStub.Runtime.register();
			var handle = obj as OLLMrpc.Live.Interface;
			if (handle == null || handle.rpc_lid == 0) {
				return 0;
			}
			if (!Signals.exists_on_peer(obj, signal_name)) {
				return 0;
			}
```

**Replace with:**

```vala
			GnomeShellRpc.GiStub.Runtime.register();
			var handle = obj as OLLMrpc.Live.Interface;
			if (handle == null) {
				return 0;
			}
			if (handle.rpc_lid == 0) {
				return Signals.queue_unminted(obj, signal_name, gjs_handler_id);
			}
			if (!Signals.exists_on_peer(obj, signal_name)) {
				return 0;
			}
```

`queue_unminted` follows `connect`:

```vala
		static int queue_unminted(GLib.Object obj, string signal_name, int gjs_handler_id)
		{
			var actor = obj as Clutter.Actor;
			if (actor == null || actor.minted) {
				return 0;
			}
			actor.pack_signals.add(signal_name);
			return Signals.remember(obj, signal_name, gjs_handler_id);
		}
```

`remember` is the current tail of `connect`: the `subs` / `refs` / `gjs_ids` inserts, and not the `RPC-Live-Subscribe.rpc_signal` call. `connect` calls `remember` after a real subscribe as well. A connect after `flush_pack` still sends `rpc_signal`.

### ⏳ 🔷 `Helper-Actor.create` takes the lists

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
				"create", "sSvvSS",
				"add_hook", "it",
```

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
		public void create(
			OLLMrpc.Request request,
			string type_name,
			string[] names,
			GLib.Variant vfunc_ids,
			GLib.Variant hook_ids,
			string[] signals,
			GLib.Variant bag
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
			var handle = (uint64) request.connection.export(created);
			this.attach_signals(request.connection, (int) handle, signals);
			this.apply_bag(request.connection, created, bag);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		void attach_signals(
			OLLMrpc.Transport.Connection connection,
			int id,
			string[] signals
		) {
			foreach (var name in signals) {
				OLLMrpc.Live.Subscribe.attach(connection, id, name);
			}
		}
```

`Subscribe.attach` is the OLLMchat bug above. `apply_bag` walks the `a(sv)` and runs each setter on `created` in order. An object value is `connection.leases`. An unknown method is `reply_error` `-32601` before the success reply.

### ⏳ 🔷 `Helper-St.pack` for a stock `.new`

**Where:** `src/rpc/helper/St.vala`. `mint` stays the `g_object_new` path for `St-Widget` / `St-DrawingArea` / `St-Viewport`. Stock icons (`St-Button` and the rest) go through `pack` instead of generated `.new`.

**Replace:**

```vala
		public static void rpc_register()
		{
			var helper = new St();
			OLLMrpc.Request.add_class("St-Widget", typeof(St), "new", "", null);
			OLLMrpc.Request.register_live("St-Widget", helper);
			OLLMrpc.Request.add_class("St-DrawingArea", typeof(St), "new", "", null);
			OLLMrpc.Request.register_live("St-DrawingArea", helper);
			OLLMrpc.Request.add_class("St-Viewport", typeof(St), "new", "", null);
			OLLMrpc.Request.register_live("St-Viewport", helper);
		}
```

**Replace with:**

```vala
		public static void rpc_register()
		{
			var helper = new St();
			OLLMrpc.Request.add_class("St-Widget", typeof(St), "new", "", null);
			OLLMrpc.Request.register_live("St-Widget", helper);
			OLLMrpc.Request.add_class("St-DrawingArea", typeof(St), "new", "", null);
			OLLMrpc.Request.register_live("St-DrawingArea", helper);
			OLLMrpc.Request.add_class("St-Viewport", typeof(St), "new", "", null);
			OLLMrpc.Request.register_live("St-Viewport", helper);
			OLLMrpc.Request.add_class(
				"Helper-St", typeof(St),
				"pack", "sSS",
				null);
			OLLMrpc.Request.register_live("Helper-St", helper);
		}
```

`pack` follows `mint`: alias `"St-Button"` becomes GType `"StButton"`, `g_object_new`, `export`, then the same `attach_signals` and `apply_bag` as `create`, then `mint`'s object reply.

**⏳ 🔷** Rows 4–6 after that, same shape as `name` / `scale_x` in `Actor.override.vala`. Preferred size only with the invalidation in row 4. A stale size is a wrong allocation.

**🚫** Leave on the wire: `get_actor_at_pos` (330), `allocate` (513), `RPC-Live-Callback.reply` (2,034), `captured-event`, `before-update`. Those are the pointer and the frame.

**🚫** Do not skip the first set of a property by pretending the construct default was already sent. That first set is row 1, where it still crosses the wire once, inside the create.
