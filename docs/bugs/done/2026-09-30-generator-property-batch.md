# Generator picks the property batch

**Status:** ✔️ archived 2026-09-30. The 18:48 binary ran this path. `set_style_class_name` in that log is 339 (was 1,652). The tally is [`2026-09-30-rpc-call-volume.md`](2026-09-30-rpc-call-volume.md). The notes below are the move onto the generator.

## Boot abort

Not a segfault. `SIGTRAP` / `int3` in `libglib` is `g_log` at error level. `ClutterBoxLayout` calls `g_error` when a mapped child's minimum height is negative. Same abort as [`ClutterBoxLayout` minimum height `-12`](2026-09-25-box-layout-negative-min-height.md).

```text
ClutterBoxLayout child unnamed [GnomeShellRpcRpcHelperActor] minimum height: -12.000000 < 0 for width 182.000000
```

17:57 stay-up: `notify_ready` at 17:57:33.584, abort at 17:57:34.088, during `BoxPointer` allocate. `Helper-Actor.add_signals` had already been replied to.

`Clutter-Actor.hide` was the failure. The batch was closed, so `batch_call_value` relayed `OLLMrpc.args("b", false)` into `Clutter-Actor.hide`. That method takes no arguments. Mutter returned `-32602`. The client logged an uncaught error at `Clutter_generated.vala:2448` and left the actor mapped. The first frame after the gate opened then hit the empty grid.

`show` and `hide` store `visible` while `prop_batch_open`, then call `call_value` with no arguments. That flush sends the map, then the real `show` / `hide`.

**Plan:** [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)

**Counts:** [`2026-09-30-rpc-call-volume.md`](2026-09-30-rpc-call-volume.md). `set_style_class_name` is still 1,652. The guess in `call_value` turns that method into `style-class-name`. The property is `style-class`.

`call_value` sends the wire call. It also decides which calls to cache. That decision moves to `src/gi-stub-gen/Generator.vala`, which already has `pname`, the property type, the argument count, and the flags. The generator emits `batch_call_value` with that `pname`. `batch_call_value` stores while `prop_batch_open` is set. When it is not, `batch_call_value` calls `call_value` with the same method and arguments. No method on `Clutter.Actor` for this.

## Who is cached

**Class.** `Clutter.Actor` only, including subclasses. The setter flood is those objects. On 2026-09-29 the counted setters are `set_style_class_name` 1,740, `set_x_expand` 1,139, `set_y_expand` 1,006, `set_x_align` 923, `set_y_align` 821, `set_can_focus` 639, `set_reactive` 564, `set_text` 462, `set_orientation` 397, `set_label_actor` 361, and `hide` 667. `St.Button`, `St.Widget`, `St.Label`, and `St.BoxLayout` are in because they are actors.

A 15 second chrome log on 2026-09-30 17:31 (15,189 calls, grid not built) is the same shape. `St-Widget.set_style_class_name` is 883. The next non-actor setters are `Clutter-ActorMeta.set_enabled` 120, `St-Adjustment.set_value` 105, and `Clutter-BindConstraint` about 60 each for `set_source`, `set_coordinate`, and `set_offset`. Hundreds, not the actor pile. No batch map on adjustments, constraints, or `Meta.Display`.

**Whitelist.** `src/gi-stub-gen/batch.whitelist`, loaded once into a set. When the generator emits a setter it looks up `Namespace.Class.method`. A hit emits `batch_call_value`. A miss emits `call_value`, which flushes. The namespace is in the key because `Clutter.BoxLayout` is not an actor and `St.BoxLayout` is. `set_child` and `set_layout_manager` are absent from the file. So are `set_pivot_point` and `set_gicon`: the type check already keeps them on `call_value`.

**Type and flags.** No names. The generator already computed these before it emits the setter.

- Not `WRITABLE` (`mapped`). No setter is emitted, so it never enters the map.
- `write_method` only when `property_setter_matches`: one IN argument, and the argument letter matches the property letter.
- `write_gprop` uses `pname` and the property type. It still has to be in the whitelist.

`hide` and `show` are not generated setters. `Actor.override.vala` owns them. While `prop_batch_open` they store `visible`, then `call_value` flushes the map and sends `hide` / `show` with no arguments. Passing the boolean into that method is `-32602`. `visible` is not a line in the whitelist.

## Proposed code

### `batch_call_value`

**Where:** `src/namespace.vala`, next to `call_value`.

While `prop_batch_open` is set, store `name` and the one argument and return. Otherwise call `call_value` with the same method and arguments. The wire method stays `set_style_class_name`. The stored name is `style-class`.

**Add:**

```vala
	public OLLMrpc.Response batch_call_value(
		string method,
		Clutter.Actor actor,
		string name,
		Gee.ArrayList<GLib.Value?>? args = null,
		OLLMrpc.Live.Buffer? buffer = null
	) throws GLib.Error {
		if (actor.prop_batch_open && args != null && args.size == 1) {
			actor.prop_batch.set(name, args.get(0));
			return new OLLMrpc.Response();
		}
		return call_value(method, actor, args, buffer);
	}
```

### `show` / `hide`

**Where:** `src/gi-stub/overrides-clutter/Actor.override.vala`.

**Replace:**

