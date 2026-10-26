# Actor construct lease is a switch

**Status:** ⏳ open. The `St-Widget` arm is out of the switch. `applications-picker-smoke: ok` at 11:42:39.384. `state=2`, `checked=true`, `page=800x299`, `pickable=30`. No `St-Widget.new`.

## Purpose

- 🔷 Delete the switch in `Actor.rpc_construct` (`src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala`).
- 🔷 ⏳ Each arm names the activity that added it. The pass for that phase is that activity. The Help click does not stand in for it.
- ✔️ Phase 1 deleted the `Clutter-Clone`, `Meta-BackgroundActor`, and `St-DrawingArea` returns together. `help-click-smoke: ok` at 11:06:42.046.
- ✔️ The `Meta-WindowActor` label is out. `help-click-smoke: ok` at 11:23:34.617. No `Meta-WindowActor.new`. The `-32602` lines in that log are `St-Widget.set_label_actor`.
- ✅ The `St-Widget` arm is out. `applications-picker-smoke: ok` at 11:42:39.384. `state=2`, `checked=true`, `page=800x299`, `pickable=30`. `Gsr-Clutter-Actor.create` 591. `St-Button.new` 509. No `St-Widget.new`.

## What we have

ℹ️ This is `Actor.rpc_construct` in `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` now. It is the current switch, copied from that file.

```vala
	protected virtual void rpc_construct()
	{
		var t = this.get_type();
		while (t != GLib.Type.INVALID) {
			if (OLLMrpc.Bin.gtype_to_alias == null
					|| !OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
				t = t.parent();
				continue;
			}
			var alias = OLLMrpc.Bin.gtype_to_alias.get(t);
			switch (alias) {
				case "St-Bin":
					// Exact bin uses St-Bin.new below. Shell.SquareBin leases the
					// square peer before the icon is built.
					// This is very hacky however - and probably needs a better design.
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
					/* Already leased, including by SquareBin.rpc_construct.
					   Subscribe once. A second mint drops the child. */
					if (this.rpc_lid != 0) {
						this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
						this.prop_batch_open = true;
						return;
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
			if (this.rpc_lid != 0) {
				this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
				this.prop_batch_open = true;
				return;
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

## Phase 1 — delete the three returns

- ✔️ The `Clutter-Clone`, `Meta-BackgroundActor`, and `St-DrawingArea` cases are gone. Each class already leases in its own `rpc_construct` and does not call the base. `help-click-smoke: ok` at 11:06:42.046. `Clutter-Clone.new` 2. `Gsr-Mutter-BackgroundActor.create` 15. `Gsr-St-DrawingArea.create` 5. `St-DrawingArea.new` 9. No `Meta-BackgroundActor.new`.
- ℹ️ `St-DrawingArea` is the quick settings bars. `BarLevel` and `Slider` stayed at `rpc_lid` 0 when this lease was missing (session `08:21:24` in this file). The activity is those sliders having a height. `tests/gjs-embed/slider-grab-smoke.js` drives two sliders.
- ℹ️ `Clutter-Clone` is a window clone. A null-arg `Clutter-Clone.new` is `-32602`. The 2026-10-24 overview prove did not construct a Clone. The activity is an overview window thumbnail.
- ℹ️ `Meta-BackgroundActor` is the desktop background. A null-arg `.new` is `-32602`. It needs the display and the monitor. The activity is the wallpaper on screen after boot.
- 🔷 Pass is `help-click-smoke: ok`.
- 💩 If `Clutter-Clone.new` or `Meta-BackgroundActor.new` comes back `-32602`, or `Gsr-St-DrawingArea.create` or `St-DrawingArea.new` drops to zero, the switch was still the mint. Put the cases back.

#### Remove

```vala
				case "Meta-BackgroundActor": // leaf Helper
				case "Clutter-Clone": // Clone.override new(source)
				case "St-DrawingArea": // DrawingArea.construct
					return;
				case "Meta-WindowActor": // no Meta-WindowActor.new
```

#### Replace with

```vala
				case "Meta-WindowActor": // no Meta-WindowActor.new
```

## Phase 2 — delete the `Meta-WindowActor` case

- ✔️ The label is gone. `Meta.WindowActor.rpc_construct` still leases, then calls the base. `help-click-smoke: ok` at 11:23:34.617. yelp `state=2`, `windows=1`, `normal=1`. No `Meta-WindowActor.new`.
- ℹ️ This is the compositor actor for a real window. There is no `Meta-WindowActor.new`. The 11:23 Help log has no `WindowActor` line, so that click did not show this lease. The activity is a window mapped on screen.
- 💩 This label shares its body with `St-Widget`. Removing the label lets `Meta-WindowActor` fall through to the stock `alias + ".new"` path. A lease that already exists hits the `rpc_lid` check under the switch and only subscribes signals.
- 🔷 Pass is `help-click-smoke: ok`.
- 💩 `-32602` on `Meta-WindowActor.new` means the switch was still the mint. Put the label back.

#### Remove

```vala
				case "Meta-WindowActor": // no Meta-WindowActor.new
				case "St-Widget":
```

#### Replace with

```vala
				case "St-Widget":
