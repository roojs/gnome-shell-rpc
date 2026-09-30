# Boot still sends about 30k RPC calls

**Status:** ⏳ open. `Helper-Actor.add_signals` is in. The 17:41 prove was killed at 8 seconds, before a tally. The 16:40 stay-up is still the scoreboard: 27,703 calls. The four-call attempt is [`done/2026-09-29-rpc-call-volume.md`](done/2026-09-29-rpc-call-volume.md).

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Seen:** 2026-09-30 13:05:02–13:07:10 and 14:31:17–14:31:47. `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`.

| Session | Calls | Span |
| ------- | ----: | ---- |
| 13:05 | 34,100 | 30,021 of them in the first 40 seconds |
| 14:31 | 28,954 | 30 seconds |

Same boot as 2026-09-29: `St-Button.new` 475 there, 503 in the older log.

## What each call saved

Four calls were added around construct: create, signals, hooks, properties. Boot was about 32,000 calls in 29 seconds on 2026-09-29. After all four, plus the later stay-open edit, a 30 second run was 27,703. About 4,000 of 32,000.

| Call | 2026-09-29 | 13:05 | 16:40 |
| ---- | ---------: | ----: | ----: |
| boot calls | ~32,000 | 30,021 | 27,703 |
| `rpc_signal` | 5,286 | 5,146 | 5,122 |
| `add_hooks` | — | 45 | 40 |
| `add_properties` | — | 1,168 | 1,716 |
| `set_style_class_name` | 1,740 | 1,651 | 1,652 |
| `set_x_expand` | 1,139 | 469 | 44 |
| `set_y_expand` | 1,006 | 374 | 34 |
| `set_x_align` | 923 | | 248 |
| `set_y_align` | 821 | | 258 |
| `set_can_focus` | 639 | | 276 |
| `set_reactive` | 564 | | 347 |
| `set_text` | 462 | 70 | 21 |
| `hide` | 667 | 607 | 429 |
| `set_pivot_point` | 301 | 303 | 297 |
| `set_label_actor` | 361 | | 328 |
| `St-Button.new` | 503 | 475 | 478 |
| `Helper-Actor.create` | 711 | 712 | 699 |

**Create.** Still one call per actor. `St-Button.new` 503 → 478, `Helper-Actor.create` 711 → 699.

**Signals.** Still one `"s"` per name, 5,286 → 5,122. `74c9562` sent that list as `OLLMrpc.args("S", signal_names)` to `RPC-Live-Subscribe.rpc_signal`. That method is registered `"s"` and takes `string name`, so the array arrived as a null `name` and the method returned no reply. The client was changed back to one `"s"` per name. `rpc_signal` stays `"s"`. The list is `Helper-Actor.add_signals`. Proposal at the bottom.

**Hooks.** `add_hooks` is 40 calls, against 699 `Helper-Actor.create`. Before this, the hook ids already rode on `Helper-Actor.create`, and each vfunc also sent `RPC-Live-Callback.register`. The new path skips that register and sends `add_hooks` only when the list is non-empty. The saving is one register per extra vfunc on those ~40 actors. A separate wire method for that is a small cut.

**Properties.** This is the cut that shows in the boot total. The rows above that have both ends drop by 4,689 calls. `add_properties` costs 1,716. Net about 3,000. The 13:05 map, which closed on a missed name, took the boot from ~32,000 to 30,021. The stay-open edit took a 30 second run from 28,954 to 27,703.

`set_style_class_name` stayed 1,652. `set_pivot_point` stayed 297. `hide` fell by 238. `set_x_expand` and `set_y_expand` are the rows that actually moved.

The move to the generator is [`2026-09-30-generator-property-batch.md`](2026-09-30-generator-property-batch.md).

## Generator classifies the call

`call_value` in `src/namespace.vala` is the wire send. It also guesses which calls to cache: `instance as Clutter.Actor`, then `hide` / `show` / a one-argument `set_*` whose tail matches a writable property. That guess is the wrong place. `set_style_class_name` becomes `style-class-name`. The property is `style-class`.

The generator emits every setter and already has `pname` (`src/gi-stub-gen/Generator.vala`). It decides the path. A batchable setter is a different function from `call_value`, and that function takes `pname` and the value. `call_value` stops classifying tails. The next `call_value` on that actor still flushes `Helper-Actor.add_properties`.

**Class whitelist.** One class: `Clutter.Actor`. `prop_batch` and `prop_batch_open` exist only there, and `prop_batch_open` is set only from `Actor.construct`. `St.Widget`, `St.Button`, and the other actor subclasses are in because they are actors, not because they are listed. `Meta.Display`, `St.Settings`, `St.Adjustment`, layout managers, and constraints are not.

**Name blacklist.** A method that is special because of its name stays on `call_value`. The generator does not emit it on the batch path.

