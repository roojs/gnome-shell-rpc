# Menu expander sits on the opened list

**Status:** The three visible lists sit under their controls. The stock `QuickToggleMenu` constraint is what the smoke scores. `allocate_public` stays out: it does not restore source Y.

`Clutter.BindConstraint` places the list at `source.y + offset`. `clutter_actor_get_y` returns 0 while `needs_allocation` is set, so the volume row and the Keyboard toggle were read as y 0. The stored transform into the menu's parent still has that y. `Clutter.BindConstraint` is sealed, so `gsr_bind_constraint_install` in `src/server/libmutter-clutter-16/bind-constraint-place.c` only replaces the class vfunc and calls the stock allocation. `Constraint.gsr_bind_constraint_place` then adds that transform when `get_x` or `get_y` is 0, for a position bind only. It writes the same `Clutter.ActorBox` the vfunc received. The shell copies the control's height into `offset` with `bind_property('height', constraints, 'offset')`. That binding connects in C. The client `BindConstraint` subscribes `notify::height` on its source so the binding runs. `signals.js` does not know about this binding.

**Reproduction:**

```bash
GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=menu-expander-overlap/ui/init \
  ./scripts/weston-gsr-prove.sh
```

2026-10-27 15:56, `~/.cache/gnome-shell-rpc/nested-weston-prove.tee.log`. `weston-autolaunch-prove.log` ends `stop (smoke-ok) after 13s`.

```text
menu-expander-overlap/ui/init: quick-settings-system-item relative=19,0 y=0
menu-expander-overlap/ui/init: quick-settings-system-item ... gap=0 height=38 menuY=38 high=false
menu-expander-overlap/ui/init: quick-slider relative=19,50 y=0
menu-expander-overlap/ui/init: quick-slider ... gap=-0.0006 height=28 menuY=78 high=false
menu-expander-overlap/ui/init: Keyboard relative=207,50 y=0
menu-expander-overlap/ui/init: Keyboard ... gap=0 height=48 menuY=98 high=false
menu-expander-overlap/ui/init: ok
```

## Rejected allocation proposal

The replaced client-owned layout-manager shortcut came from commit `b5f0a319` and [`2026-09-15-gjs-layoutmanager-null-allocate.md`](done/2026-09-15-gjs-layoutmanager-null-allocate.md). Its gate is `layout-allocate-smoke`. The helper `allocate_public` branch came from commit `81fffd57` and [`2026-09-16-allocate-follow-reference.md`](done/2026-09-16-allocate-follow-reference.md). Its gates are `workspace-dot-align-smoke` and `startup-allocate-smoke` F. `constraint-allocate-smoke` covers public allocation updating constraints.

The proposed broad `allocate_public` path plus the `notify::height` subscription compiled. The historical gates did not regress:

- `layout-allocate-smoke`: GJS layout manager step 2 hit once; subclass step 3 hit; all allocate calls returned. Its deliberate step 4 clear still emits the expected `CLUTTER_IS_LAYOUT_MANAGER` criticals.
- `workspace-dot-align-smoke`: A, B, and C PASS.
- `startup-allocate-smoke`: A resolved; E PASS; F PASS with `hits=1`. B and C remain the smoke's known diagnostic failures.
- `constraint-allocate-smoke`: PASS with two `vfunc_update_allocation` hits.

It did not fix this bug. On the real menu smoke, the height subscription moved the system menu to `menuY=38`, but volume remained `source.y=0`, `menuY=28`, `gap=-50.0006`; Keyboard remained `source.y=0`, `menuY=48`, `gap=-90.0006`. Broadening `allocate_public` therefore does not establish the missing Y for these actors. All three `src/` experiments were reverted. The only complete off-product pass remains the smoke constraint whose offset is source Y relative to the overlay plus source height.

## Steps

### 1. The system menu opens

On a normal desktop the system menu opens from the top bar.

Here it works as expected. The smoke opens it before it expands either list.

### 2. The power list sits under the power button

On a normal desktop the power button stays where it is, and the list (Suspend, Restart, Power Off, Log Out) starts at the bottom of that button.

Here it does not. At 10:23 the button is 38 pixels tall and its top is 57 pixels down the screen. The list is 222 pixels tall and its top is also 57 pixels down. The list covers the button. It should start at 95, which is the bottom of the button.

### 3. The volume list sits under the volume row

On a normal desktop the volume arrow stays on the volume row, and the output list starts at the bottom of that row.

Here the list is 148 pixels tall and its top is 57 pixels down, the same line as the row. Inside its parent the list starts at the parent's top, not one row lower. The volume row's own box could not be read: the allocation came back as infinity. The row's parent is a real box, and it lines up with the list.

