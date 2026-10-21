# Applications picker does not work

**Status:** ⏳ open. Show Applications opens, and the page size is 800 by 299. The icons and their labels are drawn on top of each other. That is not the stock application grid.

**Next:** Icon size is chosen too early. `_findBestIconSize` returned 96 while the first icon's preferred size was `25/49/81/49`. After the icons settle, the same icon is `120/145/120/145` at icon size 96, and a later call returns 24. The picture is the 96px icons drawn on an 88 by 53 pitch. The pass is still a grid that looks like the stock one.

1. `ViewportActor.rpc_register` calls `OLLMrpc.Bin.register_alias("St-Viewport", typeof(ViewportActor))`. `set_child` accepts the grid. `viewport-scroll-child-smoke` at `22:43:08` is `ok`.
2. Picker screenshot `~/.cache/gnome-shell-rpc/applications-picker.png` at `22:52` (800×600). Two rows of large icons occupy the same space. Labels run together on one line (`Ásbrú Connection Manager` through `Character Map`).
3. Tee `22:52:45`: `page=800x299`, icons `0@18,218 145x145` then `1@106,218 145x145` (88px apart) and `8@18,271 145x145` (53px below the first). A 145px icon does not fit that pitch.

```bash
GSR_WESTON_SOCKET=wayland-gsr-viewpeer \
GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-viewpeer \
GI_META_SMOKE=viewport-scroll-child-smoke GSR_WESTON_PIXMAN=1 \
GSR_NESTED_TIMEOUT=40 ./scripts/agent-nested-smoke-prove.sh
```

```bash
GSR_WESTON_SOCKET=wayland-gsr-apppick \
GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-apppick \
GI_META_SMOKE=shell-boot/ui/init GSR_WESTON_PIXMAN=1 \
GSR_NESTED_TIMEOUT=90 ./scripts/agent-nested-smoke-prove.sh
```

Read `nested-weston-prove.tee.log`. The autolaunch log is about 5GB.

**Where it stands:** The grid is the scroll child and `IconGrid.vfunc_allocate` runs. The picture is overlapping icons. `applications-picker.png` at `22:52` is that frame. The smoke now fails with `miss overlap` when the next icon starts inside the previous icon.

**Still true:** A plain widget cannot be the scroll child. A real `St.Viewport` can, and it receives the scroll box. The page size is `IconGrid.vfunc_allocate`, which runs only after the grid is that child. The client `allocation` cache for `_box` and the scroll view can read 0×0 while the server boxes are already real. The grid server box at `22:52` is `0,0 800x299`. The icons on that grid overlap.

## Proposal

Applied, including `register_alias` in `rpc_register`. The fences below are the lease. The alias line is the part that made `set_child` accept the subclass.

`IconGrid.vfunc_allocate` sets the page size. A GJS `St.Viewport` subclass is leased as `ViewportActor`, whose `allocate` override emits that hook. A chain reply runs `st_viewport_allocate`. Exact `St.Viewport` stays `St-Viewport.new`.

`LayoutHooks`, `allocate_public`, preferred size, event, captured-event, and `style_changed` are not in this proposal. `DrawingAreaActor` emits its hook inside the override. This does the same for `allocate`. `helper_attached` stays false, so this lease does not go through `Gsr-Clutter-Actor.allocate_public`.

`vfunc_style_changed` and `vfunc_child_added` stay unwired. Spacing, padding, and key-focus tracking are not what sets the page size.

### 1. `src/server/libst-16/ViewportActor.vala` — allocate override

**Why:** `base.allocate` on an `St.Viewport` subclass is `st_viewport_allocate`.

**Where:** new file.

#### Add

```vala
/**
 * JS {@code St.Viewport} subclass. {@code StScrollable}, so
 * {@code St.ScrollView.set_child} accepts it. {@code allocate}
 * emits the client hook. A chain reply runs stock
 * {@code St.Viewport.allocate}.
 */
namespace Gsr.Server.St
{
	public class ViewportActor : global::St.Viewport
	{
		public Gee.HashMap<int, OLLMrpc.Live.Hook> vfuncs {
			get; set; default = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
		}
		public Gee.HashMap<int, string> method_names {
			get; set; default = new Gee.HashMap<int, string>();
		}
		static int allocate_id;

		public static void rpc_register()
		{
			OLLMrpc.Bin.register_alias("St-Viewport", typeof(ViewportActor));
			allocate_id = OLLMrpc.Gi.vfunc_offset(
				"Clutter", "Actor", "allocate");
		}

		/**
		 * Client hook, then stock viewport allocate when the
		 * reply asks to chain. An empty reply chains too.
		 */
		public override void allocate(global::Clutter.ActorBox box)
		{
			var hook = this.vfuncs.get(allocate_id);
			if (hook == null) {
				base.allocate(box);
				return;
			}
			hook.emit(OLLMrpc.args("tdddd",
				hook.connection.export(this),
				(double) box.x1, (double) box.y1,
				(double) box.x2, (double) box.y2));
			var reply = hook.reply_args;
			if (reply.size >= 1
					&& !(reply.get(0).type() == GLib.Type.BOOLEAN
						&& reply.get(0).get_boolean())) {
				return;
			}
			var saved = this.vfuncs;
			this.vfuncs = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
			base.allocate(box);
			this.vfuncs = saved;
		}
	}
}
```