| Method | Why |
| ------ | --- |
| `set_child` | Parents the child. Already excluded. Closes the batch. |
| `set_layout_manager` | `Actor` override builds the server manager. |

**Property type.** The generator already has the property type, the argument count, and the flags. It picks the path from those. No method name for these.

| Seen as | What the generator has |
| ------- | ---------------------- |
| `set_gicon` | The value is a string. The property is a `GIcon`. Batching it cleared the search icons. |
| `set_pivot_point` | Two arguments. 297 calls on 16:40, same as before. |
| `mapped` | Not writable. |

`add_child`, getters, `allocate`, and `rpc_signal` are not property sets, so they stay on `call_value` and they flush.

Folding `style-class` through the batch function is up to 1,652 calls, the ones still sent beside an `add_properties` that already flushes.

## What closes the batch

`prop_batch_open` is already true when GObject applies the constructor properties. `call_value` in `src/namespace.vala` names the property from the method tail: strip `set_`, turn `_` into `-`.

`St-Widget.set_style_class_name` becomes `style-class-name`. The property is `style-class`. `find_property` returns null. A miss sets `prop_batch_open = false`. The map is empty, so there is no `add_properties`. Every later setter on that actor is its own call.

On 14:31, 3,810 constructors. The next logged call is `set_style_class_name` 801 times and `add_properties` 775 times. `set_text` derives `text`, so it was queued: 462 calls on 2026-09-29, 70 on 13:05. `set_style_class_name` stayed 1,651. `hide` stayed 607.

`add_properties` also stored `mapped`. That property is not writable. Twelve criticals: `StEntry` 3, `StWidget` 3, `WorkspacesDisplay` 3, and one each for `DateMenuButton`, `QuickSettings`, and `InputSourceIndicator`.

`rpc_signal` is still one `"s"` per name (5,146 on 13:05). That is not this fix.

## After the edit

**Seen:** 2026-09-30 16:40:20–16:40:49. `GSR_NESTED_STAYUP=1` prove, nest timeout 30s. 27,703 `Client.vala:1018` calls. The 14:31 run, also about 30s and before this edit, was 28,954.

| Call | 13:05 | 16:40 |
| ---- | ----: | ----: |
| total | 34,100 | 27,703 |
| `set_style_class_name` | 1,651 | 1,652 |
| `rpc_signal` | 5,146 | 5,122 |
| `add_properties` | 1,168 | 1,716 |
| `set_x_expand` | 469 | 44 |
| `set_y_expand` | 374 | 34 |
| `set_text` | 70 | 21 |
| `hide` | 607 | 429 |
| `add_child` | 2,201 | 2,178 |
| `St-Button.new` | 475 | 478 |

The setters that used to follow a miss joined the map. `set_x_expand` and `set_y_expand` fell. `set_style_class_name` did not. `rpc_signal` did not. The 30s total fell by about 1,200.

`mapped` is still six criticals, one each for `DateMenuButton`, `QuickSettings`, `InputSourceIndicator`, `StEntry`, `StWidget`, and `WorkspacesDisplay`. Each one is a `notify::mapped` followed by `Clutter-Actor.is_mapped`, not `add_properties`.

## Not the flood

The edit is in `src/namespace.vala` `call_value`. A one-argument `set_*` that does not match a property is sent as itself and the batch stays open. The setters after `set_style_class_name` joined the map: `set_x_expand` 469 → 44, `set_y_expand` 374 → 34.

`set_style_class_name` stayed 1,652. `rpc_signal` stayed 5,122. Constructors, getters, and `add_child` stayed. That is the flood.

The writable check did not stop the `mapped` criticals. Those six are `notify::mapped`, then `is_mapped`.

`set_child`, a setter with two arguments, a getter, `add_child`, and `allocate` still close the batch.

The generator already has the property name (`pname`) when it emits the `style-class` setter. Folding that call into the map belongs there. [`2026-09-30-generator-property-batch.md`](2026-09-30-generator-property-batch.md).

## Signals — one list, `rpc_signal` stays `"s"`

`rpc_signal` is the largest row on 16:40 (5,122). A 17:29 prove (15,983 calls, about 22 seconds) sent 1,495 of them in 849 runs. 469 runs are already one name. The other 380 runs are the extras: 646 calls. Same shape as 16:40, which kept going through the grid.

`Request.add_class` defines `"S"` as one `string[]`: a pointer plus the Vala length. `Helper-Actor.add_hooks` is already registered that way. `RPC-Live-Subscribe.rpc_signal` is registered `"s"` and takes one `string name`. `74c9562` sent the array to that method. The array is one wire value, the size check passes, and `name` is null. The method returns no reply.

`OLLMrpc.Live.Subscription.connect` connects one name and writes no reply. A handler that replies itself calls it once per name, then replies once. That handler is `Helper-Actor.add_signals`. `rpc_signal` stays the later one-name call.