### 4. The shell pushes the list down by the control's height

`vendor/gnome-shell/js/ui/quickSettings.js`, `QuickToggleMenu`:

```js
const constraints = new Clutter.BindConstraint({
    coordinate: Clutter.BindCoordinate.Y,
    source: sourceActor,
});
sourceActor.bind_property('height',
    constraints, 'offset',
    GObject.BindingFlags.DEFAULT);
```

The constraint pins the list's vertical position to the control. `offset` is how many pixels further down the list starts. The binding copies the control's height into `offset` whenever that height changes. On a normal desktop the list then starts just below the control.

Here the binding never runs, so `offset` stays 0. The list is not pushed down. That is step 2 and step 3.

The height can still be read. Asking the power button for its height returns 38. Asking the volume row returns 28. Nothing copies those numbers into `offset` until the trial in step 5.

The copy, when it does run, is the client setter in `src/client/libmutter-clutter-rpc-16/overrides/BindConstraint.override.vala`. It sends `Clutter-BindConstraint.set_offset` to the real constraint in mutter.

### 5. Writing the height in when the menu opens does push the list down

A temporary copy of `quickSettings.js` under `/tmp/gsr-menu-override` set `offset` from the control's height at the start of `open`. Not the vendor tree. Not `src/`.

```js
const sourceHeight = this.sourceActor.height;
if (Number.isFinite(sourceHeight) && sourceHeight > 0)
    this._yBind.offset = sourceHeight;
```

Here that works. Volume height 28, and the list then started 28 pixels down inside its parent. Power height 38, and the list top moved from 57 to 95. That is the bottom of the 38 pixel button. The smoke printed `menu-expander-overlap: ok`.

**Reproduction** of the failure, after that trial was taken off:

```bash
GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=menu-expander-overlap/ui/init \
  ./scripts/weston-gsr-prove.sh
```

2026-10-11 10:23, `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`:

```text
menu-expander-overlap: power source=737,57 38x38 menu=392,57 402x222 gap=-38
menu-expander-overlap: miss overlap
nested-weston-prove: stop (smoke-fail) after 19s
```

`gap=-38` is the list starting 38 pixels too high: on the button, not under it. `alan@192.168.88.197` did not answer, so this Weston run is the session.

## LLM efforts

### 2026-10-10

Filed from the user report. No log read. No reproduction. No `src/` edit.

### 2026-10-11 morning

`ssh` to `alan@192.168.88.197` timed out. The Weston prove log on this machine ended at 08:44 with `stop (smoke-ok)`, a different smoke. The client log had no line about the power button or the volume arrow.

### 2026-10-11 09:43 first smoke

`GI_META_SMOKE=menu-expander-overlap`. Positions came back as NaN for one side of each pair, and the check treated NaN as "not overlapping", so it printed `ok`. That was not a pass. Listing an actor's constraints also failed: `clutter_actor_get_constraints` is not in `libmutter-clutter-rpc-16.so`.

### 2026-10-11 09:54 boxes

The same smoke walked each actor's allocation up to the screen. The power button was 38 by 38 at y 57. The list was at the same y, and that run gave the list no height. The volume list started at the top of its parent. The nest was stopped by the 35 second timeout while the smoke was still holding the picture.

### 2026-10-11 09:58 the open() trial

The `/tmp` override in step 5. Volume offset 28, list moved down 28. Power offset 38, list top 95, `gap=0`. `menu-expander-overlap: ok`. `stop (smoke-ok) after 18s`.

### 2026-10-11 10:10 telling every constraint about allocation

Tried to make the existing height binding fire, instead of setting `offset` by hand. Every bind constraint subscribed its source to `notify::allocation`, and the allocation setter emitted `notify::height`. Boot did not finish. From 10:09:43 the log is `value location for 'gboolean' passed as NULL`. At the 35 second kill the smoke threw `settings is null` on empty boxes. That subscribe was reverted.

### 2026-10-11 10:19 same idea, no re-emit

The allocation notice was delivered with `add_signals` only, without re-emitting the signal. The shell came up. The volume list stayed at y 57. The power list's box came back as infinity. The smoke printed `ok` only because a broken box was not counted as overlap. Reverted. `src/` is back to what it was before that trial.

### 2026-10-11 10:23 after the revert

The smoke in the reproduction block. Power list 222 pixels tall, starting on the 38 pixel button. `miss overlap`. `stop (smoke-fail) after 19s`.

### 2026-10-26 15:20 logs already on disk

`~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log` ends at 14:58 with `g_signal_handler_disconnect` criticals. `nested-weston-prove.tee.log` is from 15:20. Neither file contains `menu-expander-overlap`. No new prove of this failure. `src/` was not edited.