### 2. `src/server/libst-16/Viewport.vala` — lease that actor

**Why:** `Gsr-Clutter-Actor.create` mints an `St.Widget`. This create mints `ViewportActor`. `add_hooks` is the `DrawingArea.add_hooks` loop with that cast. `Actor.add_hooks` is unchanged.

**Where:** new file.

**Depends on:** 1.

Do not `register_alias("St-Viewport", typeof(ViewportActor))`.

#### Add

```vala
/**
 * Lease for a JS {@code St.Viewport} subclass.
 */
namespace Gsr.Server.St
{
	public class Viewport : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-St-Viewport", typeof(Viewport),
				"create", "",
				"add_hooks", "Sv"
			);
			OLLMrpc.Request.register_live("Gsr-St-Viewport", new Viewport());
		}

		/**
		 * ''Gsr-St-Viewport.create'' — {@link ViewportActor} for a
		 * JS {@code St.Viewport} subclass.
		 */
		public void create(OLLMrpc.Request request)
		{
			var created = new ViewportActor();
			request.reply(new OLLMrpc.Response() {
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(created)),
			});
		}

		/**
		 * ''Gsr-St-Viewport.add_hooks'' — store construct vfunc
		 * hooks on the leased {@link ViewportActor}.
		 */
		public void add_hooks(
			OLLMrpc.Request request,
			string[] names,
			GLib.Variant vfunc_ids
		) {
			var created = request.connection.leases.get((int) request.lease_id)
				as ViewportActor;
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
	}
}
```

### 3. `src/server/libst-16/namespace.vala` and `src/meson.build` — compile and register

**Why:** Startup has to register the type and the RPC class.

**Where:** `rpc_register`, after `DrawingArea.rpc_register()`. `compositor_sources`, after `DrawingAreaActor.vala`.

**Depends on:** 1 and 2.

#### Remove

```vala
		DrawingArea.rpc_register();
		FocusManager.rpc_register();
```

#### Replace with

```vala
		DrawingArea.rpc_register();
		ViewportActor.rpc_register();
		Viewport.rpc_register();
		FocusManager.rpc_register();
```

#### Remove

```meson
  'server/libst-16/DrawingAreaActor.vala',
  'server/libst-16/FocusManager.vala',
```

#### Replace with

```meson
  'server/libst-16/DrawingAreaActor.vala',
  'server/libst-16/ViewportActor.vala',
  'server/libst-16/Viewport.vala',
  'server/libst-16/FocusManager.vala',
```

### 4. `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` — subclass lease

**Why:** The `St-Viewport` subclass arm calls `create_with_overrides()`, which leases `Gsr-Clutter-Actor`.

**Where:** that arm, and `create_viewport()` after `create_drawing_area()`.

**Depends on:** 2.

#### Remove

```vala
				case "St-Viewport":
					/* Exact Viewport uses St-Viewport.new below. A GJS
					 * subclass (IconGrid) has vfunc_allocate and needs
					 * the same hooks as St-Widget. */
					if (this.get_type() != t) {
						this.create_with_overrides();
```

#### Replace with

```vala
				case "St-Viewport":
					/* Exact Viewport uses St-Viewport.new below.
					   A subclass leases ViewportActor. */
					if (this.get_type() != t) {
						this.create_viewport();
```

#### Add

```vala
	/**
	 * GJS {@code St.Viewport} subclass. Peer is
	 * {@link Gsr.Server.St.ViewportActor}. Only {@code allocate}
	 * is hooked. {@code helper_attached} stays false.
	 */
	void create_viewport()
	{
		Gsr.Client.Rpc.hook_rows =
			new Gee.ArrayList<Gsr.Client.Rpc.InvokeRow>();
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
		var hooks = Gsr.Client.Rpc.call_value(
			"Gsr-St-Viewport.add_hooks", this,
			OLLMrpc.args("Sv", names, vfunc_ids.end()));
		var ids = hooks.args.get(0).get_variant();
		if (Gsr.Client.Rpc.handlers == null) {
			Gsr.Client.Rpc.handlers = new Gee.HashMap<int,
				Gsr.Client.Rpc.InvokeRow>();
		}
		var n = (int) ids.n_children();
		for (var i = 0; i < n; i++) {
			var id = ids.get_child_value(i).get_uint64();
			Gsr.Client.Rpc.handlers.set((int) id,
				Gsr.Client.Rpc.hook_rows.get(i));
		}
		Gsr.Client.Rpc.hook_rows = null;
	}
```

