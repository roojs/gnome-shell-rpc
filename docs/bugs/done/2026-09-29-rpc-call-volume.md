# Boot sends 32k RPC calls before any input

**Status:** ✔️ archived 2026-09-30. The four-call construction ran. The boot flood stayed the same size. Continued as [`2026-09-30-rpc-call-volume.md`](2026-09-30-rpc-call-volume.md). The notes below are that attempt.

The four-call client is on `74c9562`. `prop_batch_open` turns on at the end of `construct`. An empty hook list sends no `Helper-Actor.add_hooks`. An empty property map sends no `Helper-Actor.add_properties`. The empty stage after that commit was `Shell.Signals.connect` sending `OLLMrpc.args("S", signal_names)`. `Request.add_class` defines `"S"` as one `string[]`. `rpc_signal` was still registered `"s"` and takes `string name`, so `name` was null and the method returned no reply. The client was then changed back to one `"s"` per name. The 13:05 binary includes the one-string client. `rpc_signal` stays `"s"`. The list is `Helper-Actor.add_signals`. Proposal: [`2026-09-30-rpc-call-volume.md`](2026-09-30-rpc-call-volume.md).

## After the construction change

**Seen:** 2026-09-30 13:05:02–13:07:10. `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`. Binary built 13:02. Weston was killed at 13:07:10 (`X connection to :1 broken`). The socket closed with `pending=0`.

34,100 `Client.vala:1018` calls, ids 2–34101.

| When | Calls | What |
| ---- | ----: | ---- |
| 13:05:02–13:05:42 | 30,021 | Boot |
| 13:05:54–13:06:08 | 3,700 | Layout. `RPC-Live-Callback.reply` 619, `St-Adjustment.get_value` 324, preferred size, `allocate` |
| 13:06:16–13:07:09 | 379 | A few calls a second. `get_actor_at_pos` 55, preferred size, callback replies |

Same kind of boot as the 2026-09-29 log: `St-Button.new` 475 (was 503), `Helper-Actor.create` 712 (was 711), `add_child` 2,201 (was 2,330). This log ends at the kill. `get_next_sibling` is 9 here and 1,931 in the earlier log, which kept going through the pointer walk.

| Call | 2026-09-29 | 2026-09-30 |
| ---- | ---------: | ---------: |
| `rpc_signal` | 5,286 | 5,146 |
| `add_properties` | — | 1,168 |
| `add_hooks` | — | 45 |
| `set_style_class_name` | 1,740 | 1,651 |
| `set_x_expand` | 1,139 | 469 |
| `set_y_expand` | 1,006 | 374 |
| `set_text` | 462 | 70 |
| `hide` | 667 | 607 |
| `set_pivot_point` | 301 | 303 |
| `set_gicon` | — | 47 |

`add_hooks` is 45 for 712 `Helper-Actor.create`. An actor with no vfunc hooks sends no hook call.

`add_properties` is the sets that happen after `construct` returns, when the derived name is a real property. The next call that is not one of those sets flushes the map: `add_child` 567 times, `St-Label.get_clutter_text` 242, `get_text_direction` 131. `St-Label.set_text` falling from 462 to 70 is that map. `set_text` derives `text`, and that property exists. `set_x_expand` falling from 1,139 to 469 is the same, on the actors whose earlier setters also derived a real property.

The map is already open when the constructor properties run. `St-Button.new` is sent and replied, then `signal_overrides`, then `prop_batch_open = true`, then `construct` returns. GObject applies the remaining properties after that. A stock button has no overridden signals, so `signal_overrides` sends nothing, and the first logged call after `.new` is the first property.

`call_value` in `src/namespace.vala` derives the property name from the method tail: strip `set_`, turn `_` into `-`. `St-Widget.set_style_class_name` becomes `style-class-name`. The property on `St.Widget` is `style-class` (`g_param_spec_string ("style-class", ...)` in `St_generated.c`, and `set_property` calls `st_widget_set_style_class_name`). `find_property("style-class-name")` is null, so the name is cleared. A cleared name falls through to the close: `prop_batch_open = false`, and `add_properties` only if the map already has entries.

The map is empty, so there is no `add_properties`. `prop_batch_open` stays false. Every later setter on that actor is its own call: `set_button_mask`, `set_reactive`, `set_can_focus`, `set_x_expand`, `hide`. `St-Button.new` id 15697 at 13:05:14 is that shape. `set_style_class_name` is still 1,651. `hide` is still 607.