`QuickToggleMenu` is the only collapsible submenu. Callers with `hasMenu: true`: the volume row and the brightness row (`QuickSlider`), the shutdown button (`ShutdownItem`), background apps (`BackgroundAppsToggle`), and `QuickMenuToggle`. The volume arrow and the shutdown button are the two that are on screen in the system menu. The list is pushed down only by `sourceActor.bind_property('height', constraints, 'offset')`. That call is `GObject.bind_property`, which connects in C. The JS `connect` wrap in `src/client/gresource/signals.js` is what subscribes `notify::` on the server. This binding never goes through that wrap, so a later server `notify::height` is not delivered to the client binding, and `offset` stays 0. Not yet re-proven on Weston.

### 2026-10-26 15:28 direct smoke

`GI_META_SMOKE=menu-expander-overlap ./scripts/weston-gsr-prove.sh`. The script path does not end in `ui/init.js`, so `begin_shell_startup` does not run. Mutter logs `ClutterBoxLayout child unnamed [GsrServerClutterActor] minimum height: -12.000000 < 0 for width 182.000000`, the client socket closes during `Clutter-Actor.allocate`, and the smoke logs `miss start TypeError: global.stage.context is null`. That is the empty-grid abort, before either list is measured. `src/` not edited.

### 2026-10-26 15:31 boot through ui/init.js

`GI_META_SMOKE=menu-expander-overlap/ui/init`. The shell stays up. Visible submenus: `quick-settings-system-item`, one `quick-slider` (`menuEnabled` false until the smoke turns it on), and `Keyboard`. Brightness hidden. Power list `gap=-38`, `menuY=0`. Volume source box was infinity on that first open. `miss overlap`.

### 2026-10-26 15:34 all three lists

Same command. System row `411,57 364x38`, list `392,57`, `gap=-38`, `menuY=0`. Volume slider `411,107 364x28`, list still `392,57`, `gap=-78`, `menuY=0`. Keyboard `599,147 176x48`, list `392,57`, `gap=-138`, `menuY=0`. `miss overlap`.

### 2026-10-26 15:38 offset trial

The smoke cleared each list's constraints and added a new Y bind whose `offset` was the control's height. System row `menuY=38`, `gap=0`. Volume `menuY=28`, `gap=-50` (still short by the row's 50). Keyboard `menuY=48`, `gap=-90` (still short by the toggle's 90). The list moves by `offset` and no further. `src/` not edited.

### 2026-10-26 15:45 `.y` against the allocation

Same command. Volume `relative=19,50 y=0` with allocation y 50. Keyboard `relative=207,90 y=0` with allocation y 90. System row `y=0` and allocation y 0. Mutter 48 `clutter_bind_constraint_update_allocation` sets the list to `clutter_actor_get_y(source) + offset`. `clutter_actor_get_y` returns 0 while `needs_allocation` is set. The volume trial again: `menuY=28`, `gap=-50`. Keyboard's list box came back with height 0 on this pass; the 15:38 pass is the one that moved it to `menuY=48`. `miss overlap`. `src/` not edited.

### 2026-10-27 user reconfirmed and Weston reproduced

The user identified the visible affected controls as the volume expander and the power expander containing Log Out; the existing smoke also finds the visible Keyboard expander.

`GI_META_SMOKE=menu-expander-overlap/ui/init ./scripts/weston-gsr-prove.sh`. System list: source y 57, menu y 57, `gap=-38`, `high=true`. Volume list: source y 292, menu y 57, `gap=-263`, `high=true`. The smoke printed `miss overlap`. Its old height-only trial still left both lists high. Keyboard's menu allocation was infinite on this pass. The outer command ended with exit 137 while shutting down Weston instead of recording the usual stop line. `src/` was not edited.

### 2026-10-27 source position plus height trial

Changed only the smoke's replacement constraint: its offset is now the source's Y relative to the menu actor's parent plus the source height. The same run first reproduced the system overlap (`gap=-38`), then the trial moved it to `gap=0`. It reproduced the volume overlap (`gap=-263.0006`), then moved it to `gap=-0.0006`. The Keyboard overlap was `gap=-323.0006`; the outer command's five-minute kill closed the RPC socket before that trial could be measured, so this is not yet a pass. `src/` was not edited.

Reran the same command in the foreground. System moved from `gap=-38` to `gap=0`, volume from `gap=-263.0006` to `gap=-0.0006`, and Keyboard from `gap=-323.0006` to `gap=-0.0006`. The smoke printed `ok`. This proves the full required offset is the source's position in the overlay plus its height; height alone is insufficient while the peer reports every source `.y` as zero.