## What is sized

`applications-picker-smoke` at `08:20:47` (`~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`). `cache` is `actor.allocation`. `server` is `get_allocation_box()`. `wh` is `get_width()` by `get_height()`.

| Actor | Client cache | Server box | Mapped | Children |
| ----- | ------------ | ---------- | ------ | -------- |
| `AppDisplay` | 800×315 | 0,194 800×315 | yes | 1 |
| `_box` | 0×0 | 0,0 800×315 | yes | 2 |
| scroll parent | 0×0 | 0,0 800×299 | yes | 5 |
| scroll view | 0×0 | 0,0 800×299 | yes | 2 |
| grid | 0×0 | ∞,∞ −∞×−∞ | no | 147 |

The grid box is `CLUTTER_ACTOR_BOX_UNINITIALIZED` (`clutter-types.h`: `x1 = INFINITY`, `y1 = INFINITY`, `x2 = -INFINITY`, `y2 = -INFINITY`). `get_width` / `get_height` are 0×16 because `needs_allocation` is still set, so those getters return the natural size. Preferred size of the grid is `0/0×16/16`.

`_box` has `x_expand` and `y_expand`. `BinLayout` did give it the 800 by 315. The client cache stayed 0 by 0 because `Actor.allocation` reads `allocation_priv`, and that field is written by the client `allocate()` / `set_allocation` path. A stock child allocated only on the server does not update it.

## Why the grid is never allocated

`vendor/gnome-shell/js/ui/iconGrid.js`: `class IconGrid extends St.Viewport`. `appDisplay.js`: `class AppGrid extends IconGrid.IconGrid`. `St.Viewport` implements `St.Scrollable`. `BaseAppView._init` does `new St.ScrollView({ child: this._grid })`.

`src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala`, construct, `St-Viewport`: a subclass calls `create_with_overrides()`, which leases `Gsr-Clutter-Actor`. That server class extends `global::St.Widget` (`src/server/libmutter-clutter-16/ClutterActor.vala`). An exact `St.Viewport` uses `St-Viewport.new` and is a real viewport.

`st_scroll_view_set_child` (`gnome-shell` `src/st/st-scroll-view.c`):

```c
g_return_if_fail (child == NULL || ST_IS_SCROLLABLE (child));
```

Server log, same run, `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log` `08:20:33.701`, immediately after `St-ScrollView.new` and the scroll view's expand sets:

```text
recv id=2023 method=St-ScrollView.set_child
st_scroll_view_set_child: assertion 'child == NULL || ST_IS_SCROLLABLE (child)' failed
```

That is the grid. `st_scroll_view_init` adds only `hscroll` and `vscroll`, so the scroll view's child count stays 2. `st_scroll_view_allocate` calls `clutter_actor_allocate` on `priv->child` only. There is no child.

`clutter_actor_allocate` (`clutter-actor.c`) returns before the class allocate when the actor is not mapped and is not toplevel. The grid is visible in the client cache and unmapped on the server, so `IconGrid.vfunc_allocate` does not run. `_pageWidth` and `_pageHeight` stay 0.

The same assertion is logged again at `08:20:34.650`, `08:20:40.672`, `08:20:40.964`, and `08:20:41.016`. Other `St-ScrollView.set_child` calls in that boot do not assert.

## Steps

### 1. Show Applications opens the grid

On a normal desktop the Show Applications button opens the applications grid.

Here it works as expected.

### 2. The overview gives AppDisplay its box

`vendor/gnome-shell/js/ui/overviewControls.js`, `ControlsManagerLayout.vfunc_allocate`:

```js
this._appDisplay.allocate(appDisplayBox);
```

On a normal desktop that box is the applications area.

Here it works as expected. `AppDisplay` is 800 by 315.

### 3. AppDisplay stores that box and allocates on the server

`AppDisplay` is an `St.Widget`, so `allocate` takes the helper path. `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala`:

```vala
this.allocation_priv = box;
Gsr.Client.Rpc.call_value("Gsr-Clutter-Actor.allocate_public", this,
    OLLMrpc.args("ay", new GLib.Bytes(helper_data)));
```

On a normal desktop the actor keeps that box and the server runs `clutter_actor_allocate`.

Here it works as expected. The stored box is the 800 by 315 from step 2.

### 4. BinLayout gives that box to `_box`

`AppDisplay._init` sets `layout_manager: new Clutter.BinLayout()` and `this.add_child(this._box)`. `_box` is an `St.BoxLayout` with `x_expand` and `y_expand`. `clutter_bin_layout_allocate` ends on the child:

```c
clutter_actor_allocate_align_fill (child, &child_alloc,
                                   x_align, y_align,
                                   x_fill, y_fill);
```

On a normal desktop `_box` is the same 800 by 315.