```vala
	public void show()
	{
		this.actor_visible = true;
		GnomeShellRpc.call_value("Clutter-Actor.show", this);
	}

	public void hide()
	{
		this.actor_visible = false;
		GnomeShellRpc.call_value("Clutter-Actor.hide", this);
	}
```

**Replace with:**

```vala
	public void show()
	{
		this.actor_visible = true;
		if (this.prop_batch_open) {
			GnomeShellRpc.batch_call_value("Clutter-Actor.show", this, "visible",
				OLLMrpc.args("b", true));
		}
		GnomeShellRpc.call_value("Clutter-Actor.show", this);
	}

	public void hide()
	{
		this.actor_visible = false;
		if (this.prop_batch_open) {
			GnomeShellRpc.batch_call_value("Clutter-Actor.hide", this, "visible",
				OLLMrpc.args("b", false));
		}
		GnomeShellRpc.call_value("Clutter-Actor.hide", this);
	}
```

### `call_value` only flushes

**Where:** `src/namespace.vala`.

**Replace:** the `hide` / `show` store, the `set_*` tail guess, `refused`, and `&& !refused` on the flush.

**Replace with:**

```vala
		var actor = instance as Clutter.Actor;
		if (actor != null && actor.prop_batch_open && actor.prop_batch.size == 0) {
			actor.prop_batch_open = false;
		}
		if (actor != null && actor.prop_batch.size > 0) {
			actor.prop_batch_open = false;
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
```

An open map with nothing in it is closed and nothing is sent. The flush looks at `prop_batch.size` only. A store only happens while `prop_batch_open` is set, so a non-empty map was open. `batch_call_value` does not enter `call_value` while the batch is open, so a cached setter does not flush itself. The next `call_value` (`add_child`, `set_child`, a getter, `allocate`) flushes, then runs. A later setter hits `batch_call_value` with the batch closed and that call is `call_value`.

### Generator

**Where:** `src/gi-stub-gen/Application.vala` loads the file the same way as `load_deny`. `src/gi-stub-gen/Generator.vala` holds the set and looks it up at the setter.

**Add** the field:

```vala
		/**
		 * {@code Namespace.Class.method} lines from {@code batch.whitelist}.
		 * A hit emits {@code batch_call_value}. A miss emits
		 * {@code call_value}.
		 */
		public Gee.HashSet<string> batch = new Gee.HashSet<string>();
```

**Add** the loader, next to `load_deny`. It fills a set. The `Generator` object takes that set, the same way it takes `deny`.

```vala
		private void load_batch(out Gee.HashSet<string> batch)
		{
			batch = new Gee.HashSet<string>();
			if (Application.opt_batch_file == "") {
				return;
			}
			string contents;
			size_t len;
			try {
				GLib.FileUtils.get_contents(
					Application.opt_batch_file, out contents, out len);
			} catch (GLib.Error e) {
				GLib.error(
					"cannot read batch file %s: %s",
					Application.opt_batch_file, e.message);
			}
			foreach (var line in contents.split("\n")) {
				var name = line.strip();
				if (name == "" || name.has_prefix("#")) {
					continue;
				}
				var hash = name.index_of("#");
				if (hash >= 0) {
					name = name.substring(0, hash).strip();
				}
				if (name != "") {
					batch.add(name);
				}
			}
		}
```

```vala
			Gee.HashSet<string> batch;
			this.load_batch(out batch);
			var gen = new Generator() {
				deny = deny,
				batch = batch,
				/* … */
			};
```

The lookup is `ns + "." + class_name + "." + setter.get_name()`. On `write_method`, after `property_setter_matches`:

```vala
		var batch_key = ns + "." + class_name + "." + setter.get_name();
		if (batch_key in this.batch) {
			/* emit batch_call_value with pname */
		} else {
			/* emit call_value, as now */
		}
```

On `write_gprop`, the same lookup with `ns + "." + class_name + "." + conv_set`. A miss stays `set_property` through `call_value`.

**Add** `src/gi-stub-gen/batch.whitelist`. One setter per line. Comments with `#`.

```text
# Namespace.Class.method. batch_call_value stores these.
# A setter not listed here is call_value and flushes.
# Clutter.BoxLayout is not an actor. St.BoxLayout is.

Clutter.Actor.set_x_expand
Clutter.Actor.set_y_expand
Clutter.Actor.set_x_align
Clutter.Actor.set_y_align
Clutter.Actor.set_reactive
Clutter.Actor.set_opacity
St.Widget.set_style_class_name
St.Widget.set_can_focus
St.Widget.set_track_hover
St.Widget.set_label_actor
St.Label.set_text
St.BoxLayout.set_orientation
```

`set_track_hover` is on the icon trace between `set_can_focus` and `set_style_class_name`. Left off the list, it would flush the batch before `style-class` is stored. The property is emitted on the class that defines it, so `St.Widget.set_style_class_name` is the key while `St.Widget` is generated. `St.Button` does not emit that setter again.

`St.Widget.style-class` is `write_method` (`set_style_class_name`) and `pname` is `style-class`. The lookup hits, so the emitted setter is:

```vala
			set {
				GnomeShellRpc.batch_call_value(
					"St-Widget.set_style_class_name", this, "style-class",
					OLLMrpc.args("s", value));
			}
```