### 2026-10-27 replaying `Actor.allocate` does not clear the source

Changed the smoke trial to call `row.item.allocate(row.item.get_allocation_box())`, then install a normal bind constraint with only the source height as offset. `GI_META_SMOKE=menu-expander-overlap/ui/init ./scripts/weston-gsr-prove.sh`: system passed because its source Y is zero; volume remained `y=0`, `menuY=28`, `gap=-50.0006`, and the smoke printed `miss overlap=true trial-high=true`. The stub's client-owned layout-manager shortcut runs its `allocate_vfunc` directly and does not enter public `clutter_actor_allocate` on the source peer, so replaying the current stub call cannot clear the peer's `needs_allocation`. `src/` was not edited.

### 2026-10-27 `allocate_preferred_size` trial

Replaced the replay with the stock `Actor.allocate_preferred_size(sourceBox.x1, sourceBox.y1)` and retained the height-only constraint. The peer still reported `.y=0`; volume remained high (`menuY=28`, `gap=-235.0006` after the other menus changed the grid height). This method does not establish the missing parent-assigned allocation boundary for these RPC actors. The passing source-position-plus-height trial was restored. `src/` was not edited.

### 2026-10-27 final off-product pass

The smoke retains the failing stock constraint, then replaces it with the proven source-position-plus-height trial. Its post-change wait is 800 ms because 300 ms produced one run where the system menu had not reallocated yet. `GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=menu-expander-overlap/ui/init ./scripts/weston-gsr-prove.sh`: system `gap=0`, volume `gap=-0.0006`, Keyboard `gap=-0.0006`, then `menu-expander-overlap/ui/init: ok`. No `src/` edit. The major stock-boundary change is proposed above for review.

### 2026-10-27 stock constraint uses the stored Y plus the height binding

`allocate_public` stays reverted. The server bind constraint, for a position bind only, reads the source through `clutter_actor_apply_relative_transform_to_point` into the list's parent when `get_x` or `get_y` is 0. `signals.js` subscribes `notify::height` when `bind_property` copies `height` onto `offset`.

The first build subscribed every `bind_property`. Boot reached a `notify::icon-name` / `St-Icon.set_icon_name` loop and the client exited at 14:49:41, before any list was measured. `stop` was the 50s wall, exit 124. That subscribe was narrowed to height-onto-offset.

Same command again. System `y=0` `menuY=38` `gap=0`. Volume `y=0` `relative y=50` `menuY=78` `gap=-0.0006`. Keyboard `y=0` `relative y=90` `menuY=138` `gap=-0.0006`. The smoke printed `ok`. `stop (smoke-ok) after 16s`. The shell's own constraint was left in place.

### 2026-10-27 height subscribe leaves signals.js

A height-to-offset filter in `signals.js` is not a general connect wrap. Subscribing every `bind_property` looped `notify::icon-name`. The filter came out. The client `BindConstraint` subscribes `notify::height` on its source instead, which is the actor the shell binds onto `offset`.

`Clutter.BindConstraint` is sealed, so a Vala subclass does not compile (`cannot inherit from sealed class`). The position fix stays `gsr_bind_constraint_install`.

Same command. System `gap=0` `menuY=38`. Volume `gap=-0.0006` `menuY=78`. Keyboard `gap=0` `menuY=98`. `menu-expander-overlap/ui/init: ok`. `stop (smoke-ok) after 13s`.

### 2026-10-27 stock vfunc writes the box

The position fix was a copy of mutter's allocation switch. `Clutter.BindConstraint` is sealed, so that body cannot move to a Vala override. `gsr_bind_constraint_update_allocation` now calls the saved stock vfunc and adds the stored parent position when `get_x` or `get_y` is 0, for X, Y, position, and all only.

Same command. System `gap=0` `menuY=38`. Volume `gap=-0.0006` `menuY=78`. Keyboard `gap=0` `menuY=98`. `menu-expander-overlap/ui/init: ok`. `stop (smoke-ok) after 13s`.

### 2026-10-27 placement is Vala

`bind-constraint-place.c` now only installs the class vfunc and calls the stock function. `Constraint.gsr_bind_constraint_place` receives that same `Clutter.ActorBox` by reference and adds the stored parent position. A second struct is not required. The mutter vapi's `apply_relative_transform_to_point` returns a `Vertex`; the call uses the mutter 16 out-parameter form.

Same command. System `gap=0` `menuY=38`. Volume `gap=-0.0006` `menuY=78`. Keyboard `gap=0` `menuY=98`. `menu-expander-overlap/ui/init: ok`. `stop (smoke-ok) after 13s`.