Here the server box is that 800 by 315. The client `allocation` cache stays 0 by 0. `_box` is visible and mapped. See the table above.

### 5. BoxLayout gives `_box` to the scroll parent

`_box` holds the scroll parent. `allocate_box_child` in `clutter-box-layout.c`:

```c
clutter_actor_allocate (child, child_box);
```

On a normal desktop the scroll parent is given a box inside `_box`.

Here the server box is 800 by 299. The client cache stays 0 by 0. Its layout manager is `BaseAppViewGridLayout`.

### 6. The grid layout allocates the scroll view

`vendor/gnome-shell/js/ui/appDisplay.js`, `BaseAppViewGridLayout.vfunc_allocate`:

```js
this._scrollView.allocate(box);
```

On a normal desktop the scroll view is the size of that box, and its content child is `AppGrid`.

Here the scroll view's server box is 800 by 299. It has two children, the scrollbars from `st_scroll_view_init`. The grid is not one of them.

### 7. The scroll view's content child is rejected

`st_scroll_view_set_child` requires `ST_IS_SCROLLABLE`. The grid's server actor is not. The assertion fails at `08:20:33.701`. `priv->child` stays null, so `st_scroll_view_allocate` never calls `clutter_actor_allocate` on the grid.

Forcing `scrollParent.layout_manager.vfunc_allocate` from the smoke still throws `Could not locate clutter_margin_copy` at `appDisplay.js:164` before `this._scrollView.allocate`. That throw is on the forced call. It is not why the natural path leaves the grid unallocated. `libmutter-clutter-rpc-16.so` exports `clutter_margin_dup`.

### 8. The grid sets its page from the box

`vendor/gnome-shell/js/ui/iconGrid.js`, `IconGrid.vfunc_allocate`:

```js
const [width, height] = box.get_size();
this._findBestModeForSize(width, height);
this.layout_manager.adaptToSize(width, height);
super.vfunc_allocate(box);
```

On a normal desktop the page is the size of the grid's box, and `IconGridLayout.vfunc_allocate` then places the icons.

Here it does not work as expected. Neither `vfunc_allocate` runs. The page stays 0 by 0.

A `St.Viewport` subclass added straight to the stage does run `vfunc_allocate`. The grid's method does not run because the grid was never added to the scroll view and is not mapped. `clutter_actor_allocate` returns before the class allocate in that case.

### 9. Calling that method with the parent box does size the page

The same two lines, invoked by the smoke with the 800 by 315 box:

```js
this._findBestModeForSize(width, height);
this.layout_manager.adaptToSize(width, height);
```

On a normal desktop step 8 is what runs these.

Here it works as expected. The page becomes 800 by 315. `appDisplay._grid.vfunc_allocate` with that same box does the same. Those calls were taken back out. They are not the product path.

**Reproduction** of the failure, with those calls absent:

```bash
GSR_WESTON_SOCKET=wayland-gsr-apppick \
GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-apppick \
GI_META_SMOKE=shell-boot/ui/init GSR_WESTON_PIXMAN=1 \
GSR_NESTED_TIMEOUT=25 ./scripts/agent-nested-smoke-prove.sh
```

Pass is `applications-picker-smoke: ok`. The line is `miss page-size`.

Direct `GI_META_SMOKE=applications-picker-smoke` never reaches the grid. `gsr-smoke` calls `begin_shell_startup` only when the script path ends in `ui/init.js`, so `main.start()` aborts on `ClutterBoxLayout` minimum height `-12` and the client then logs `global.stage.context is null` (`mutter exited ec=133`). The run that reaches the grid is `tests/gjs-embed/shell-boot/ui/init.js`, which imports the smoke after that lock.

## Debug-code cleanup ledger

- `tests/gjs-embed/applications-picker-smoke.js` waits until the Show Applications box is stable, clicks it, and records state, mapping, item count, page size, and pickable icons. The boxes line logs client `allocation` and server `get_allocation_box()` for the app, `_box`, scroll parent, scroll view, and grid, plus expand, align, mapped, and child count. A following line logs preferred size. It does not call `vfunc_allocate`. The `+38,+59` aim is the measured virtual-pointer offset. `/tmp/gsr-apppick-js` is a leftover overlay of `ui/iconGrid.js` with two log lines. It is not in the repo. The 2026-10-21 prove did not set `GI_RPC_JS_OVERRIDE_DIR`.
- `tests/gjs-embed/shell-boot/ui/init.js` only imports that smoke so `gsr-smoke` takes the startup frame lock. No `src/` change.

## LLM efforts

### 2026-10-12 09:39 report created

Created as a separate bug from overview workspace selection and window dragging. No product code or reproduction code has been changed for this failure.

### 2026-10-12 09:41 installed-session logs do not yet name the picker failure

