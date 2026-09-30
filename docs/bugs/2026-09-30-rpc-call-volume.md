# Boot still sends about 30k RPC calls

**Status:** ⏳ open. The four-call construction ran and the flood stayed about 30,000 calls. That attempt is [`done/2026-09-29-rpc-call-volume.md`](done/2026-09-29-rpc-call-volume.md). The `call_value` edit below stops the `mapped` critical. It does not cut this flood.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Seen:** 2026-09-30 13:05:02–13:07:10 and 14:31:17–14:31:47. `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`.

| Session | Calls | Span |
| ------- | ----: | ---- |
| 13:05 | 34,100 | 30,021 of them in the first 40 seconds |
| 14:31 | 28,954 | 30 seconds |

Same boot as 2026-09-29: `St-Button.new` 475 there, 503 in the older log.

## What closes the batch

`prop_batch_open` is already true when GObject applies the constructor properties. `call_value` in `src/namespace.vala` names the property from the method tail: strip `set_`, turn `_` into `-`.

`St-Widget.set_style_class_name` becomes `style-class-name`. The property is `style-class`. `find_property` returns null. A miss sets `prop_batch_open = false`. The map is empty, so there is no `add_properties`. Every later setter on that actor is its own call.

On 14:31, 3,810 constructors. The next logged call is `set_style_class_name` 801 times and `add_properties` 775 times. `set_text` derives `text`, so it was queued: 462 calls on 2026-09-29, 70 on 13:05. `set_style_class_name` stayed 1,651. `hide` stayed 607.

`add_properties` also stored `mapped`. That property is not writable. Twelve criticals: `StEntry` 3, `StWidget` 3, `WorkspacesDisplay` 3, and one each for `DateMenuButton`, `QuickSettings`, and `InputSourceIndicator`.

`rpc_signal` is still one `"s"` per name (5,146 on 13:05). That is not this fix.

## Not the flood

One edit in `src/namespace.vala` `call_value`. No method names in that function. A property that is not writable is not stored, so `add_properties` stops writing `mapped`. A one-argument `set_*` that does not match a property is sent as itself and the batch stays open, so the setters after `set_style_class_name` can join the map.

`St-Widget.set_style_class_name` stays its own call. On 13:05 that is 1,651 calls, and on 14:31 it is the next call after 801 constructors. `rpc_signal` stays 5,146. Constructors, getters, and `add_child` stay. That is the flood.

`set_child`, a setter with two arguments, a getter, `add_child`, and `allocate` still close the batch, send `add_properties` when the map has entries, and then run.

The generator already has the property name (`pname`) when it emits the `style-class` setter. Folding that call into the map belongs there, not in `call_value`.

**Replace:**

```vala
		if (name != "") {
			var pspec = actor.get_class().find_property(name);
			var held = args.get(0);
			if (pspec == null || held == null
					|| (!held.type().is_a(pspec.value_type)
						&& !GLib.Value.type_transformable(held.type(), pspec.value_type))) {
				name = "";
			}
		}
		if (name != "") {
			actor.prop_batch.set(name, args.get(0));
			return new OLLMrpc.Response();
		}
		if (actor != null && actor.prop_batch_open) {
			actor.prop_batch_open = false;
```

**Replace with:**

```vala
		var refused = name != "";
		if (name != "") {
			var pspec = actor.get_class().find_property(name);
			var held = args.get(0);
			if (pspec == null || held == null
					|| (pspec.flags & GLib.ParamFlags.WRITABLE) == 0
					|| (!held.type().is_a(pspec.value_type)
						&& !GLib.Value.type_transformable(held.type(), pspec.value_type))) {
				name = "";
			}
		}
		if (name != "") {
			actor.prop_batch.set(name, args.get(0));
			return new OLLMrpc.Response();
		}
		if (actor != null && actor.prop_batch_open && !refused) {
			actor.prop_batch_open = false;
```