```

## Phase 3 — delete the `St-Widget` arm

- ✅ The `St-Widget` arm is gone. `applications-picker-smoke: ok` at 11:42:39.384. `state=2`, `checked=true`, `visible=true`, `mapped=true`, `items=147`, `page=800x299`, `pickable=30`. `Gsr-Clutter-Actor.create` 591. `St-Button.new` 509. No `St-Widget.new`. Prove exit 137 is the wrapper timeout. That pass line is not in `SMOKE_OK_PAT`.

```bash
GI_META_SMOKE=shell-boot/ui/init GSR_WESTON_PIXMAN=1 \
  GSR_NESTED_TIMEOUT=90 ./scripts/agent-nested-smoke-prove.sh
```

That is `tests/gjs-embed/shell-boot/ui/init.js`, which imports `applications-picker-smoke.js`. Direct `GI_META_SMOKE=applications-picker-smoke` never reaches the grid. The pass line is in the log. It is not in `SMOKE_OK_PAT`, so the prove exit code is not the pass. A miss on this arm is `applications-picker-smoke: miss state`.
- 🔷 ⏳ Depends on phase 2. `St.Widget.rpc_construct` already leases an exact widget, then calls the base. A registered subclass such as `St.Button` is not this arm. Its alias is `St-Button`, and that stays `alias + ".new"`.
- ℹ️ The click in that smoke is the Show Applications button (`Gjs_ui_dash_ShowAppsIcon`). The 12:29 log sent that type, and `Gjs_ui_layout_UiActor`, through this arm (`Gsr-Clutter-Actor.create`).
- 💩 If an exact `St.Widget` reaches this with `rpc_lid` still 0, it would call `St-Widget.new` instead of `create_with_overrides`. Put the arm back.

#### Remove

```vala
				case "St-Widget":
					/* Widget.rpc_construct already leased an exact
					   widget. A later entry must not mint again. */
					if (this.rpc_lid != 0) {
						this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
						this.prop_batch_open = true;
						return;
					}
					this.create_with_overrides();
					this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
					this.prop_batch_open = true;
					return;
				case "St-Viewport":
```

#### Replace with

```vala
				case "St-Viewport":
```

## Phase 4 — delete the `St-Viewport` arm

- 🔷 ⏳ Depends on phase 3. Exact `St.Viewport` already falls through to `St-Viewport.new`. A subclass is leased by `St.Viewport.rpc_construct` before the base runs.
- ℹ️ Show Applications. The app grid is a GJS `St.Viewport`. The page stayed `0x0` until a subclass leased `ViewportActor` and `allocate` ran. Record: `docs/bugs/done/2026-10-12-applications-picker-not-working.md`. Changing page is still `docs/bugs/2026-10-22-app-grid-pagination.md`.
- 🔷 ⏳ Same command as phase 3. Needs to pass `applications-picker-smoke: ok`. A miss on this arm is `applications-picker-smoke: miss page-size`.
- ℹ️ The overlap line is not this arm. With the arm out, the icon boxes stayed `145x145` for 45s (`redraw 0` through `redraw 44`, `matched=0`) and the page stayed `800x299`. With the arm back in, the same wait did the same thing: `145x145` for 45s, `late state` page `800x299`, `pickable=30`, `miss overlap` at 08:08:54.237. Preferred size stayed `73`. The shot after that wait shows the grid drawn. The arm is out.
- 💩 If `Gsr-St-Viewport.create` drops to zero, the arm was still the mint. Put it back.

#### Remove

```vala
				case "St-Viewport":
					/* Exact Viewport uses St-Viewport.new below.
					   A subclass leases ViewportActor.
					   Viewport.rpc_construct may already have leased. */
					if (this.get_type() == t) {
						break;
					}
					if (this.rpc_lid != 0) {
						this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
						this.prop_batch_open = true;
						return;
					}
					this.create_viewport();
					this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
					this.prop_batch_open = true;
					return;
				case "St-Bin":
```

#### Replace with

```vala
				case "St-Bin":