The current hand-test logs were searched for the previously observed `clutter_margin_copy` symbol failure, `IconGridLayout.adaptToSize` allocation failure, and `appDisplay.js` errors; none occurred. The session did contain four `dnd.js` current-event errors and a later unrelated shutdown error after the server socket closed. A clean picker reproduction must identify whether the button changes the overview state, whether the app display maps, and whether icons are pickable without the workarounds in `picker-second-launch.js`.

### 2026-10-18 18:44 existing Weston logs do not name the picker

Read `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` (session `10:33:31`–`18:43:52`, writer `gsr-client` 1167619), `mutter-rpc.debug.log` (writer `gsr-server` 1167587), and `nested-weston-prove.tee.log`. Started by `scripts/weston-gsr-session.sh --debug` on pts/9. No `JS ERROR`. No `clutter_margin_copy`. No `adaptToSize`. No `appDisplay` string. After boot, the client log is quiet until `18:36:34`–`18:43:52` (icon `set_gicon`, label `set_text`, allocate). No `button-press` / `clicked` in that window. End of tee: `Gdk-Message: Lost connection to Wayland compositor` at `18:43:52.276`, then `socket closed`. Boot criticals that remain: fourteen `St-Widget.set_label_actor` replies with empty error and `St_generated.vala:3043` `-32602` at `10:33:35`. `src/` not edited.

### 2026-10-18 18:50 scripted prove died in startup, before the picker

Command: `GI_META_SMOKE=applications-picker-smoke GSR_WESTON_PIXMAN=1 GSR_NESTED_TIMEOUT=90 ./scripts/agent-nested-smoke-prove.sh`

The shell inherited `GSR_NESTED_STAYUP=1` (prove line: `timeout=90s settle=10s stayup=1`). Spawned `gsr-smoke` pid 1183608 at `18:50:17.362`. Did not reach Show Applications. At `18:50:19.318` the server logged `ClutterBoxLayout child unnamed [GsrServerClutterActor] minimum height: -12.000000 < 0 for width 182.000000`. At `18:50:20.086` the client logged `socket closed` during `Clutter-Actor.allocate` id=4932. Then `applications-picker-smoke: miss exception TypeError: global.stage.context is null`. `nested-weston-prove: mutter exited ec=133 after 3s`. That is the known startup abort (`g_error` on a negative minimum, then the client sees a null stage context). It is not the picker. `src/` not edited.

### 2026-10-18 19:03 nine more startup aborts, then the lock

`GSR_WESTON_SOCKET=wayland-gsr-apppick` so this did not share `wayland-gsr` with the other smoke. Three single runs and a loop of six all died the same way: minimum height `-12`, then `applications-picker-smoke: miss exception TypeError: global.stage.context is null`, `mutter exited ec=133` after about 3s. `gsr-smoke` calls `begin_shell_startup` only for a script path ending in `ui/init.js` (`SmokeApplication.vala`). `gsr-client` always calls it.

### 2026-10-18 19:07 and 2026-10-19 08:48 click misses the button

`GI_META_SMOKE=shell-boot/ui/init` (imports the picker smoke) with the startup lock. `startup notice removed`, then `click at=568,560 size=44x80 before=1`. Four seconds later `state=1 checked=false visible=false mapped=false items=0 page=0x0 pickable=0` and `miss state`. The RPC after `pointer_click` is `Clutter-ClickAction.get_button` then `Meta-Workspace.activate`. `workspace.js` leaves the overview when the active workspace is clicked. The button's `get_transformed_position` center is the Show Apps button for `get_actor_at_pos`, and the X event is at `530,501`.

### 2026-10-19 08:53 pick is the button, event is the workspace

Same command. `pick=St_Button.show-apps > ShowAppsIcon.dash-item-container > ... > Dash#dash`. Server log `button press ... x:530.00, y:501.00`. `event()` / `captured_event` for that press run on `WorkspacesDisplay`, not the button. Then `clicked` and `Meta-Workspace.activate`.

### 2026-10-19 09:00 aim +38,+59 opens the grid and the page stays 0

Request `606,619`. X event `x:568.00, y:560.00` on the button. `state=2 checked=true visible=true mapped=true items=147 page=0x0 pickable=7`. `miss page-size`. Client log `09:00:25.626` `JS ERROR: Error: IconGridLayout.adaptToSize wasn't called before allocation` at `iconGrid.js:742` from `overviewControls.js:236` `_appDisplay.allocate`. Stack does not include `iconGrid.js:1251`. `09:00:26.345` `Could not locate clutter_margin_copy` at `appDisplay.js:164` `_updatePadding`. `nm -D build/src/libmutter-clutter-rpc-16.so` has `clutter_margin_dup` and not `clutter_margin_copy`. `src/` not edited.

### 2026-10-19 09:04 smoke-side margin copy was not a clean rerun

