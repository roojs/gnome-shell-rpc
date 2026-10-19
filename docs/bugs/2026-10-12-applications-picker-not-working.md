# Applications picker does not work

**Status:** ⏳ open. Show Applications opens the app grid. Without a call to the grid's JS `vfunc_allocate`, the page size stays 0. `11:00:30` Weston, smoke only: after the click, `grid.vfunc_allocate(appDisplay.allocation)` with that box at `800x315` and the grid's own allocation `0x0`. Result `page=800x315 pickable=30` then `ok`. `src/` matches HEAD.

## Diagnosis still true

`09:00:31` Weston, after the click lands on `St.Button.show-apps`:

`applications-picker-smoke: state=2 checked=true visible=true mapped=true items=147 page=0x0 pickable=7`

`applications-picker-smoke: miss page-size`

`IconGrid.vfunc_allocate` (`iconGrid.js:1251`, the `adaptToSize` call) is not in the stack. `overviewControls.js:236` calls `_appDisplay.allocate`, and the layout manager throws at `iconGrid.js:742`: `IconGridLayout.adaptToSize wasn't called before allocation`. Same second, `AppGrid._updatePadding` (`appDisplay.js:164`) throws `Could not locate clutter_margin_copy` against `libmutter-clutter-rpc-16.so`. That library exports `clutter_margin_dup`, `clutter_margin_new`, `clutter_margin_free`, and `clutter_margin_get_type`. It does not export `clutter_margin_copy`. `ActorBox.copy` already exists because Vala emits `dup` and GJS looks up `copy`.

Direct `GI_META_SMOKE=applications-picker-smoke` never reaches this. `gsr-smoke` calls `begin_shell_startup` only when the script path ends in `ui/init.js`, so `main.start()` aborts on `ClutterBoxLayout` minimum height `-12` and the client then logs `global.stage.context is null` (`mutter exited ec=133`). The run that reaches the grid is `tests/gjs-embed/shell-boot/ui/init.js`, which imports the smoke after that lock.

A request of stage point `568,560` is delivered as an X button press at `530,501` (workspace, not the button). A request of `606,619` is delivered at `568,560` and hits the button. The smoke aims `+38,+59` for that.

## Reproduction

```bash
GSR_WESTON_SOCKET=wayland-gsr-apppick \
GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-apppick \
GI_META_SMOKE=shell-boot/ui/init GSR_WESTON_PIXMAN=1 \
GSR_NESTED_TIMEOUT=25 ./scripts/agent-nested-smoke-prove.sh
```

Pass would be `applications-picker-smoke: ok`. Without a smoke-side `adaptToSize`, the line is `miss page-size`.

`10:34:23` Weston, smoke only: after the click, `appDisplay.allocation` was `800x315` and `appDisplay._grid.allocation` was `0x0`. The smoke called `_findBestModeForSize`, `adaptToSize(800, 315)`, then `layout_manager.allocate` on the grid. Result: `state=2 checked=true visible=true mapped=true items=147 page=800x315 pickable=30` then `ok`. `11:00:26` calls `appDisplay._grid.vfunc_allocate` with that same parent box instead. `11:00:30` is the same `ok` line. The button is clicked only after its transformed box has stayed the same for two samples. At `11:00:12` that box was `568,560` size `44x80`. Replacing `IconGrid.prototype.allocate` and `IconGridLayout.prototype.vfunc_allocate` did not run; the throw stayed at `iconGrid.js:742`.

## Debug-code cleanup ledger

- `tests/gjs-embed/applications-picker-smoke.js` clicks Show Applications and records state, mapping, item count, page size, and pickable icons. After the click it calls `appDisplay._grid.vfunc_allocate` with `appDisplay.allocation` when that box is non-zero. The `+38,+59` aim is the measured virtual-pointer offset, not a product change.
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
