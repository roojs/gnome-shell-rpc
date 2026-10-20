# Applications picker does not work

**Status:** ⏳ open. Paused 2026-10-20 10:06. Show Applications opens the grid. The page stays 0 by 0. `src/` matches HEAD. No product fix is proven.

**Cause:** `ControlsManagerLayout` gives `AppDisplay` a box of 800 by 315. `AppDisplay`'s `Clutter.BinLayout` leaves its child `_box` at 0 by 0. `_box` is visible and mapped. The scroll parent, the scroll view, and the grid stay 0 by 0. The grid stays unmapped. `IconGrid.vfunc_allocate` and `IconGridLayout.vfunc_allocate` do not run, so the page size stays 0.

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

Here it does not work as expected. `_box` stays 0 by 0. It is visible and mapped.

### 5. BoxLayout gives `_box` to the scroll parent

`_box` holds the scroll parent. `allocate_box_child` in `clutter-box-layout.c`:

```c
clutter_actor_allocate (child, child_box);
```

On a normal desktop the scroll parent is given a box inside `_box`.

Here it does not work as expected. The scroll parent stays 0 by 0. Its layout manager is `BaseAppViewGridLayout`.

### 6. The grid layout allocates the scroll view

`vendor/gnome-shell/js/ui/appDisplay.js`, `BaseAppViewGridLayout.vfunc_allocate`:

```js
this._scrollView.allocate(box);
```

On a normal desktop the scroll view is the size of that box. Its child is `AppGrid`.

Here it does not work as expected. This line does not run. The scroll view stays 0 by 0 and visible. The grid stays 0 by 0 and unmapped.

### 7. Page padding is copied before that allocate

The same `vfunc_allocate` sets `indicatorsPadding` first. `AppGrid._updatePadding`:

```js
const padding = this._indicatorsPadding.copy();
```

On a normal desktop this returns the margin, then step 6 allocates the scroll view.

Here it does not work as expected. The natural path does not reach this line. Forcing `scrollParent.layout_manager.vfunc_allocate` throws `Could not locate clutter_margin_copy` at `appDisplay.js:164`, before `this._scrollView.allocate`. `libmutter-clutter-rpc-16.so` exports `clutter_margin_dup`.

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

A `St.Viewport` subclass added straight to the stage does run `vfunc_allocate`. The grid's method is not called because the actors above it have no box.

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

- `tests/gjs-embed/applications-picker-smoke.js` waits until the Show Applications box is stable, clicks it, and records state, mapping, item count, page size, and pickable icons. It also logs the app / `_box` / scroll-parent / scroll / grid boxes. It does not call `vfunc_allocate`. The `+38,+59` aim is the measured virtual-pointer offset. `/tmp/gsr-apppick-js` is a leftover overlay of `ui/iconGrid.js` with two log lines. It is not in the repo. The last prove passed `GI_RPC_JS_OVERRIDE_DIR=/tmp/gsr-apppick-js`. A resume run without that variable is the clean reproduction.
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

Same command, no forced layout call. `10:05:49` `boxes app=800x315 appLayout=Clutter_BinLayout box=0x0 boxVisible=true boxMapped=true scrollParent=0x0 BaseAppViewGridLayout scroll=0x0 scrollVisible=true grid=0x0 gridMapped=false`, then `state=2 ... page=0x0 pickable=7` `miss page-size`. No `grid-vfunc`. `_box` is visible and mapped and still `0x0`. Stopped here.