Patched `AppGrid._updatePadding` to assign margin fields, and wrapped `IconGrid.vfunc_allocate` to log. The button's reported center moved to `626,545` and the pick there was `overviewGroup`, not the button. `state=1 checked=false` `miss state`. No `grid-vfunc` line, no `clutter_margin_copy`, no `adaptToSize`. The patch was removed. It does not show whether a margin copy fixes the page size.

### 2026-10-19 09:23 prototype allocate did not run

Same Weston command. Replaced `IconGrid.prototype.allocate` so it called `adaptToSize` before the saved method, and replaced `AppGrid._updatePadding` with field copies. Click still `568,560` on `show-apps`. `state=2 ... page=0x0 pickable=7` `miss page-size`. The throw stack is still `iconGrid.js:742` from `overviewControls.js:236`, with no frame in the smoke. The GI `allocate` method is not the prototype property.

### 2026-10-19 09:28 layout prototype did not run

Replaced `IconGridLayout.prototype.vfunc_allocate` and logged arguments on the first call. No `layout-args` line. Same `miss page-size`. The class slot stays the function registered with the class. The replacement was removed.

### 2026-10-19 10:24 through 10:34 smoke-side adaptToSize passes

`10:24:24` called `adaptToSize` on `appDisplay.layout_manager` with `appDisplay.allocation` `800x315`. `miss exception TypeError: appDisplay._findBestModeForSize is not a function`. The grid is `appDisplay._grid`. `10:26:10` the reported button center was `626,545` and the pick was `overviewGroup`, `miss state`, grid box `0x0`. `10:31:34` the click hit `568,560` again, grid allocation `0x0`, `miss page-size`. `10:34:18` `reallocate grid=0x0 parent=800x315`, then `_findBestModeForSize`, `adaptToSize`, and `layout_manager.allocate` on `_grid`. `10:34:23` `page=800x315 pickable=30` `ok`. The smoke calls were removed after that.

### 2026-10-19 10:37 and 10:44 class-slot edit still misses

`Actor.allocate` called the allocate class slot before `allocate_public`. Rebuilt. Both reruns: click `568,560` on `show-apps`, `state=2 ... page=0x0 pickable=7` `miss page-size`. Stack still `iconGrid.js:742` and not `iconGrid.js:1251`. `clutter_margin_copy` still missing. That edit is reverted. `src/` matches HEAD.

### 2026-10-19 10:54 JS vfunc_allocate was not reached

Restored `Actor.override.vala` and rebuilt. Smoke calls `appDisplay._grid.vfunc_allocate(appDisplay.allocation)` after the click. `click at=674,540 size=64x72` and the pick at that point is `St_Button.show-apps`. Aim `712,599`. X event `x:674.00, y:540.00` is delivered to `overviewGroup`, not the button. `vfunc parent=0x0 grid=0x0`. `state=1 checked=false` `miss state`. The grid never opened. `src/` not edited.

### 2026-10-19 11:00 JS vfunc_allocate passes

Same smoke. The click waits until the transformed box is unchanged for two samples. `click at=568,560 size=44x80 stable=2` on `show-apps`. `vfunc parent=800x315 grid=0x0 checked=true`. `state=2 checked=true visible=true mapped=true items=147 page=800x315 pickable=30` `ok`. `src/` not edited.

### 2026-10-19 later src guesses did not run line 1251

Forcing `allocate` onto every actor, and calling `allocate_vfunc` from `relay_allocate`, both left the throw at `iconGrid.js:742`. Neither stack contains `iconGrid.js:1251`. Both edits were reverted. The forced hook also left the button at `0x0` on the retry.

### 2026-10-20 08:36 AppGrid's allocate hook is registered and the page stays 0

`St-Viewport` subclasses take `create_with_overrides` (commit `d17e7a9`). `actor-hooks type=Gjs_ui_appDisplay_AppGrid names=allocate` at `08:35:56`. Click `568,560` on `show-apps`. `08:36:09` `state=2 checked=true visible=true mapped=true items=147 page=0x0 pickable=7` `miss page-size`. No `iconGrid.js:1251` in the client log. The registered hook does not enter the JS method the smoke called. The hook-name log is removed from `create_with_overrides`.

### 2026-10-20 08:44 allocate_vfunc still misses

`relay_allocate` called `this.allocate_vfunc(box)` instead of `vfunc_call_void_pointer`. Rebuilt `libmutter-clutter-rpc-16.so`. Click `568,560` size `44x80` on `show-apps`. `08:44:52` `state=2 checked=true visible=true mapped=true items=147 page=0x0 pickable=7` `miss page-size`. The tee has no `iconGrid.js:742` and no `iconGrid.js:1251`. The relay edit is reverted. `src/` matches HEAD. `Gi.vfunc_offset` (`OLLMchat/libocrpc/Gi.vala`) is the typelib class-struct field offset. GJS writes its trampoline at that same field. The hook's call of that slot is not the JS method the smoke called.

### 2026-10-20 09:14 a Viewport subclass does allocate