```

## Phase 5 — delete the `St-Bin` arm

- 🔷 ⏳ Depends on phase 4. `Shell.SquareBin.rpc_construct` already leases `Gsr-St-SquareBin.new`, then calls the base. Exact `St.Bin` falls through to `St-Bin.new`.
- ℹ️ Show Applications icons. Added 2026-10-22 in the same picker record. Without this lease the icons overlapped and the labels were one character wide. The Help dash icon is the same type, which is why that click sees it. The activity that added the arm is the app grid icons.
- 🔷 ⏳ Same command as phase 3. Needs to pass `applications-picker-smoke: ok`. A miss on this arm is `applications-picker-smoke: miss overlap`.
- 💩 If `Gsr-St-SquareBin.new` drops, or `base-child` is null, the arm was still the mint. Put it back.

#### Remove

```vala
				case "St-Bin":
					// Exact bin uses St-Bin.new below. Shell.SquareBin leases the
					// square peer before the icon is built.
					// This is very hacky however - and probably needs a better design.
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
					/* Already leased, including by SquareBin.rpc_construct.
					   Subscribe once. A second mint drops the child. */
					if (this.rpc_lid != 0) {
						this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
						this.prop_batch_open = true;
						return;
					}
					var response = Gsr.Client.Rpc.call_value("Gsr-St-SquareBin.new", null,
						OLLMrpc.args("t", (uint64) 0));

					this.rpc_lid = (response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
					Gsr.Client.Rpc.register_handle(this);
					this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
					this.prop_batch_open = true;
					return;
				case "Clutter-Actor":
```

#### Replace with

```vala
				case "Clutter-Actor":
```

## Phase 6 — `Clutter-Actor` leaves the switch

- 🔷 ⏳ Depends on phase 5. This arm is last, on its own.
- ℹ️ A GJS or Vala actor that is not a registered St type. The arm comment says those need the helper hooks. Exact `Actor` uses `.new`. The boot count of those helpers is in `docs/bugs/done/2026-09-29-rpc-call-volume.md`. The activity is the shell finishing boot with its plain actors.
- 💩 It does not become `Clutter-Actor.new`. An unregistered subclass still uses `create_with_overrides`.
- 🔷 ⏳ Same command as phase 3. Needs to pass `applications-picker-smoke: ok`. A miss on this arm is `applications-picker-smoke: miss controls`.
- 🔷 The `queue_relayout` compare in `Actor.construct` stays. User 2026-10-24.
- ℹ️ `alias + ".new"` stays. That is `St-Button.new` for the dash and the other buttons. It is not one of these deletions.

#### Remove

```vala
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
```

#### Replace with

```vala
				default:
					break;
			}
			if (alias == "Clutter-Actor" && this.get_type() != typeof(Actor)) {
				this.create_with_overrides();
				this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
				this.prop_batch_open = true;
				return;
			}