A later session, 14:31:17–14:31:47, 28,954 `Client.vala:1018` calls, has the same split. Of 3,810 constructors, the next logged call is `set_style_class_name` 801 times (the batch died on this name) and `add_properties` 775 times (every setter up to the flush derived a real property).

`rpc_signal` stays one call per name. 5,146 of them.

`set_pivot_point` stays its own call. It has two arguments. `Helper-Icon.set_gicon` stays its own call (47). A string is not a `GIcon`.

`add_properties` wrote `mapped` with `set_property`. That property is not writable. Twelve criticals: `StEntry` 3, `StWidget` 3, `WorkspacesDisplay` 3, and one each for `DateMenuButton`, `QuickSettings`, and `InputSourceIndicator`.

The scoreboard row is still open. The first setter whose method tail is not the property name closes the map for that actor, and each signal name is still its own call.

## 2026-09-29 baseline

A nested session that the user had not driven reached 32,000 client calls in 29 seconds. The log finished at 45,080. Most of that is a first write or a first subscribe per new actor, or a getter whose answer does not change until a signal we already receive.

**Plan:** [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)

**Seen:** 2026-09-29 15:56:21–15:58:03. `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`. Nested `mutter-rpc` + `gnome-shell-rpc`. The user had not clicked or typed. Pointer `captured-event` was still zero when the call count crossed 32,000.

The log ends at 15:58:03 with `Unexpected early end-of-stream` after call id 45081. That abort was the unregistered `MetaWindowWayland` in that session ([`2026-09-24-overview-picker-preview-gone.md`](2026-09-24-overview-picker-preview-gone.md)). The session now stays up. This bug is the call volume, not that abort.

## What the 2026-09-29 log shows

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

Scoreboard for this bug: the four-call cut only. Row 1 keeps one call per batch, so its removed count is the extras, not the whole bucket. The 13:05 log measured this construction. `set_style_class_name` derives `style-class-name` and closes the map, and `rpc_signal` is still one call per name.

| | Change | Calls removed |
| - | ------ | ------------- |
| 1 | Four calls per new actor: create, signals, hooks, properties | every signal after the first, every hook register after the first, every initial setter after the property call |
| 2 | `add_child` / `set_child` stay their own call | none — 2,330 + 681 stay |

Row 1 is the init spike. It does not fold those calls into `.new`. Row 2 stays one call per `add_child` / `set_child` (2,330 + 681).

Row 1's inputs are 5,286 `RPC-Live-Subscribe.rpc_signal`, the per-vfunc `RPC-Live-Callback.register`, and 8,949 counted setters: `set_style_class_name` 1,740, `set_x_expand` 1,139, `set_y_expand` 1,006, `set_x_align` 923, `set_y_align` 821, `set_can_focus` 639, `set_layout_manager` 596, `set_reactive` 564, `St-Label.set_text` 462, `set_orientation` 397, `set_label_actor` 361, `set_pivot_point` 301. The `.new` itself stays. Initial `hide` is another 667, as the `visible` property on the property call.

Row 2 is `add_child` 2,330 and `St-Bin.set_child` 681.

## Other call summary

**Parked 2026-09-30.** Split out of the scoreboard. These are the other buckets in the same 2026-09-29 log. Not the RPC flood. A lot of that may already be gone. Look here only after the four-call cut, and only against a fresh log.

`style-changed` was firing in the same seconds as the layout bursts (283 notifications), so rows 4 and 5 do not get to claim every call they touch.

| | Change | Calls removed | Share |
| - | ------ | ------------: | ----: |
| 3 | Local child list: `get_next_sibling`, `get_first_child`, `get_parent` | 2,813 | 6% |
| 4 | Preferred size until `queue_relayout`, a child change, or `style-changed` | a few hundred of 2,331 | |
| 5 | Theme node and `ThemeNode.get_length` until `style-changed` | a few hundred of 1,973 | |
| 6 | `get_text_direction` and `St.Settings` until the matching notify | 331, plus settings getters each under 300 | ~1% |
| 7 | Skip a setter when the cached value already matches | a few hundred | <1% |

Row 3 removes **2,813** calls (6%). It is `get_next_sibling` 1,931, `get_first_child` 503, `get_parent` 379. The client already sent the `add_child`. `child-added` (257 notifications) covers a child the server inserts itself. `get_children` was under 300 and drops with the same list.

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
| signals | one `rpc_signal` per initial name (`"s"`, the registered signature) | same `construct`, after the lease exists |
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

ARCHIVE_REST