Smoke built a `St.Viewport` subclass with `vfunc_allocate`, added it to the stage at 40×40. `09:14:11` `probe allocate 40x40`, `probe hits=1`. The click still ended `page=0x0` `miss page-size`. The probe was removed.

### 2026-10-20 09:47 the grid allocate methods do not run

`GI_RPC_JS_OVERRIDE_DIR=/tmp/gsr-apppick-js` logged at the start of `IconGrid.vfunc_allocate` and `IconGridLayout.vfunc_allocate`. Overlay installed (`js override overlay 1 files`). No `grid-vfunc` and no `layout-vfunc`. `09:48:05` `boxes app=800x315 scroll=0x0 grid=0x0 gridMapped=false`, then `page=0x0` `miss page-size`.

### 2026-10-20 09:52 layout vfunc does not size the scroll view

Same overlay. After the boxes line, the smoke called `appDisplay.layout_manager.vfunc_allocate(appDisplay, appDisplay.allocation)`. `09:52:38` `after-layout scroll=0x0 grid=0x0 page=0x0`, then `miss page-size`. That call is removed from the smoke. The boxes log stays. No RPC ran between the two log lines. `appDisplay.layout_manager` is `Clutter.BinLayout`, not `BaseAppViewGridLayout`.

### 2026-10-20 10:01 the grid layout throws on margin copy

Same overlay. Boxes before the call: `app=800x315 box=0x0 scrollParent=0x0 BaseAppViewGridLayout scroll=0x0 grid=0x0 gridMapped=false`. The smoke then called `scrollParent.layout_manager.vfunc_allocate(scrollParent, appDisplay.allocation)`. `10:01:43` `miss exception GLib.Error g-invoke-error-quark: Could not locate clutter_margin_copy`. That is `AppGrid._updatePadding` via `indicatorsPadding` inside `BaseAppViewGridLayout.vfunc_allocate`, before `_scrollView.allocate`. The call is removed from the smoke.

### 2026-10-20 10:05 paused on the zero child box

Same command, no forced layout call. `10:05:49` `boxes app=800x315 appLayout=Clutter_BinLayout box=0x0 boxVisible=true boxMapped=true scrollParent=0x0 BaseAppViewGridLayout scroll=0x0 scrollVisible=true grid=0x0 gridMapped=false`, then `state=2 ... page=0x0 pickable=7` `miss page-size`. No `grid-vfunc`. `_box` is visible and mapped and still `0x0`. Stopped here. Those sizes are `actor.allocation`, the client cache.

### 2026-10-21 08:20 the cache is 0 and the server box is not

Same command, `GSR_NESTED_TIMEOUT=40`, no `GI_RPC_JS_OVERRIDE_DIR`. `src/` not edited. Click `568,560` on `show-apps`. `08:20:47` `miss page-size`. Server boxes: app `0,194 800x315`, `_box` `0,0 800x315`, scroll parent `0,0 800x299`, scroll `0,0 800x299` with 2 children, grid `Infinity,Infinity -Infinityx-Infinity`, unmapped, 147 children. `mutter-rpc.debug.log` `08:20:33.701` `St-ScrollView.set_child` then `st_scroll_view_set_child: assertion 'child == NULL || ST_IS_SCROLLABLE (child)' failed`, directly after `St-ScrollView.new`. Prove stop is `stop (smoke-fail) after 15s` (script SIGKILL, exit 137). Nested-debug: that stop is the script, not a crash.

### 2026-10-21 08:46 viewport subclass is the peer that gets the box

`src/` product code not edited. Added `tests/call-sync-repro/viewport-scrollable-peer-gate.c` and a `meson.build` executable. `ninja -C build tests/call-sync-repro/viewport-scrollable-peer-gate` then `timeout 20 ./build/tests/call-sync-repro/viewport-scrollable-peer-gate`. Output: `St-CRITICAL` `st_scroll_view_set_child: assertion 'child == NULL || ST_IS_SCROLLABLE (child)' failed`, then `ok widget rejected children=2`, `ok viewport subclass accepted children=3`, `peer hits=1 seen=800x315 alloc=800x315 mapped=1`, `PASS viewport-scrollable-peer-gate`. Headless mutter also logged `GLib-GObject-CRITICAL` `invalid (NULL) pointer instance` around `Lost or failed to acquire name org.gnome.Mutter.ServiceChannel`. The peer line is after those, and the process exited 0. The product change is the proposal above. Not applied.

### 2026-10-21 09:58 exact viewport gets the box, the subclass does not

`src/` product code not edited. Added `tests/gjs-embed/viewport-scroll-child-smoke.js`. Result is in `nested-weston-prove.tee.log`, not the autolaunch log. `09:58:10`: widget `assign=reject child=null children=2` uninitialized box; exact `assign=ok child=set children=3 box=0,0 800x315`; subclass client assign succeeded, server `ST_IS_SCROLLABLE` critical, `child=null children=2` uninitialized box, `hits=0`; `viewport-scroll-child-smoke: done split`. Prove process then exit 137 from the auto-close kill. The seven-file proposal stays unapplied.

