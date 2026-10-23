# Actor construct lease is a switch

**Status:** ✔️ applied, then a Wayland regression. `Gjs_ui_barLevel_BarLevel` and `Gjs_ui_slider_Slider` stay at `rpc_lid` 0. Exact `St.DrawingArea` still leases. Not user-confirmed.

**Next:** The constructor fallback did not change what the session shows. Log `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` session `09:05:11`. App grid: `createIcon in BaseIcon` 168 times, first at `09:05:12.937074`. Overview: `ClutterActorBox` undefined and `clutter_margin_copy` missing at `09:05:20.541775`. One `create_launcher`, at startup `09:05:13.621268`.

Child, not applied: [`2026-10-23-construct-style-during-init.md`](2026-10-23-construct-style-during-init.md). Signal `rpc_lease`, no body. Handlers connect with `Signal.override_class_handler`.

**Proposal:** ✔️ applied. [Proposed changes](#proposed-changes). Each special class overrides `rpc_construct`. The default walk only calls `alias + ".new"`. A parent calls `base.rpc_construct()` when a derived type is the registered one, so `St.Button` still gets `St-Button.new`. Two deviations are in the 08:30 effort.

Split from [`done/2026-10-12-applications-picker-not-working.md`](done/2026-10-12-applications-picker-not-working.md).

- Pagination: [`2026-10-22-app-grid-pagination.md`](2026-10-22-app-grid-pagination.md)
- Performance: [`2026-10-22-app-grid-performance.md`](2026-10-22-app-grid-performance.md)
- Parent walk: [`done/2026-09-06-lease-construct-base-steals-leaf.md`](done/2026-09-06-lease-construct-base-steals-leaf.md)

Vala runs `construct` **base first**. On a local `new`, `rpc_lid` is `0`. Actor's construct runs first and is the one that leases. Later constructs see a non-zero lid and return. Wire import sets `rpc_lid` before any construct, so this whole block returns at the guard.

A made-up alias cannot replace an arm. `Gi.vfunc_names` splits on the first hyphen and looks the name up in the typelib. `Gsr-St-SquareBin` aborted with `no object Gsr.St-SquareBin`.

## Current construct

`src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala`:

```vala
construct {
    this.signal_queue_relayout.connect(() => {
        var baseline = GLib.Type.from_name("StWidget");
        if (baseline != GLib.Type.INVALID
                && OLLMrpc.Gi.vfunc_slot(this.get_type(), "Clutter", "Actor", "queue_relayout")
                != OLLMrpc.Gi.vfunc_slot(baseline, "Clutter", "Actor", "queue_relayout")) {
            Gsr.Client.Rpc.vfunc_call_void(
                this, OLLMrpc.Gi.vfunc_offset("Clutter", "Actor", "queue_relayout"));
        }
    });

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
            case "St-DrawingArea": // DrawingArea.construct
                return;
            case "Meta-WindowActor": // no Meta-WindowActor.new
            case "St-Widget":
                this.create_with_overrides();
                this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
                this.prop_batch_open = true;
                return;
            case "St-Viewport":
                /* Exact Viewport uses St-Viewport.new below.
                   A subclass leases ViewportActor. */
                if (this.get_type() == t) {
                    break;
                }
                this.create_viewport();
                this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
                this.prop_batch_open = true;
                return;
            case "St-Bin":
                // Exact bin uses St-Bin.new below. Shell.SquareBin leases the
                //  square peer before the icon is built.
                if (this.get_type() == t) {
                    break;
                }
                var scan = this.get_type();
                var square = false;
                while (scan != GLib.Type.INVALID) {
                    if (scan.name() == "ShellSquareBin") {
                        square = true;
                        break;
                    }
                    scan = scan.parent();
                }
                if (!square) {
                    break;
                }
                var response = Gsr.Client.Rpc.call_value("Gsr-St-SquareBin.new", null,
                    OLLMrpc.args("t", (uint64) 0));
                this.rpc_lid = (response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
                Gsr.Client.Rpc.register_handle(this);
                this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
                this.prop_batch_open = true;
                return;
            case "Clutter-Actor":
                /* Exact Actor → .new. GJS/Vala subclasses need Helper hooks. */
                if (this.get_type() == typeof(Actor)) {
                    break;
                }
                this.create_with_overrides();
                this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
                this.prop_batch_open = true;
                return;
            default:
                break;
        }
        var response = Gsr.Client.Rpc.call_value(alias + ".new");
        this.rpc_lid =
            (response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
        Gsr.Client.Rpc.register_handle(this);
        this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
        this.prop_batch_open = true;
        return;
    }
    GLib.error("lease construct: no Bin-registered ancestor for %s",
        this.get_type().name());
}
```

`break` falls through to `alias + ".new"`. `return` on the first three arms leaves `rpc_lid == 0` so the leaf construct leases.

The generator still emits the parent walk on other classes (`emit_lease_construct`, LOCKED). Actor's override is the one that runs for this tree.

## RPC pairs the switch chooses

**Stock.** Client `call_value(alias + ".new")`. Server is the typelib constructor. `new St.Bin()` → `St-Bin.new` → a plain `St.Bin`.

**Square bin.** Client in the `St-Bin` arm, and again in `Shell.SquareBin.construct` if the lid is still `0`:

```vala
Gsr.Client.Rpc.call_value("Gsr-St-SquareBin.new", null,
    OLLMrpc.args("t", (uint64) 0));
```

Server `Gsr.Server.St.SquareBin.mint` (`src/server/libst-16/SquareBinActor.vala`). Drops `old_lid` when it is not `0`, exports a `SquareBinActor` (an `St.Bin` whose preferred width is its preferred height), replies with that object. `St-Bin.new` stays a plain bin. `register_alias("St-Bin", typeof(SquareBinActor))` is so later `add_child` accepts this GType. It does not make the client walk call this RPC.

**Subclass with hooks.** `create_with_overrides` calls:

```vala
Gsr.Client.Rpc.call_value("Gsr-Clutter-Actor.create", null,
    OLLMrpc.args("s", this.get_type().name()));
```

Server `Gsr.Server.Clutter.Actor.create` (`src/server/libmutter-clutter-16/ClutterActor.vala`) exports a helper `Actor`, stores the client type name, replies with the lease id in `args`. Hooks are a second call, `Gsr-Clutter-Actor.add_hooks`. `create_viewport` is the same shape against `Gsr-St-Viewport.create`.

## Proposed changes

Edits are **Remove** / **Replace with** / **Add**. Verify the surrounding lines before applying.

- 🔷 `construct` calls `rpc_construct`, then subscribes signals and opens the property batch when `rpc_lid` is set.
- 🔷 `Shell.SquareBin`, `St.Widget`, `St.Viewport`, `Meta.WindowActor`, `Meta.BackgroundActor`, `Clutter.Clone`, and `St.DrawingArea` each override `rpc_construct` with the lease that used to be their switch arm.
- 🔷 A parent override calls `base.rpc_construct()` when a more-derived type is already in `gtype_to_alias`. `St.Button` inherits `St.Widget.rpc_construct` and that call reaches `St-Button.new`.
- 🔷 Exact `Clutter.Actor` versus a subclass with no registered type stays in `Actor.rpc_construct`. That rule is Actor's own.
- 🔷 `signal_queue_relayout` stays on `Actor`. Connect only when `VfuncRelay.overridden` says this type replaced that slot. The handler does not compare slots. A non-widget subclass still reaches it because the block is on `Actor`. Vala allows one `construct` on the class, so this connect is the first part of the lease `construct`, before the `rpc_lid` guard.
- 🚫 Defer set, mint kind on `Bin.register`, a `GType` callback map, generating the switch, and a second lease in every leaf `construct`.

### 1. `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` — `construct` calls `rpc_construct`

**Why:** `construct` calls one virtual. The default body is the parent walk and `alias + ".new"`. It has no arm per type. `gtype_to_alias` is created by the first `Bin.register`, and class init has already registered before this `construct` runs, so the walk does not test the map for null. `create_with_overrides` stays here and becomes `protected`: this walk calls it for an unregistered `Clutter.Actor` subclass, and `St.Widget` and `Meta.WindowActor` call the same method. `create_viewport`, `open_drawing_area_lease`, and `create_drawing_area` move to the class that calls them.

**Where:** The doc comment and `construct` that walk `gtype_to_alias`. The virtual is the next member, before `helper_attached`.

**Depends on:** none.

#### Remove

```vala
	/**
	 * Lease like the generator parent-walk ({@code Actor.new} denied).
	 * First Bin-registered ancestor; {@code St-Widget} and
	 * {@code Meta-WindowActor} → {@code this.create_with_overrides()}.
	 *
	 * {@code Meta-BackgroundActor}: leave {@code rpc_lid == 0} for the leaf
	 * Helper construct. Stock ctor needs display+monitor; null-arg
	 * {@code Meta-BackgroundActor.new} is -32602. Do not walk to
	 * {@code Clutter-Actor} (wrong peer / double mint).
	 */
	construct {
		this.signal_queue_relayout.connect(() => {
			var baseline = GLib.Type.from_name("StWidget");
			if (baseline != GLib.Type.INVALID
					&& OLLMrpc.Gi.vfunc_slot(this.get_type(), "Clutter", "Actor", "queue_relayout")
					!= OLLMrpc.Gi.vfunc_slot(baseline, "Clutter", "Actor", "queue_relayout")) {
						
				Gsr.Client.Rpc.vfunc_call_void(
					this, OLLMrpc.Gi.vfunc_offset("Clutter", "Actor", "queue_relayout"));
			}
		});

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
				case "St-DrawingArea": // DrawingArea.construct
					return;
				case "Meta-WindowActor": // no Meta-WindowActor.new
				case "St-Widget":
					this.create_with_overrides();
					this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
					this.prop_batch_open = true;
					return;
				case "St-Viewport":
					/* Exact Viewport uses St-Viewport.new below.
					   A subclass leases ViewportActor. */
					if (this.get_type() == t) {
						break;
					}
					this.create_viewport();
					this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
					this.prop_batch_open = true;
					return;
				case "St-Bin":
					// Exact bin uses St-Bin.new below. Shell.SquareBin leases the 
					//  square peer before the icon is built. 
					//  This is very hacky however - and probably needs a better design.
					if (this.get_type() == t) {
						break;
					}
					var scan = this.get_type();
					var square = false;
					while (scan != GLib.Type.INVALID) {
						if (scan.name() == "ShellSquareBin") {
							square = true;
							break;
						}
						scan = scan.parent();
					}
					if (!square) {
						break;
					}
					var response = Gsr.Client.Rpc.call_value("Gsr-St-SquareBin.new", null,
						OLLMrpc.args("t", (uint64) 0));

					this.rpc_lid = (response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
					Gsr.Client.Rpc.register_handle(this);
					this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
					this.prop_batch_open = true;
					return;
				case "Clutter-Actor":
					/* Exact Actor → .new. GJS/Vala subclasses need Helper hooks. */
					if (this.get_type() == typeof(Actor)) {
						break;
					}
					this.create_with_overrides();
					this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
					this.prop_batch_open = true;
					return;
				default:
					break;
			}
			var response = Gsr.Client.Rpc.call_value(alias + ".new");
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
			Gsr.Client.Rpc.register_handle(this);
			this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
			this.prop_batch_open = true;
			return;
		}
		GLib.error("lease construct: no Bin-registered ancestor for %s",
			this.get_type().name());
	}
```

#### Replace with

```vala
	/**
	 * Local {@code new} calls {@link rpc_construct}. Wire import
	 * already has {@code rpc_lid} and returns above that call.
	 * After a lease, subscribe overridden signals and open the
	 * property batch.
	 */
	construct {
		if (this.rpc_lid != 0) {
			return;
		}
		this.rpc_construct();
		if (this.rpc_lid == 0) {
			return;
		}
		this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
		this.prop_batch_open = true;
	}

	/**
	 * Lease the server peer on a local {@code new}.
	 *
	 * Walk {@code Bin.gtype_to_alias} and call {@code alias.new}.
	 * A subclass of exact {@code Clutter.Actor} with no registered
	 * type of its own uses {@code create_with_overrides}.
	 * Other peers override this method.
	 */
	protected virtual void rpc_construct()
	{
		var t = this.get_type();
		while (t != GLib.Type.INVALID) {
			if (!OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
				t = t.parent();
				continue;
			}
			if (t == typeof(Actor) && this.get_type() != typeof(Actor)) {
				this.create_with_overrides();
				return;
			}
			var alias = OLLMrpc.Bin.gtype_to_alias.get(t);
			var response = Gsr.Client.Rpc.call_value(alias + ".new");
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
			Gsr.Client.Rpc.register_handle(this);
			return;
		}
		GLib.error("lease construct: no Bin-registered ancestor for %s",
			this.get_type().name());
	}
```

#### Remove

```vala
	void create_with_overrides()
```

#### Replace with

Subclasses in `St` and `Meta` call this from their `rpc_construct`.

```vala
	protected void create_with_overrides()
```

#### Remove

`create_viewport` moves to §5. `open_drawing_area_lease` and `create_drawing_area` move to §8. Nothing else calls them.

```vala
	/**
	 * {@code subclass} is decided by {@link St.DrawingArea}, where
	 * {@code typeof(DrawingArea)} exists. A subclass gets the
	 * drawing-area peer. The exact type gets {@code St-DrawingArea.new}.
	 */
	protected void open_drawing_area_lease(bool subclass)
	{
		if (subclass) {
			this.create_drawing_area();
			this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
			this.prop_batch_open = true;
			return;
		}
		var response = Gsr.Client.Rpc.call_value("St-DrawingArea.new");
		this.rpc_lid =
			(response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
		Gsr.Client.Rpc.register_handle(this);
		this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
		this.prop_batch_open = true;
	}

	/**
	 * Peer is {@link Gsr.Server.St.DrawingAreaActor}, not a plain
	 * {@code StDrawingArea}. Preferred-size vfuncs are hooked so a
	 * slider's JS height is the allocation. Repaint stays the
	 * stock allocate emission.
	 */
	void create_drawing_area()
	{
		Gsr.Client.Rpc.hook_rows = new Gee.ArrayList<Gsr.Client.Rpc.InvokeRow>();
		var overridden = Gsr.Client.Rpc.VfuncRelay.overridden(
			this.get_type(), "Clutter", "Actor", "StWidget", new string[0]);
			
		string[] names = {};
		var vfunc_ids = new GLib.VariantBuilder(new GLib.VariantType("ai"));
		foreach (var name in overridden) {
			if (name != "get_preferred_width" && name != "get_preferred_height") {
				continue;
			}
			var vfunc_id = -1;
			var hook_id = this.bind_vfunc(name, out vfunc_id);
			if (hook_id == 0) {
				continue;
			}
			names += name;
			vfunc_ids.add("i", vfunc_id);
		}
		var response = Gsr.Client.Rpc.call_value("Gsr-St-DrawingArea.create", null,
			OLLMrpc.args("s", this.get_type().name()));
			
		this.rpc_lid = response.args.get(0).get_uint64();
		Gsr.Client.Rpc.register_handle(this);
		if (names.length == 0) {
			Gsr.Client.Rpc.hook_rows = null;
			return;
		}
		var hooks = Gsr.Client.Rpc.call_value("Gsr-St-DrawingArea.add_hooks", this,
			OLLMrpc.args("Sv", names, vfunc_ids.end()));
			
		var ids = hooks.args.get(0).get_variant();
		if (Gsr.Client.Rpc.handlers == null) {
			Gsr.Client.Rpc.handlers = new Gee.HashMap<int,	Gsr.Client.Rpc.InvokeRow>();
		}
		var n = (int) ids.n_children();
		for (var i = 0; i < n; i++) {
			var id = ids.get_child_value(i).get_uint64();
			Gsr.Client.Rpc.handlers.set((int) id, Gsr.Client.Rpc.hook_rows.get(i));
		}
		Gsr.Client.Rpc.hook_rows = null;
	}

	/**
	 * GJS {@code St.Viewport} subclass. Peer is
	 * {@link Gsr.Server.St.ViewportActor}. Only {@code allocate}
	 * is hooked. {@code helper_attached} stays false.
	 */
	void create_viewport()
	{
		Gsr.Client.Rpc.hook_rows = new Gee.ArrayList<Gsr.Client.Rpc.InvokeRow>();
		var overridden = Gsr.Client.Rpc.VfuncRelay.overridden(
			this.get_type(), "Clutter", "Actor", "StWidget", new string[0]);
			
		string[] names = {};
		var vfunc_ids = new GLib.VariantBuilder(new GLib.VariantType("ai"));
		foreach (var name in overridden) {
			if (name != "allocate") {
				continue;
			}
			var vfunc_id = -1;
			var hook_id = this.bind_vfunc(name, out vfunc_id);
			if (hook_id == 0) {
				continue;
			}
			names += name;
			vfunc_ids.add("i", vfunc_id);
		}
		var response = Gsr.Client.Rpc.call_value("Gsr-St-Viewport.create", null);
			
		this.rpc_lid = response.args.get(0).get_uint64();
		Gsr.Client.Rpc.register_handle(this);
		if (names.length == 0) {
			Gsr.Client.Rpc.hook_rows = null;
			return;
		}
		var hooks = Gsr.Client.Rpc.call_value("Gsr-St-Viewport.add_hooks", this,
			OLLMrpc.args("Sv", names, vfunc_ids.end()));
			
		var ids = hooks.args.get(0).dup_variant();
		if (Gsr.Client.Rpc.handlers == null) {
			Gsr.Client.Rpc.handlers = new Gee.HashMap<int,	Gsr.Client.Rpc.InvokeRow>();
		}
		var n = (int) ids.n_children();
		for (var i = 0; i < n; i++) {
			Gsr.Client.Rpc.handlers.set((int) ids.get_child_value(i).get_uint64(), Gsr.Client.Rpc.hook_rows.get(i));
		}
		Gsr.Client.Rpc.hook_rows = null;
	}
```

**Why:** The lease `construct` should not compare vfunc slots. `VfuncRelay.overridden` already caches that compare against `StWidget`. Connect only for a type that replaced `queue_relayout`. The handler is the vfunc call. A second `construct` on `Actor` does not compile (`class already contains a constructor`), so the connect is the start of the lease `construct`. The `rpc_lid` guard stays after it, so wire import still connects.

**Where:** The start of the lease `construct` in §1.

**Depends on:** §1.

#### Add — start of the lease `construct`

```vala
		var over = Gsr.Client.Rpc.VfuncRelay.overridden(
			this.get_type(), "Clutter", "Actor", "StWidget", new string[0]);
		if (over.contains("queue_relayout")) {
			this.signal_queue_relayout.connect(() => {
				Gsr.Client.Rpc.vfunc_call_void(
					this, OLLMrpc.Gi.vfunc_offset(
						"Clutter", "Actor", "queue_relayout"));
			});
		}
```

### 2. `src/client/libshell-16/SquareBin.vala` — `rpc_construct` leases the square peer

**Why:** This is the arm that scanned `ShellSquareBin`. The override runs while `Actor.construct` is on the stack. A GJS subclass inherits it.

**Where:** The class doc comment, and the `construct` that calls `Gsr-St-SquareBin.new`. `Actor.construct` subscribes signals after this returns.

**Depends on:** §1.

#### Remove

```vala
 * {@link Clutter.Actor} construct leases {@code Gsr-St-SquareBin.new}
 * for this type. This construct does that only when nothing
 * is leased yet.
```

#### Replace with

```vala
 * {@code rpc_construct} leases {@code Gsr-St-SquareBin.new}.
 * A GJS subclass inherits this override.
```

#### Remove

```vala
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var t = this.get_type();
			if (t != typeof(SquareBin) && !t.name().has_prefix("Gjs_")) {
				return;
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-St-SquareBin.new", null,
				OLLMrpc.args("t", (uint64) 0));
			var stub = response.retval.get_object() as OLLMrpc.Live.Interface;
			this.rpc_lid = stub.rpc_lid;
			Gsr.Client.Rpc.register_handle(this);
		}

```

#### Replace with

```vala
		/**
		 * Square peer. {@code St-Bin.new} stays a plain bin.
		 * {@code Actor.construct} subscribes signals after this.
		 */
		public override void rpc_construct()
		{
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-St-SquareBin.new", null,
				OLLMrpc.args("t", (uint64) 0));
			var stub = response.retval.get_object() as OLLMrpc.Live.Interface;
			this.rpc_lid = stub.rpc_lid;
			Gsr.Client.Rpc.register_handle(this);
		}

```

### 3. `src/client/libst-rpc-16/overrides/Widget.override.vala` — `rpc_construct`

**Why:** This is the `St-Widget` arm. `St.Button` inherits the method, so a registered derived type calls `base.rpc_construct()` and the base walk calls `St-Button.new`.

**Where:** Immediately above the existing `construct`.

**Depends on:** §1.

#### Add — above `construct`

```vala
		/**
		 * Helper peer when this widget is the registered type.
		 * A derived stub calls the base walk.
		 */
		public override void rpc_construct()
		{
			var t = this.get_type();
			while (t != GLib.Type.INVALID && t != typeof(Widget)) {
				if (OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
					base.rpc_construct();
					return;
				}
				t = t.parent();
			}
			this.create_with_overrides();
		}

```

### 4. `src/client/libmutter-rpc-16/overrides/WindowActor.override.vala` — `rpc_construct`

**Why:** This is the `Meta-WindowActor` arm. There is no `Meta-WindowActor.new`. A registered derived type uses the base walk.

**Where:** Top of the class body, before `bound_meta_window`.

**Depends on:** §1.

#### Add — before `bound_meta_window`

```vala
		/**
		 * Helper peer. There is no {@code Meta-WindowActor.new}.
		 * A registered derived type uses the base walk.
		 */
		public override void rpc_construct()
		{
			var t = this.get_type();
			while (t != GLib.Type.INVALID && t != typeof(WindowActor)) {
				if (OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
					base.rpc_construct();
					return;
				}
				t = t.parent();
			}
			this.create_with_overrides();
		}

```

### 5. `src/client/libst-rpc-16/overrides/Viewport.override.vala` — `rpc_construct`

**Why:** Exact `St.Viewport` uses `St-Viewport.new` via the base walk. A subclass uses `create_viewport`. That method moves here. Only this class calls it. `bind_vfunc` is Actor's; Viewport does not declare its own.

**Where:** Top of the override, before `hadjustment`.

**Depends on:** §1.

#### Add — before `hadjustment`

```vala
		/**
		 * Exact viewport uses {@code St-Viewport.new}.
		 * A subclass leases {@code ViewportActor}.
		 */
		public override void rpc_construct()
		{
			var t = this.get_type();
			while (t != GLib.Type.INVALID && t != typeof(Viewport)) {
				if (OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
					base.rpc_construct();
					return;
				}
				t = t.parent();
			}
			if (this.get_type() == typeof(Viewport)) {
				base.rpc_construct();
				return;
			}
			this.create_viewport();
		}

		/**
		 * GJS {@code St.Viewport} subclass. Peer is
		 * {@link Gsr.Server.St.ViewportActor}. Only {@code allocate}
		 * is hooked. {@code helper_attached} stays false.
		 */
		void create_viewport()
		{
			Gsr.Client.Rpc.hook_rows = new Gee.ArrayList<Gsr.Client.Rpc.InvokeRow>();
			var overridden = Gsr.Client.Rpc.VfuncRelay.overridden(
				this.get_type(), "Clutter", "Actor", "StWidget", new string[0]);
			string[] names = {};
			var vfunc_ids = new GLib.VariantBuilder(new GLib.VariantType("ai"));
			foreach (var name in overridden) {
				if (name != "allocate") {
					continue;
				}
				var vfunc_id = -1;
				var hook_id = this.bind_vfunc(name, out vfunc_id);
				if (hook_id == 0) {
					continue;
				}
				names += name;
				vfunc_ids.add("i", vfunc_id);
			}
			var response = Gsr.Client.Rpc.call_value("Gsr-St-Viewport.create", null);
			this.rpc_lid = response.args.get(0).get_uint64();
			Gsr.Client.Rpc.register_handle(this);
			if (names.length == 0) {
				Gsr.Client.Rpc.hook_rows = null;
				return;
			}
			var hooks = Gsr.Client.Rpc.call_value("Gsr-St-Viewport.add_hooks", this,
				OLLMrpc.args("Sv", names, vfunc_ids.end()));
			var ids = hooks.args.get(0).dup_variant();
			if (Gsr.Client.Rpc.handlers == null) {
				Gsr.Client.Rpc.handlers = new Gee.HashMap<int, Gsr.Client.Rpc.InvokeRow>();
			}
			var n = (int) ids.n_children();
			for (var i = 0; i < n; i++) {
				Gsr.Client.Rpc.handlers.set(
					(int) ids.get_child_value(i).get_uint64(),
					Gsr.Client.Rpc.hook_rows.get(i));
			}
			Gsr.Client.Rpc.hook_rows = null;
		}

```

### 6. `src/client/libmutter-rpc-16/overrides/BackgroundActor.override.vala` — lease moves into `rpc_construct`

**Why:** `Meta-BackgroundActor.new` with no args is -32602. The Helper call is this class's lease. Construct properties are already set when `Actor.construct` calls the virtual.

**Where:** Replace `construct`.

**Depends on:** §1.

#### Remove

```vala
		/**
		 * Actor parent-walk defers here (null-arg {@code .new} is -32602).
		 * Wire import already has {@code rpc_lid} — skip remint.
		 */
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-BackgroundActor.create",
				null,
				OLLMrpc.args("oi", this.meta_display, this.monitor)
			);
			this.rpc_lid = response.args.get(0).get_uint64();
			/* Stock meta_background_actor_new attaches MetaBackgroundContent.
			 * Bind the client facade to that lease so content.background RPCs. */
			var content = new BackgroundContent();
			if (response.args.size > 1) {
				content.rpc_lid = response.args.get(1).get_uint64();
			}
			this.content = content;
		}
```

#### Replace with

Wire import returns from `Actor.construct` before this runs.

```vala
		/**
		 * Null-arg {@code Meta-BackgroundActor.new} is -32602.
		 * Lease the Helper. Bind the content peer it returns.
		 */
		public override void rpc_construct()
		{
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-BackgroundActor.create",
				null,
				OLLMrpc.args("oi", this.meta_display, this.monitor)
			);
			this.rpc_lid = response.args.get(0).get_uint64();
			/* Stock meta_background_actor_new attaches MetaBackgroundContent.
			 * Bind the client facade to that lease so content.background RPCs. */
			var content = new BackgroundContent();
			if (response.args.size > 1) {
				content.rpc_lid = response.args.get(1).get_uint64();
			}
			this.content = content;
		}
```

### 7. `src/client/libmutter-clutter-rpc-16/overrides/Clone.override.vala` — lease moves into `rpc_construct`

**Why:** `Clutter-Clone.new` needs `source`. `priv_source` is set before `construct` runs.

**Where:** The doc comment on `source`, and `construct`.

**Depends on:** §1.

#### Remove

```vala
		 * {@code { source }}. Actor parent construct skips this type.
```

#### Replace with

```vala
		 * {@code { source }}. {@code rpc_construct} passes it.
```

#### Remove

```vala
		construct {
			if (this.rpc_lid != 0) {
				this.mint_done = true;
				return;
			}
			var response = Gsr.Client.Rpc.call_value(
				"Clutter-Clone.new",
				null,
				OLLMrpc.args("o", this.priv_source));
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
			Gsr.Client.Rpc.register_handle(this);
			this.mint_done = true;
		}
```

#### Replace with

`construct` still marks a wire import, which never calls `rpc_construct`.

```vala
		/**
		 * Pass {@code priv_source}. A null-arg {@code .new} is -32602.
		 */
		public override void rpc_construct()
		{
			var response = Gsr.Client.Rpc.call_value(
				"Clutter-Clone.new",
				null,
				OLLMrpc.args("o", this.priv_source));
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
			Gsr.Client.Rpc.register_handle(this);
			this.mint_done = true;
		}

		construct {
			if (this.rpc_lid != 0) {
				this.mint_done = true;
			}
		}
```

### 8. `src/client/libst-rpc-16/overrides/DrawingArea.override.vala` — lease moves into `rpc_construct`

**Why:** The subclass-versus-exact choice is this class's lease. `open_drawing_area_lease` and `create_drawing_area` move here. The repaint hook stays in `construct`. `Actor.construct` subscribes signals after the lease, so the moved lease does not.

**Where:** The start of `construct`, through the lease call. The two methods go above that.

**Depends on:** §1.

#### Remove

```vala
		construct {
			if (this.rpc_lid == 0) {
				var subclass = this is DrawingArea
					&& this.get_type() != typeof(DrawingArea);
				this.open_drawing_area_lease(subclass);
			}
			if (this.rpc_lid == 0 || this.get_type() == typeof(DrawingArea)) {
```

#### Replace with

```vala
		/**
		 * Exact type uses {@code St-DrawingArea.new}.
		 * A subclass uses the drawing-area peer.
		 */
		public override void rpc_construct()
		{
			var subclass = this is DrawingArea
				&& this.get_type() != typeof(DrawingArea);
			this.open_drawing_area_lease(subclass);
		}

		construct {
			if (this.rpc_lid == 0 || this.get_type() == typeof(DrawingArea)) {
```

#### Add — above `rpc_construct`

`Actor.construct` subscribes signals and opens the property batch after this returns.

```vala
		/**
		 * Exact type uses {@code St-DrawingArea.new}.
		 * A subclass uses the drawing-area peer.
		 */
		void open_drawing_area_lease(bool subclass)
		{
			if (subclass) {
				this.create_drawing_area();
				return;
			}
			var response = Gsr.Client.Rpc.call_value("St-DrawingArea.new");
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
			Gsr.Client.Rpc.register_handle(this);
		}

		/**
		 * Peer is {@link Gsr.Server.St.DrawingAreaActor}, not a plain
		 * {@code StDrawingArea}. Preferred-size vfuncs are hooked so a
		 * slider's JS height is the allocation. Repaint stays the
		 * stock allocate emission.
		 */
		void create_drawing_area()
		{
			Gsr.Client.Rpc.hook_rows = new Gee.ArrayList<Gsr.Client.Rpc.InvokeRow>();
			var overridden = Gsr.Client.Rpc.VfuncRelay.overridden(
				this.get_type(), "Clutter", "Actor", "StWidget", new string[0]);
			string[] names = {};
			var vfunc_ids = new GLib.VariantBuilder(new GLib.VariantType("ai"));
			foreach (var name in overridden) {
				if (name != "get_preferred_width" && name != "get_preferred_height") {
					continue;
				}
				var vfunc_id = -1;
				var hook_id = this.bind_vfunc(name, out vfunc_id);
				if (hook_id == 0) {
					continue;
				}
				names += name;
				vfunc_ids.add("i", vfunc_id);
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-St-DrawingArea.create", null,
				OLLMrpc.args("s", this.get_type().name()));
			this.rpc_lid = response.args.get(0).get_uint64();
			Gsr.Client.Rpc.register_handle(this);
			if (names.length == 0) {
				Gsr.Client.Rpc.hook_rows = null;
				return;
			}
			var hooks = Gsr.Client.Rpc.call_value(
				"Gsr-St-DrawingArea.add_hooks", this,
				OLLMrpc.args("Sv", names, vfunc_ids.end()));
			var ids = hooks.args.get(0).get_variant();
			if (Gsr.Client.Rpc.handlers == null) {
				Gsr.Client.Rpc.handlers = new Gee.HashMap<int, Gsr.Client.Rpc.InvokeRow>();
			}
			var n = (int) ids.n_children();
			for (var i = 0; i < n; i++) {
				Gsr.Client.Rpc.handlers.set(
					(int) ids.get_child_value(i).get_uint64(),
					Gsr.Client.Rpc.hook_rows.get(i));
			}
			Gsr.Client.Rpc.hook_rows = null;
		}

```

## LLM efforts

### 2026-10-22 10:15 split from the picker bug

The `St-Bin` arm is the case that made the grid icons square enough to see. It stays until this design replaces the switch. No code moved in this split.

### 2026-10-22 18:59 name

The virtual is `rpc_construct`. No code moved.

### 2026-10-22 19:03 proposal

Proposed changes are in this file. Not applied. The first draft left the switch inside `Actor.rpc_construct`. That is wrong. Each special class overrides `rpc_construct`. A parent calls `base.rpc_construct()` when a derived type is already registered, so `St.Button` does not take `St.Widget`'s lease.

### 2026-10-22 19:53 helpers

`create_viewport` moves to `St.Viewport`. `open_drawing_area_lease` and `create_drawing_area` move to `St.DrawingArea`. `create_with_overrides` stays on `Actor`: the default walk still calls it for an unregistered `Clutter.Actor` subclass, and `St.Widget` and `Meta.WindowActor` call it too.

### 2026-10-23 08:03 queue_relayout connect

The slot compare leaves the lease `construct`. A second `construct` next to `queue_relayout()` connects only when `VfuncRelay.overridden` contains `queue_relayout`. Not applied.

### 2026-10-23 08:30 applied

Applied. `mutter-clutter-rpc-16`, `mutter-rpc-16`, `st-rpc-16`, `gsr-st-boxed`, and `shell-16` compiled.

Vala rejected a second `construct` on `Actor`. The `queue_relayout` connect is the first part of the lease `construct`, before the `rpc_lid` guard.

`bind_vfunc` is `protected`. `St.Viewport` and `St.DrawingArea` call it from another shared library. `internal` is invisible there. `prop_batch_open` stays `internal`. `Actor.construct` sets it after `rpc_construct` returns.

`gsr-st-boxed` compiles `st-rpc-16.vapi`. `libmutter-16.deps` loads system `mutter-clutter-16`, so `Clutter.Actor` there has no `rpc_construct`. That target uses `mutter-clutter-rpc-16` and `gsr-rpc-16`.

### 2026-10-23 08:26 constructor dispatch

Wayland session `08:21:24` in `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`. `Gjs_ui_barLevel_BarLevel` (`St.DrawingArea` subclass) and `Gjs_ui_slider_Slider` log `no rpc_lid`. `Gsr-St-DrawingArea.create` never appears. `St-DrawingArea.new` does, for exact drawing areas. `Gsr-St-SquareBin.new` appears, so a Vala override does run.

Generated `clutter_actor_rpc_construct` uses `CLUTTER_ACTOR_GET_CLASS(self)->rpc_construct`. `base.rpc_construct()` in `St.Widget` is `st_widget_parent_class->rpc_construct`, the parent function pointer. That call does not re-enter `Widget.rpc_construct`. A null slot returns without a lease. That matches the GJS actors.

`style_class` is an ordinary property, applied after the constructor returns. The only types that stay at `rpc_lid` 0 are `Gjs_ui_barLevel_BarLevel`, `Gjs_ui_slider_Slider` (extends that bar), and `Gjs_ui_messageList_MessageView` (extends `St.Viewport`). Before this change, `DrawingArea.construct` called `open_drawing_area_lease` whenever `rpc_lid` was still 0. That constructor runs for a JavaScript subclass. The lease now lives only in `rpc_construct`, and that call does not run for these subclasses. The constructor that remains returns immediately when `rpc_lid` is 0.

### 2026-10-23 08:42 constructor fallback

`rpc_construct` stays. `DrawingArea.construct` calls `open_drawing_area_lease` when `rpc_lid` is still 0. `Viewport.construct` calls `create_viewport(true)` in that same case. `signal_overrides` is `protected`. `prop_batch_open` is `public` so those libraries can set it. `mutter-clutter-rpc-16` and `st-rpc-16` compiled.

### 2026-10-23 09:06 session after the fallback

Wayland log `09:05:11`–`09:06:32`. `Gsr-St-DrawingArea.create` is at `09:05:11.842915`, just after `get_theme_node` failed on `BarLevel`. The lease is late. `createIcon in BaseIcon` is 168 times, from `iconGrid.js` `vfunc_style_changed` during `BaseIcon._init`, before `createIcon` is assigned. `layout_manager is null` is 4 times, from `IconGrid._init`. At `09:05:20` the overview update throws `ClutterActorBox` undefined in `overviewControls.js` `vfunc_allocate`, then `clutter_margin_copy` is missing from `libmutter-clutter-rpc-16.so` in `AppGrid._updatePadding`. `Meta-StartupNotification.create_launcher` appears once, at `09:05:13`, during startup.

### 2026-10-23 09:37 speculative fix pulled

A parent-type lease table, a held `style-changed`, and `clutter_margin_copy` were written into `src/` and compiled. They were removed the same morning. `src/` is back to the constructor fallback.

### 2026-10-23 09:50 large draft rejected

That draft is not the proposal.

### 2026-10-23 09:55 function-pointer cast rejected

`RpcConstructSlot` is out. The child proposal was signal `lease`.

### 2026-10-23 10:07 `rpc_lease` has no body

The signal is `rpc_lease`. Nothing runs inside the declaration. `Actor.construct` emits it. The classes that already override `rpc_construct` connect a class handler.

### 2026-10-23 10:14 signal taken back out

That signal was written into `src/` and removed. It is a GIR symbol unless the generator emits `[CCode (gir = false)]`. Left in the child proposal.
