# GJS subclass misses rpc_construct

**Status:** ⏳ proposal only. Written into `src/` and taken back out. Not applied.

**Next:** Think about the GIR. A `rpc_lease` signal on `Clutter.Actor` is a new symbol. Hiding it is `[CCode (gir = false)]`. That belongs in the generator if we do this. No test program.

Parent: [`2026-10-22-actor-construct-lease-switch.md`](2026-10-22-actor-construct-lease-switch.md).

`Actor.construct` calls `this.rpc_construct()`. A JavaScript subclass leaves that slot empty, so the parent override does not run.

`this.rpc_lease.connect` inside `DrawingArea.construct` is too late. Actor's constructor has already returned. The handler is connected when the class is created, with `Signal.override_class_handler`. Emit stays in `Actor.construct`.

Wayland log `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`, session `09:05:11`. `BarLevel` still had `rpc_lid` 0 when `get_theme_node` ran.

## Proposal

### 1. `Actor.override.vala` — signal `rpc_lease`

**Why:** the class handler runs for a JavaScript subclass. The empty slot does not.

**Where:** replace `this.rpc_construct()` in `construct`. Declare the signal with no body. Connect the current walk for `typeof(Actor)`.

#### Remove

```vala
		this.rpc_construct();
```

#### Replace with

```vala
		this.rpc_lease();
```

#### Add

Next to `rpc_construct`. The `while` that is `rpc_construct` today moves into `lease_ancestor`. `rpc_construct` calls `lease_ancestor` so `base.rpc_construct()` stays the walk.

```vala
	public signal void rpc_lease();

	static construct {
		GLib.Signal.override_class_handler(
			"rpc-lease",
			typeof(Actor),
			(GLib.Callback) on_rpc_lease);
	}

	static void on_rpc_lease(Actor self) {
		self.lease_ancestor();
	}

	protected virtual void rpc_construct() {
		this.lease_ancestor();
	}

	void lease_ancestor()
	{
```

### 2. Classes that already override `rpc_construct`

**Why:** `BarLevel` must run `DrawingArea`'s lease. That class handler replaces Actor's for that type and its subclasses.

**Where:** `static construct` on `DrawingArea`, `Viewport`, `SquareBin`, `Widget`, `Clone`, `BackgroundActor`, `WindowActor`.

`on_rpc_lease` runs the lease that class's `rpc_construct` already runs. It does not call `rpc_construct()`.

#### Add

`DrawingArea.override.vala`:

```vala
		static construct {
			GLib.Signal.override_class_handler(
				"rpc-lease",
				typeof(DrawingArea),
				(GLib.Callback) on_rpc_lease);
		}

		static void on_rpc_lease(DrawingArea self) {
			var subclass = self.get_type() != typeof(DrawingArea);
			self.open_drawing_area_lease(subclass);
		}
```

`Viewport.override.vala`:

```vala
		static construct {
			GLib.Signal.override_class_handler(
				"rpc-lease",
				typeof(Viewport),
				(GLib.Callback) on_rpc_lease);
		}

		static void on_rpc_lease(Viewport self) {
			self.create_viewport(false);
		}
```

`SquareBin.vala`, `Widget.override.vala`, `Clone.override.vala`, `BackgroundActor.override.vala`, and `WindowActor.override.vala` connect the same way. `on_rpc_lease` is the body now in that class's `rpc_construct`, and `rpc_construct` calls it too.

## LLM efforts

### 2026-10-23 10:07 signal has no body

`lease` with a body is not the proposal. The signal is `rpc_lease`. Handlers are connected with `Signal.override_class_handler`. Not applied.

### 2026-10-23 10:14 signal taken back out

`rpc_lease` was added on `Actor` and the classes that override `rpc_construct`. It came back out the same morning. The signal would show up in the GIR. The hide tag in this tree is `[CCode (gir = false)]`. Putting that on a generated class is generator work, and that is too much for this tweak. `src/` is the constructor fallback again. The proposal above is unchanged.