```

## LLM efforts

### 2026-10-25 old phases and the end-state proposal removed

The class leases are already in the tree. The old phase 1–8 writeups and the end-state fences were removed from this file. Phases 1–3 above are the deletions. The trial log below is unchanged.

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

### 2026-10-23 16:32 restored baseline and proposal

Product source was rolled forward back to the pre-refactor `2e70d04` constructor semantics. The separate child `2026-10-23-construct-style-during-init.md` was removed, and the complete proposal and effort history were restored here as the only planning surface.

`meson compile -C build` passed. `./scripts/weston-gsr-prove.sh` reached `weston-gsr-autolaunch: prove ec=0`; the wrapper then stopped Weston and exited 137 as part of that stop. The later end-of-stream and `no rpc_lid` flood is teardown after the successful prove, not the live acceptance result.

Future work must apply the proposal gradually, one section or switch arm at a time. Before each product stage, add a focused gate for that arm; after each stage, rebuild and pass the Weston proof before proceeding.

### 2026-10-24 08:40 phases

Product source is still `8cbe4bb`. No `src/` edit.

The deleted child is `git show c2ff8a9:docs/bugs/2026-10-23-construct-style-during-init.md`. It says `Actor.construct`'s `this.rpc_construct()` misses a JavaScript subclass because the slot is empty, and proposes `rpc_lease` plus `Signal.override_class_handler`. That signal was removed because it would show up in the GIR. The parent effort log already had the session facts. The top of this file did not say that the next edit is a probe, so the end-state fences were still easy to apply as one diff.

GJS 1.82.1 `gi/gobject.cpp` `gjs_object_class_init` replaces `constructor`, `get_property`, and `set_property`. `modules/core/overrides/GObject.js` calls `hook_up_vfunc` only for own `vfunc_*` methods. It does not clear other slots. The null-slot sentence stays an inference until Phase 1 logs `before lease walk` and `virtual lease` for BarLevel, Slider, MessageView, and a SquareBin subclass.

Phases are in this file. Phase 1 adds the virtual and leaves the switch as the lease. SquareBin is the first override. Widget, WindowActor, Clone, BackgroundActor, Viewport, then DrawingArea. The old arm stays until the virtual lease for that type is written here. `rpc_lease` stays parked.

### 2026-10-24 09:03 phase 1 prove

`meson compile -C build` passed. `./scripts/weston-gsr-prove.sh` ended `weston-gsr-autolaunch: prove ec=0`, then the wrapper killed Weston (exit 137). Read `org.gnome.ShellRpc.debug.log` only. `weston-autolaunch-prove.log` is 54,350,129 lines.

The invoker is `if (_klass_->rpc_construct) _klass_->rpc_construct (self)`. A missing `virtual lease` line means that slot was null.

| Type | Parent | `before lease walk` | `virtual lease` |
| --- | --- | --- | --- |
| `StDrawingArea` | exact | 09:03:53.555116 | 09:03:53.555124 |
| `Gjs_ui_barLevel_BarLevel` | `St.DrawingArea` | 09:03:53.609904 | none |
| `Gjs_ui_slider_Slider` | `BarLevel` | 09:03:56.341488 | none |
| `Gjs_ui_messageList_MessageView` | `St.Viewport` | 09:03:54.081464 | none |
| `Gjs_ui_iconGrid_BaseIcon` | `Shell.SquareBin` | 09:03:54.796118 | 09:03:54.796165 |
| `Gjs_ui_layout_UiActor` | `St.Widget` | 09:03:53.480795 | 09:03:53.480815 |

`BarLevel`, `Slider`, and `MessageView` have no `virtual lease` line anywhere in that log. After the missed body, `get_theme_node` runs with `no rpc_lid`, then `Gsr-St-DrawingArea.create` (id 390 at 09:03:53.610220). That is the old `DrawingArea.construct` lease, after the style callback. The switch still leased everyone else. `Gsr-St-SquareBin.new` is at 09:03:54.797041, after BaseIcon's virtual body.

The probe debug lines are removed. The empty `rpc_construct` and the call stay. Next landing is Phase 2.

### 2026-10-24 09:43 chain call

User: the call walks parent classes until one has `rpc_construct`, then calls that function with this object. No hardcoded class list. Written as [Phase 1 chain call](#phase-1-chain-call). Not applied. The switch still leases. Phase 2 waits on that call.

### 2026-10-24 10:42 chain prove

`clutter_actor_rpc_construct_chain(this)` is the call. The C name stays `clutter_actor_rpc_construct_chain`. `meson compile -C build` passed. `./scripts/weston-gsr-prove.sh` ended `stop (picker-up)` after 19s and `prove ec=0`, then the wrapper killed Weston (exit 137). `GNOME Shell started at` is 10:43:10.172 in `nested-weston-prove.tee.log`.

The first build called the first non-null slot. For `BarLevel` that slot was on `Gjs_ui_barLevel_BarLevel` and it was not Actor's function. `vfunc_style_changed` ran inside that call, before `chain done`, and `get_theme_node` logged `no rpc_lid`. Same for `Slider`, `MessageView`, and `BaseIcon`. Exact `StDrawingArea` and `StBin` matched Actor's function. The walk now skips a `Gjs_` class whose function differs from its parent.

10:42 log, after that skip (`org.gnome.ShellRpc.debug.log`):

| Instance | Function used |
| --- | --- |
| `Gjs_ui_barLevel_BarLevel` | `StDrawingArea` (10:42:56.194809) |
| `Gjs_ui_slider_Slider` | `StDrawingArea` (10:43:01.873869) |
| `Gjs_ui_messageList_MessageView` | `StViewport` (10:42:56.996710) |
| `Gjs_ui_iconGrid_BaseIcon` | `ShellSquareBin` (10:42:58.477776) |

`Gsr-St-DrawingArea.create` is the next line after BarLevel's chain log (id 390 at 10:42:56.194923). That log has no `no rpc_lid` for those four types. The chain debug line is removed after this record. The switch still leases. Next landing is Phase 2.

### 2026-10-24 10:49 phase 2 prove

Works as expected. Prove `stop (picker-up)`, `ec=0`. The `square lease` line is removed. Next is the `St.Widget` override.

### 2026-10-24 10:58 phases 3–5

Widget, WindowActor, and Clone overrides, proved together. Works as expected. `stop (picker-up)`, `ec=0`. This overview did not construct a Clone or a WindowActor. The `phase lease` lines are removed. The `queue_relayout` compare stays until the last step.

### 2026-10-24 11:05 rollback

Help on the bottom bar did not launch after phases 3–5. Those three overrides and the `gsr-st-boxed` dependency change are out. `create_with_overrides` is private again. Phase 2 stays: the chain call and `SquareBin.rpc_construct`.

### 2026-10-24 11:09 rollback to phase 1

Help still failed at phase 2. `SquareBin.rpc_construct` is out. `Actor.construct` no longer returns after the chain. The chain call stays, and the switch leases.

### 2026-10-24 11:21 signals stay last

Help works at phase 1. Phase 2 had lifted `signal_overrides` and `prop_batch_open` to one call after the chain, and skipped the switch. That call is the end state of `construct`, after the switch is gone. It is not the next phase. The next phases move the lease out of each switch arm. The arm keeps the signal call.

### 2026-10-24 11:42 switch replacement

User asked to replace the switch. The arms are gone. `Actor.construct` calls the chain, then `signal_overrides` and `prop_batch_open` when `rpc_lid` is set. The `queue_relayout` compare stays. `bind_vfunc` is `protected` again so `St.Viewport` and `St.DrawingArea` can call it.

`meson compile -C build` passed. `./scripts/weston-gsr-prove.sh` ended `stop (picker-up)` after 19s and `prove ec=0`, then the wrapper killed Weston (exit 137). `GNOME Shell started at` is 11:42:15.153 in `nested-weston-prove.tee.log`.

11:42 client log, method counts:

| Method | Count |
| --- | --- |
| `St-Button.new` | 201 |
| `Gsr-Clutter-Actor.create` | 246 |
| `St-Bin.new` | 62 |
| `Gsr-St-SquareBin.new` | 60 |
| `St-DrawingArea.new` | 24 |
| `Gsr-Mutter-BackgroundActor.create` | 15 |
| `Gsr-St-DrawingArea.create` | 5 |
| `Gsr-St-Viewport.create` | 2 |

No `no rpc_lid`. No `JS ERROR`. This overview did not call `St-Viewport.new` or `Clutter-Clone.new`. Help was not clicked.

### 2026-10-24 11:44 drawing-area lease inlined

`open_drawing_area_lease` and `create_drawing_area` are the body of `St.DrawingArea.rpc_construct`. Exact type calls `St-DrawingArea.new`. A subclass calls `Gsr-St-DrawingArea.create` and hooks preferred size.

### 2026-10-24 12:10 switch replacement taken back

The user said boot did not work. The class overrides were removed by editing the files. No git restore. What stayed is the chain call, the empty `rpc_construct`, `c-rpc-construct-chain.c`, and the switch as the lease.

`meson compile -C build` passed. `./scripts/weston-gsr-prove.sh` ended `stop (picker-up)` after 22s and `prove ec=0`, then the wrapper killed Weston (exit 137). `GNOME Shell started at` is 12:10:36.072 in `nested-weston-prove.tee.log`. No `JS ERROR`. No `no rpc_lid`. Help was not clicked. The 11:42 prove had the same stop and the user said that boot did not work, so this stop is not that confirmation.

### 2026-10-24 12:29 chain versus switch

Two debug lines, then removed. The chain logged the instance, the class whose `rpc_construct` it called, and whether that function is Actor's. The switch logged the alias and whether the instance is that registered type. `./scripts/weston-gsr-prove.sh` ended `prove ec=124` before `GNOME Shell started`. Logging every construct blew the nest timeout. 1106 chain calls, all `inherited=yes`.

The chain calls Actor's empty method and does not lease. The switch then leases. Eight instances stop on a parent class because the JavaScript slot differs. The rest stop on their own class, which still holds Actor's function.

| Instance | Chain class | Switch | Lease after the switch |
| --- | --- | --- | --- |
| `Gjs_ui_barLevel_BarLevel` | `StDrawingArea` | `St-DrawingArea` exact=no | `Gsr-St-DrawingArea.create` |
| `Gjs_ui_slider_Slider` | `StDrawingArea` | `St-DrawingArea` exact=no | `Gsr-St-DrawingArea.create` |
| `StDrawingArea` | `StDrawingArea` | `St-DrawingArea` exact=yes | `St-DrawingArea.new` |
| `Gjs_ui_messageList_MessageView` | `StViewport` | `St-Viewport` exact=no | `Gsr-St-Viewport.create` |
| `Gjs_ui_appDisplay_AppGrid` | `StViewport` | `St-Viewport` exact=no | `Gsr-St-Viewport.create` |
| `Gjs_ui_iconGrid_BaseIcon` | `ShellSquareBin` | `St-Bin` exact=no | `Gsr-St-SquareBin.new` |
| `StBin` | `StBin` | `St-Bin` exact=yes | `St-Bin.new` |
| `StButton` | `StButton` | `St-Button` exact=yes | `St-Button.new` |
| `StWidget` | `StWidget` | `St-Widget` exact=yes | `Gsr-Clutter-Actor.create` |
| `Gjs_ui_layout_UiActor` | `Gjs_ui_layout_UiActor` | `St-Widget` exact=no | `Gsr-Clutter-Actor.create` |
| `Gjs_ui_dash_ShowAppsIcon` | `Gjs_ui_dash_ShowAppsIcon` | `St-Widget` exact=no | `Gsr-Clutter-Actor.create` |
| `MetaBackgroundActor` | `MetaBackgroundActor` | `Meta-BackgroundActor` exact=yes | `Gsr-Mutter-BackgroundActor.create` |

Dash favorite icons were not constructed before the timeout. One `JS ERROR: TypeError: laters is null` came from `dash.js` `_queueUpdateRegions` in that same incomplete run. The 12:10 prove, without these lines, had no `JS ERROR`.

### 2026-10-24 18:05 switch moved into the chain's function

The 12:29 log showed every chain call used Actor's `rpc_construct`. The switch now is that function. `construct` only calls the chain. `St.DrawingArea.rpc_construct` calls `open_drawing_area_lease`. A debug line, since removed, showed that override running for `StDrawingArea`, `Gjs_ui_barLevel_BarLevel`, and `Gjs_ui_slider_Slider`.

`gsr-st-boxed` compiles against `mutter-clutter-rpc-16`. System `mutter-clutter-16` has no `rpc_construct`, so the boxed library would not build once `St.DrawingArea` overrode it.

`./scripts/weston-gsr-prove.sh` ended `stop (picker-up)` and `prove ec=0`. No `JS ERROR`. Lease counts matched the switch-only prove: `Gsr-Clutter-Actor.create` 252, `St-Button.new` 208, `St-Bin.new` 70, `Gsr-St-SquareBin.new` 60, `Gsr-Mutter-BackgroundActor.create` 15, `St-DrawingArea.new` 9, `Gsr-St-DrawingArea.create` 5, `Gsr-St-Viewport.create` 2.

`St.Widget`, `St.Viewport`, and `Shell.SquareBin` overrides were tried together. `Gsr-St-SquareBin.new` fell to 8. Removing them one at a time left the count at 8 until an `if (rpc_lid != 0) return` at the top of the switch was removed. With that return gone, and only the DrawingArea override kept, the count went back to 60. Help was not clicked.

### 2026-10-24 18:10 Help click failed

The user clicked Help on the build where the switch lived in `rpc_construct` and `St.DrawingArea` overrode it. Help did not launch. The click is not in `org.gnome.ShellRpc.debug.log` (that log is the 18:00 prove). The switch is back in `construct`, after the chain call. `rpc_construct` is empty. The DrawingArea override and the `gsr-st-boxed` dependency change are out.

`meson compile -C build` passed. `./scripts/weston-gsr-prove.sh` ended `stop (picker-up)` after 23s and `prove ec=0`. `GNOME Shell started at` is 18:12:27.712 in `nested-weston-prove.tee.log`. No `JS ERROR`. No `no rpc_lid`. Counts: `Gsr-Clutter-Actor.create` 252, `St-Button.new` 208, `St-Bin.new` 70, `Gsr-St-SquareBin.new` 8, `Gsr-Mutter-BackgroundActor.create` 15, `St-DrawingArea.new` 9, `Gsr-St-DrawingArea.create` 5, `Gsr-St-Viewport.create` 2. Seventy `g_atomic_ref_count_dec: assertion 'old_value > 0' failed`, three `closure->ref_count`, two `G_VALUE_HOLDS_OBJECT`. Help was not clicked.

### 2026-10-24 18:20 Help click is a smoke

The 18:12 client log has no `yelp` and no `JS ERROR`. The click is `tests/gjs-embed/help-click-smoke.js`. It boots the shell, pointer-clicks the `yelp.desktop` dash icon, and prints `help-click-smoke: ok` or `help-click-smoke: miss`. `scripts/nested-weston-prove.sh` treats `help-click-smoke: ok` as `stop (smoke-ok)`. Not run yet.

### 2026-10-24 19:06 Help click passes, then the lease move misses

`GI_META_SMOKE=help-click/ui/init ./scripts/agent-nested-smoke-prove.sh`. The script path ends in `ui/init.js`, so gsr-smoke takes `Server-Bootstrap.begin_shell_startup`. The click aims 38 by 59 pixels past the icon center. Virtual motion lands that far short of the requested point.

Switch in `construct`, empty `rpc_construct`. `help-click-smoke: ok` at 19:06:00.823. `clicked=true`, yelp `state=2`, `windows=1`, `normal=1`.

Then the switch moved into `rpc_construct`, `St.DrawingArea.rpc_construct` calls `open_drawing_area_lease`, and `gsr-st-boxed` compiles against `mutter-clutter-rpc-16`. `meson compile -C build` passed. The same command printed `help-click-smoke: miss no-launch` at 19:08:36.239. `clicked=true`, yelp `state=0`, `windows=0`, `normal=0`. `JS ERROR: TypeError: actor is null` at `zoomOutActor` (`iconGrid.js:182`) from `animateLaunch` during `vfunc_clicked`. The line before it is `St-Bin.get_child`. Ten `St-Widget.set_label_actor` calls returned -32602 before the click.

### 2026-10-24 19:21 the square bin child is already null

Same command. Before the click the Help button's child is a `GsrServerClutterActor`. `icon.icon.child` (`BaseIcon`, `Shell.SquareBin`) is null. `icon.icon._iconBin.child` is an `StIcon`. Calling `set_child` on that `BaseIcon` again still reads null (`reset-base-child null` at 19:20:47.788). The click still emits `clicked` and yelp stays `state=0`. `help-click-smoke: miss no-launch` at 19:21:00.788. `src/` was not changed.

### 2026-10-24 19:22 set_child finds the child already parented

The null read is a successful `St-Bin.get_child` reply, not an RPC error. The smoke's second `set_child` is the only `child->priv->parent == NULL` assertion in that log (19:20:47.775). The box already has a parent. This bin's `get_child` is still null after that call.

### 2026-10-24 19:49 the box parent is the same bin

Same command, logging `get_parent` of `_box`. `base-child=null`. `box-parent` is `GsrServerStSquareBinActor` and `is-base=true`. `help-click-smoke: miss no-launch` at 19:49:35.572.

### 2026-10-24 19:59 set_child sticks on other square bins

Wrapped `St.Bin.prototype.set_child`. Eight dash `overview-icon` bins logged `after=set` before the click. The Help bin address `0x646c082a2ad0` was not among them. It appears at 19:59:09 in `st_widget_get_theme_node` ("not in the stage") and at 19:59:15 as `box-parent` with `is-base=true` and `base-child=null`. `Clutter.Actor.prototype.add_child` logged nothing. `src/` was not changed.

### 2026-10-24 20:12 wrapping get_child does not affect the property

`St.Bin.prototype.get_child` falling back to `get_child_at_index(0)` never logged. `base-child` stayed null. `help-click-smoke: miss no-launch` at 20:13:29.703. The shell reads the GI property, not that method.

### 2026-10-24 20:31 zoom via `_box` launches yelp

After `main.start()`, `BaseIcon.prototype.animateZoomOut` calls `zoomOutActor(this._box)` when `this.child` is null. Before the click: `base-child=null`, `n=0`, `at0=null`, `box-parent` is the bin, `is-base=true`. `zoom via box` at 20:30:58.486. `help-click-smoke: ok` at 20:31:01.208. `clicked=true`, yelp `state=2`, `windows=1`, `normal=1`. `stop (smoke-ok)`. `src/` was not changed. That patch is no longer in the smoke.

### 2026-10-24 20:38 a JS child property does not override GI

`Object.defineProperty(St.Bin.prototype, 'child', …)` logged `child property wrapped`. `base-child` stayed null. `TypeError: actor is null` at 20:38:20.440. `help-click-smoke: miss no-launch` at 20:38:34.926.

### 2026-10-24 20:41 remove_child is the wrong object

`icon.icon.remove_child(_box)` returned without a JavaScript exception. The server logged `clutter_actor_remove_child: assertion 'child->priv->parent == self' failed` at 20:41:17.720. The following `set_child` logged `child->priv->parent == NULL` at 20:41:17.721. `repair set child=null`. `help-click-smoke: miss no-launch` at 20:41:33.252. `rpc_lid` is not visible to the smoke (`lid=absent`).

### 2026-10-24 21:30 the square arm mints again

`GLib.debug` in the square arm, then `GI_META_SMOKE=help-click/ui/init ./scripts/agent-nested-smoke-prove.sh`. `square arm` 223 times, `square construct` 0. 55 of the arm logs had `old` non-zero, including `Gjs_ui_iconGrid_BaseIcon old=928` at 21:30:32.589 during `set_allocation` / `allocate_public`. `Shell.SquareBin.construct` did not mint. The debug lines were removed after that run.

### 2026-10-25 09:20 skip the second mint, Help launches

The square arm returns when `rpc_lid != 0`, before `Gsr-St-SquareBin.new`. The check is not at the top of the switch. `meson compile -C build`. Same smoke command. `base-child` is an `StBoxLayout`, `n=1`, `at0` is that box, `is-base=true`. `help-click-smoke: ok` at 09:20:48.853. `clicked=true`, yelp `state=2`, `windows=1`, `normal=1`. `stop (smoke-ok)` after 22s. `Gsr-St-SquareBin.new` 16 times in that log. No `JS ERROR`.

### 2026-10-25 09:29 SquareBin.rpc_construct still launches Help

`Shell.SquareBin.rpc_construct` mints when `rpc_lid` is 0, then calls `base.rpc_construct()`. A second entry returns. The `St-Bin` arm, when the lid is already set, calls `signal_overrides` and does not mint. `SquareBin.construct` is unchanged. `meson compile -C build`. `GI_META_SMOKE=help-click/ui/init ./scripts/agent-nested-smoke-prove.sh`. `help-click-smoke: ok` at 09:29:35.348. `base-child` is an `StBoxLayout`, `n=1`. `clicked=true`, yelp `state=2`, `windows=1`, `normal=1`. `stop (smoke-ok)` after 22s. `Gsr-St-SquareBin.new` 16. No `JS ERROR`.

### 2026-10-25 09:50 Widget.rpc_construct still launches Help

`St.Widget.rpc_construct`: a registered subclass calls `base.rpc_construct()`. Exact widget calls `create_with_overrides()` (`protected`) then the base. The `St-Widget` arm and the default `.new` path skip a second mint when `rpc_lid` is set and still call `signal_overrides`. `meson compile -C build`. `GI_META_SMOKE=help-click/ui/init ./scripts/agent-nested-smoke-prove.sh`. `help-click-smoke: ok` at 09:50:11.448. `base-child` is an `StBoxLayout`, `n=1`. `clicked=true`, yelp `state=2`, `windows=1`, `normal=1`. `stop (smoke-ok)` after 21s. `St-Button.new` 418. `Gsr-St-SquareBin.new` 16. `Gsr-Clutter-Actor.create` 508. No `JS ERROR`.

### 2026-10-25 09:55 WindowActor.rpc_construct still launches Help

`Meta.WindowActor.rpc_construct` leases with `create_with_overrides()` when no derived alias is registered, then calls the base. A later call calls the base, and the `Meta-WindowActor` arm does not mint again. `help-click-smoke: ok` at 09:55:35.829. `base-child` is an `StBoxLayout`, `n=1`. yelp `state=2`, `windows=1`, `normal=1`. `stop (smoke-ok)` after 24s. No `JS ERROR`.

### 2026-10-25 09:58 Clone.rpc_construct still launches Help

`Clutter.Clone.rpc_construct` calls `Clutter-Clone.new` with `priv_source`. A later call returns. `construct` only sets `mint_done` when a lease already exists. `help-click-smoke: ok` at 09:58:14.666. `Clutter-Clone.new` 4. yelp `state=2`, `windows=1`, `normal=1`. `stop (smoke-ok)` after 36s. `layout_manager is null` logged during the app grid. The click still launched yelp.

### 2026-10-25 10:03 BackgroundActor.rpc_construct still launches Help

`Meta.BackgroundActor.rpc_construct` calls `Gsr-Mutter-BackgroundActor.create` with the display and monitor. A later call returns. `help-click-smoke: ok` at 10:03:36.246. `Gsr-Mutter-BackgroundActor.create` 30. yelp `state=2`, `windows=1`, `normal=1`. `stop (smoke-ok)` after 21s. No `actor is null`.

### 2026-10-25 10:08 Viewport.rpc_construct still launches Help

`St.Viewport.rpc_construct` leases a subclass with `create_viewport()` (`protected`), then calls the base. Exact viewport calls the base, and `St-Viewport.new` still runs. A later call calls the base, and the arm does not mint again. `help-click-smoke: ok` at 10:08:58.601. `base-child` is an `StBoxLayout`, `n=1`, `is-base=true`. yelp `state=2`, `windows=1`, `normal=1`. `stop (smoke-ok)` after 63s. `Gsr-St-Viewport.create` 5. No `actor is null`.

### 2026-10-25 10:11 DrawingArea lease only in rpc_construct, Help launches

`St.DrawingArea.construct` no longer calls `open_drawing_area_lease`. `rpc_construct` does, and that helper still subscribes signals. `construct` returns for an exact drawing area or a missing lease, and otherwise watches repaint. `help-click-smoke: ok` at 10:11:56.458. `base-child` is an `StBoxLayout`, `n=1`. yelp `state=2`, `windows=1`, `normal=1`. `stop (smoke-ok)` after 21s. `Gsr-St-DrawingArea.create` 5. `St-DrawingArea.new` 9. No `actor is null`.

### 2026-10-25 11:06 the three returns deleted together

`Clutter-Clone`, `Meta-BackgroundActor`, and `St-DrawingArea` left the switch in one edit. `meson compile -C build` passed. `GI_META_SMOKE=help-click/ui/init ./scripts/agent-nested-smoke-prove.sh`. `help-click-smoke: ok` at 11:06:42.046. yelp `state=2`, `windows=1`, `normal=1`. `Clutter-Clone.new` 2. `Gsr-Mutter-BackgroundActor.create` 15. `Gsr-St-DrawingArea.create` 5. `St-DrawingArea.new` 9. No `Meta-BackgroundActor.new`. No `actor is null`.

### 2026-10-25 11:23 Meta-WindowActor label removed

The `Meta-WindowActor` case label is gone. The `St-Widget` body stays. `meson compile -C build` passed. `GI_META_SMOKE=help-click/ui/init ./scripts/agent-nested-smoke-prove.sh`. `help-click-smoke: ok` at 11:23:34.617. yelp `state=2`, `windows=1`, `normal=1`. No `Meta-WindowActor.new`. The `-32602` lines are `St-Widget.set_label_actor`. No `actor is null`.

### 2026-10-25 11:42 St-Widget arm removed

The `St-Widget` case is gone. `St.Widget.rpc_construct` still leases an exact widget and an unregistered subclass with `create_with_overrides`, then calls the base. The base walk, with `rpc_lid` already set, subscribes signals and does not mint. `meson compile -C build` passed. `GI_META_SMOKE=shell-boot/ui/init GSR_WESTON_PIXMAN=1 GSR_NESTED_TIMEOUT=90 ./scripts/agent-nested-smoke-prove.sh`. `applications-picker-smoke: ok` at 11:42:39.384. `state=2`, `checked=true`, `page=800x299`, `pickable=30`. `Gsr-Clutter-Actor.create` 591. `St-Button.new` 509. No `St-Widget.new`. Prove exit 137 is the wrapper timeout.

### 2026-10-25 12:02 St-Viewport arm removed, grid overlaps

The `St-Viewport` case is gone. `meson compile -C build` passed. Same picker command. `applications-picker-smoke: miss overlap` at 12:02:49.574. `state=2`, `checked=true`, `page=800x299`, `pickable=30`. `Gsr-St-Viewport.create` 5. No `St-Viewport.new`. Settled icons `145x145` at a stride of about 88. Phase 3 settled `73x73` and logged ok. `Gsr-St-SquareBin.new` 168. A burst of `too much recursion` in `quickSettings.js` `_syncIndicatorsVisible` at 12:02:44. The shot at `~/.cache/gnome-shell-rpc/applications-picker.png` shows the icons piled up. The same deletion, run again, logged `miss overlap` at 12:14:25.126 with the same `145x145` boxes.

### 2026-10-25 12:16 arm restored, same early grid

The `St-Viewport` case was put back. Same picker command. Click at 12:16:15.803. `applications-picker-smoke: miss overlap` at 12:16:56.512. Icons still `145x145`. Page `800x299`, `pickable=30`. The 11:42 `73x73` line was about 62s after its click. This one was about 40s after the click. The grid had not finished redrawing. The overlap line is not a verdict on the arm.

### 2026-10-26 08:08 the 145 box does not move

The smoke now waits up to 45s for the first twelve icons' transformed size to match their preferred size. Arm out: `redraw 0` at 08:05:16.478 and `redraw 44` at 08:06:02.419 are both `145x145`, `matched=0`. `late state` page `800x299`, `pickable=30`, `stable=0`. `miss overlap` at 08:06:03.463. Preferred `73/73/73/73`. Arm put back and the same wait run: `redraw 0` at 08:08:07.165 and `redraw 44` at 08:08:53.230 are both `145x145`. `miss overlap` at 08:08:54.237. Page `800x299`, `pickable=30`. The shot after the wait shows the grid drawn. The overlap line is the same with the arm in or out. The arm is out again.

### 2026-10-25 12:18 the restore was not a stop

The overlap line is the same with the arm in or out, and it is read before the grid has finished redrawing. The deletion stays. Page size on those runs was `800x299`. `Gsr-St-Viewport.create` 5. No `St-Viewport.new`.