### 2026-10-21 10:15 the wide proposal is removed

The wide patch was taken out of the proposal. It widened `LayoutHooks` and `allocate_public`, and it copied preferred size, event, captured-event, and `style_changed`. Those edits are not the page-size fix. The proposal is the `allocate` override on a viewport lease. Not applied.

### 2026-10-21 10:12 the viewport lease does not parent the subclass

Applied `ViewportActor`, `Viewport`, the `St.Viewport` vapi binding, and `create_viewport()`. Rebuilt. `viewport-scroll-child-smoke` tee `10:12:17`: exact `child=set children=3 box=0,0 800x315`. Subclass: `Gsr-St-Viewport.create` and `add_hooks` reply, then `g_atomic_ref_count_dec: assertion 'old_value > 0' failed`, then `St-ScrollView.set_child` error `-32602`. `assign=ok child=null children=2` uninitialized box, `hits=0`, `miss subclass`. `allocate` did not run.

### 2026-10-21 22:31 the refcount critical is the reply variant

gdb on `gsr-smoke`: `g_variant_unref` from `g_value_unset` in `oll_mrpc_response_finalize`, called from `clutter_actor_create_viewport`. `GLib.Value.get_variant()` does not ref. Vala unrefs that result, then the response unsets the same variant. `create_viewport` now uses `dup_variant()`. Rebuilt the client and the server. Tee `22:31:22`: no refcount critical. Exact `child=set children=3 box=0,0 800x315`. Subclass `set_child` id 46 `replied error=` and `-32602`, no `ST_IS_SCROLLABLE` line. `assign=ok child=null children=2 hits=0`, `miss subclass`.

### 2026-10-21 22:43 register_alias lets set_child accept the subclass

`ViewportActor.rpc_register` calls `OLLMrpc.Bin.register_alias("St-Viewport", typeof(ViewportActor))`. Rebuilt `gsr-server`. Tee `22:43:08`: widget `assign=reject`; exact `child=set children=3 box=0,0 800x315`; `subclass vfunc 800x315`; subclass `assign=ok child=set children=3 box=0,0 800x315 hits=1`; `viewport-scroll-child-smoke: ok`. Prove process exit 137 is the script stop after that line.

### 2026-10-21 22:44 the picker did not reach the page line

Same picker command, `GSR_NESTED_TIMEOUT=40`, sockets `wayland-gsr-apppick` / `wayland-mutter-apppick`. Tee: `22:44:53` `click at=568,560` pick `UiActor#uiGroup`, `before=1`. `22:44:54` `retry aim=606,619`. `St-ScrollView.set_child` ids 21097, 21970, and 22125 replied with no error. No `boxes`, no `state=`, no `applications-picker-smoke: ok` or `miss`. Nest killed at `22:45:22`. The fourteen `-32602` lines are `St-Widget.set_label_actor`. Exit 137 is the script stop.

### 2026-10-21 22:47 the picker page is 800 by 299

Same picker command with `GSR_NESTED_TIMEOUT=90`. Tee `22:47:24` click `at=568,560` on `St_Button.show-apps`. `22:47:45` `boxes` grid `server=0,0 800x299` `mapped=true` `children=147`. `state=2 checked=true visible=true mapped=true items=147 page=800x299 pickable=30`. `applications-picker-smoke: ok`. That line is not the visual pass.

### 2026-10-21 22:52 the icons overlap

Same command. Screenshot `~/.cache/gnome-shell-rpc/applications-picker.png`, 800×600. Two rows of large icons share the same space. Labels are one overlapping line. Tee `22:52:45` icons `0@18,218 145x145 | 1@106,218 145x145 | 8@18,271 145x145`. Pitch is 88 by 53. `shot miss TypeError: area is undefined` because `screenshot()` did not return the area; the PNG was written. Smoke still printed `ok`. The smoke now treats that pitch as `miss overlap`.

### 2026-10-21 23:17 icon size 96 is chosen while the icon is 49px tall

Same command. `23:16:08` `bestIcon 96 seen=none page=800x315 cols=8 rows=3 col=0`. `23:16:13` `bestIcon 96 seen=25/49/81/49 page=800x299 cols=8 rows=3 col=12`. `23:17:01` `gridMode cols=8 rows=3 icon=96 col=12 row=12 maxCol=36 maxRow=36 pad=24,18,24,18 item0=120/145/120/145 baseIcon=96`. Icons still `145x145` at an 88 by 53 pitch. `miss overlap`. Calling `_findBestIconSize` again at that point returned 24 and left the first icon at preferred `48/73/81/73`. Eight columns of a 145px icon do not fit a 800 by 299 page once padding and the 12px spacing are included. The 96 choice used the 49px measurement.