A later `.connect` of a name already in the list bumps the local ref and sends nothing. A name that was not in the construct list still sends one `rpc_signal` with `"s"`.

**Order.** `create_with_overrides` sets `prop_batch_open` and returns. `construct` then runs `signal_overrides`. Each `rpc_signal` is a `call_value`, and `call_value` closes the batch. The map is empty, so there is no `add_properties`. `St.Widget` subclasses then send `set_style_class_name` on its own (1,652). The stock `.new` arm sets `prop_batch_open` after `signal_overrides`. The widget arm does the same: create, hooks, one `add_signals`, then `prop_batch_open`.

## Proposed code

### `add_signals`

**Where:** `src/rpc/helper/ClutterActor.vala` `rpc_register`, the `add_class` list.

**Add** after `"add_hooks", "Sv",`:

```vala
				"add_signals", "S",
```

**Add** the method next to `add_hooks`:

```vala
		/**
		 * ''Helper-Actor.add_signals'' — subscribe each name on the lease.
		 *
		 * ''Subscription.connect'' writes no reply. This method
		 * replies once after the list. An empty name or a missing
		 * lease is ''-32602'' and no success reply.
		 *
		 * @param request inbound RPC
		 * @param names signal or ''notify::'' property
		 */
		public void add_signals(OLLMrpc.Request request, string[] names)
		{
			for (var i = 0; i < names.length; i++) {
				var subscription = new OLLMrpc.Live.Subscription() {
					connection = request.connection,
					method = names[i],
					id = (int) request.lease_id
				};
				if (!subscription.connect()) {
					request.connection.reply_error(request,
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
					return;
				}
			}
			request.reply(new OLLMrpc.Response());
		}
```

The lease can be an `St.Button`. `Helper-Actor` is registered live, so dispatch stays on the singleton and the lease id is `request.lease_id`. Same as `add_properties`.

### `Signals.connect`

**Where:** `src/shell-gi/Signals.vala`.

**Replace:**

```vala
			GnomeShellRpc.GiStub.Runtime.client.proxies.set(lid, obj);
			foreach (var name in signal_names) {
				GnomeShellRpc.call_value("RPC-Live-Subscribe.rpc_signal", obj,
					OLLMrpc.args("s", name));
			}
```

**Replace with:**

```vala
			GnomeShellRpc.GiStub.Runtime.client.proxies.set(lid, obj);
			if (signal_names.length > 1) {
				GnomeShellRpc.call_value("Helper-Actor.add_signals", obj,
					OLLMrpc.args("S", signal_names));
			} else {
				GnomeShellRpc.call_value("RPC-Live-Subscribe.rpc_signal", obj,
					OLLMrpc.args("s", signal_names[0]));
			}
```

One name stays `"s"`. The construct list is `"S"`. The local `subs` loop under that call is unchanged.

### Collect, then one subscribe

**Where:** `src/gi-stub/overrides-clutter/Actor.override.vala`.

`create_with_overrides` stops setting `prop_batch_open`. `construct` sets it after `signal_overrides`.

**Replace** both `this.prop_batch_open = true;` lines inside `create_with_overrides` with nothing.

**Replace** the `St-Widget` arm:

```vala
				case "St-Widget":
					this.create_with_overrides();
					this.signal_overrides(this.get_type());
					return;
```

**Replace with:**

```vala
				case "St-Widget":
					this.create_with_overrides();
					this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
					this.prop_batch_open = true;
					return;
```

**Replace** the `Clutter-Actor` subclass arm the same way: pass the list, then `this.prop_batch_open = true`.

**Replace** the stock arm call:

```vala
			this.signal_overrides(this.get_type());
			this.prop_batch_open = true;
```

**Replace with:**

```vala
			this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
			this.prop_batch_open = true;
```

**Replace** `signal_overrides` with the walk that gathers names and subscribes once on the leaf. `74c9562` had this walk. The leaf copies the list into `Runtime.pending_signals` and calls `ensure_signal_subscribe` with the first name. `Signals.connect` sees a list longer than one and sends `add_signals`. An empty list sends nothing.

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
			var pending_signals = names.to_array();
			GnomeShellRpc.GiStub.Runtime.pending_signals = pending_signals;
			GnomeShellRpc.GiStub.Runtime.pending_signals_size = pending_signals.length;
			GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(
				this, pending_signals[0]);
			return;
		}
		if (OLLMrpc.Bin.gtype_to_alias == null) {
			return;
		}
		if (!OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
			return;
		}
		var alias = OLLMrpc.Bin.gtype_to_alias.get(t);
		var dot = alias.index_of("-");
		if (dot < 0) {
			return;
		}
		var ns = alias.substring(0, dot);
		var class_name = alias.substring(dot + 1);
		var leaf = this.get_type();
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
			names.add(signal_name);
		}
	}
```