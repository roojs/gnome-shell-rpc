# Menu expander sits on the opened list

**Status:** ✅ closed 2026-10-29. User confirmed that the step 6 height-copy change fixes the whole user-visible menu-expander problem. Archived as done.

**Reproduction:**

```bash
GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=menu-expander-overlap/ui/init \
  ./scripts/weston-gsr-prove.sh
```

Last prove, 2026-10-29 09:38, `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`, with only the step 6 proposal applied.

The automated geometry smoke proves the original power-list failure is fixed: the power button top is 57 and its height is 38, while the list top is now 95. Its volume and Keyboard probes do not match the confirmed user-visible result and remain inaccurate test measurements, not open product failures.

```text
menu-expander-overlap/ui/init: quick-settings-system-item ... menuY=38 ... gap=0 high=false
menu-expander-overlap/ui/init: quick-settings-system-item-trial ... gap=0 ... high=false
menu-expander-overlap/ui/init: quick-slider ... menu=392,85 402x1 menuY=28 ... gap=-235.0006103515625 high=true
menu-expander-overlap/ui/init: quick-slider-trial ... menuY=28 ... gap=-235.0006103515625 high=true
menu-expander-overlap/ui/init: Keyboard ... menu=Infinity,Infinity ... gap=Infinity ... high=true
menu-expander-overlap/ui/init: Keyboard-trial ... menu=Infinity,Infinity ... gap=Infinity ... high=true
menu-expander-overlap/ui/init: miss failure=true trial-high=true
```

## Steps

### 1. The expander list is built when the row is created

`vendor/gnome-shell/js/ui/quickSettings.js`, `QuickSettingsItem._init`:

```js
if (this.hasMenu) {
    this.menu = new QuickToggleMenu(this);
    this.menu.actor.hide();
}
```

`ShutdownItem` and `QuickSlider` pass `hasMenu: true`. `SystemItem` then sets `this.menu = shutdownItem.menu`. This runs when the shell creates the quick settings, before the panel is opened.

On a normal desktop the power list, the volume list, and the Keyboard list exist at this point and are hidden.

**Matches.** Opening the system menu does not build them. Clicking the power button or the volume arrow does not build them. Those clicks show the list that was built here.

### 2. That constructor ties the hidden list to the row

`QuickToggleMenu` constructor, called from step 1:

```js
const constraints = new Clutter.BindConstraint({
    coordinate: Clutter.BindCoordinate.Y,
    source: sourceActor,
});
sourceActor.bind_property('height',
    constraints, 'offset',
    GObject.BindingFlags.DEFAULT);
this.actor = new St.Widget({
    height: 0,
    constraints,
});
```

On a normal desktop the hidden list is tied to its row, with height 0, so it can sit under the row once it is shown.

**Matches.** Nothing is on screen. The list is still hidden.

### 3. The hidden list is parented to the overlay

`QuickSettingsMenu._completeAddItem`, when the row is added to the panel:

```js
if (item.menu)
    this._overlay.add_child(item.menu.actor);
```

On a normal desktop the list becomes a child of the overlay and stays hidden.

**Matches.**

### 4. The system menu opens

`QuickSettingsMenu.open` shows the panel. It does not call `QuickToggleMenu.open`.

On a normal desktop the buttons and rows appear. The power list stays hidden.

**Matches.** The smoke opens the panel, then expands a list. The expand is step 5.

### 5. Expanding the row shows the list from step 1

Power button, `vendor/gnome-shell/js/ui/status/system.js`, `ShutdownItem`:

```js
this.connect('clicked', () => this.menu.open());
```

Volume arrow, `QuickSlider`:

```js
this._menuButton.connect('clicked', () => this.menu.open());
```

`QuickToggleMenu.open` starts with `this.actor.show()`.

On a normal desktop the list appears under the control that was clicked.

**Does not match.** The power list covers the power button. The button is 38 pixels tall. Its top is 57 pixels down the screen, and the list top is 57 as well. The list should start at 95, under the button.

The volume list covers the volume row. That row is 28 pixels tall and sits 50 pixels below the top of the menu. The list starts at the top of the menu, on the row.

The Keyboard list covers the Keyboard toggle. That toggle is 48 pixels tall and sits 90 pixels below the top of the menu. The list starts at the top of the menu.

### 6. The height binding copies the row into `offset`

Same call as step 2, `bind_property('height', constraints, 'offset', DEFAULT)`.

On a normal desktop this copies the control's height into `offset`. Power 38. Volume 28. Keyboard 48. That is how far below the control the list starts.

**Does not match.** The copy never happens. `offset` stays 0. The heights can still be read: the power button is 38, the volume row is 28. Nothing writes those numbers into `offset`, so the list is not pushed down. That is step 5.

`src/client/gresource/signals.js`:

```js
GObject.Object.prototype.connect = function (name, ...rest) {
    const id = Signals._orig_connect.call(this, name, ...rest);
    imports.gi.Shell.Signals.connect(this, name, id);
    return id;
};
```

On a normal desktop the binding and the actor are one process, so `notify::height` reaches the binding.

**Does not match.** `bind_property` connects from C. It does not call this wrap, so the server is never subscribed. The height change happens on the server. The binding is in the client and never hears it.

#### Proposal for this step only

✔️ Applied and proved for the power list on 2026-10-29. The remaining volume and Keyboard failures are later steps.

The off-product trial wrote the control's height into `offset` at `open()`. The power list then started under the button. The volume list was still 50 pixels too high. The Keyboard list was still 90 pixels too high. Those two are step 9. This proposal does not add them.

🚫 Do not subscribe `notify::height` on the server. An inbound notify writes the height back and the overlay sticks at 0. That is step 15.

🚫 Do not add the control's Y onto `offset`. That is step 9. The relay that did both was applied and reverted. Steps 16 and 17.

The existing binding already sets `offset` when the source emits `notify::height` in this process. `show()` on the list actor emits that locally. The binding reads the height (power 38, volume 28) and calls step 7. Mutter is not told to set the height.

### 1. `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` — remember the list's Y constraint and poke it on `show()`

**Why:** `QuickToggleMenu.open` starts with `this.actor.show()`. That is step 5. The constraint was stored in step 2. `show()` is the moment the binding has to copy the height.

**Where:** `Actor.show()` and the `constraints` setter.

**Depends on:** proposal 2.

##### Part 1 — keep the constraint

#### Remove
```vala
	public void show()
```

#### Replace with
```vala
	private BindConstraint? priv_bind_constraint;

	public void show()
```

##### Part 2 — copy the source height before the server show

#### Remove
```vala
		if (this.prop_batch_open) {
			Gsr.Client.Clutter.Batch.call_value("Clutter-Actor.show", this, "visible",
				OLLMrpc.args("b", true));
		}
		Gsr.Client.Rpc.call_value("Clutter-Actor.show", this);
```

#### Replace with
```vala
		if (this.prop_batch_open) {
			Gsr.Client.Clutter.Batch.call_value("Clutter-Actor.show", this, "visible",
				OLLMrpc.args("b", true));
		}
		if (this.priv_bind_constraint != null) {
			this.priv_bind_constraint.copy_source_height();
		}
		Gsr.Client.Rpc.call_value("Clutter-Actor.show", this);
```

##### Part 3 — the construct property is the list's constraint

#### Remove
```vala
			if (value != null) {
				this.add_constraint(value);
			}
```

#### Replace with
```vala
			if (value != null) {
				this.add_constraint(value);
				if (value is BindConstraint) {
					this.priv_bind_constraint = (BindConstraint) value;
				}
			}
```

### 2. `src/client/libmutter-clutter-rpc-16/overrides/BindConstraint.override.vala` — local height notify

**Why:** `notify_property("height")` runs the binding already created in step 2. The binding writes `offset`. The `offset` setter already calls `sync_offset`, which is step 7. No extra Y is added.

**Where:** after `priv_offset`.

**Depends on:** nothing.

#### Add
```vala
		internal void copy_source_height()
		{
			if (this.priv_coordinate != BindCoordinate.y || this.priv_source == null) {
				return;
			}
			this.priv_source.notify_property("height");
		}
```

After this, the power list starts under the button. The 2026-10-29 run measured `menuY=38`, `gap=0`, and `high=false` before the smoke trial. Volume stays high, and the empty volume box and missing Keyboard box stay step 13.

### 7. `set_offset` is the write that moves the list

`src/client/libmutter-clutter-rpc-16/overrides/BindConstraint.override.vala`:

```vala
Gsr.Client.Rpc.call_value(
    "Clutter-BindConstraint.set_offset", this,
    OLLMrpc.args("f", (double) this.priv_offset));
```

On a normal desktop step 6 calls this with the control's height, and the list moves down by that many pixels.

**Does not match.** This call does not run. The offset mutter has is 0.

### 8. The constraint places the menu

`clutter_bind_constraint_update_allocation` in `clutter-bind-constraint.c`, Y case:

```c
source_position.y = clutter_actor_get_y (bind->source);
allocation->y1 = source_position.y + bind->offset;
allocation->y2 = allocation->y1 + actor_height;
```

On a normal desktop `y1` is the bottom of the control. The list starts there.

**Does not match.** Both numbers this adds are 0. `offset` is 0 from step 7. `get_y` is 0 from step 9. The list top is set to 0, which is the top of its parent, on the control. That is step 5.

### 9. `get_y` of the row

`clutter_actor_get_y` in `clutter-actor.c`:

```c
if (priv->needs_allocation)
  {
    if (priv->position_set)
      return info->fixed_pos.y;
    else
      return 0;
  }
else
  return priv->allocation.y1;
```

On a normal desktop `needs_allocation` is clear, so this returns the control's real Y inside its parent. The volume row is 50 pixels down. The Keyboard toggle is 90 pixels down. The power button is at 0.

**Does not match.** `needs_allocation` is set, and no fixed position is set, so this returns 0 for all three. The stored box still has the real Y: volume 50, Keyboard 90, power 0. Step 5 adds the 0 from this function, not those stored positions.

### 10. The row allocate does not clear that flag

`QuickSettingsLayout.vfunc_allocate`:

```js
child.allocate(childBox);
```

`src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala`:

```vala
var lm = this.priv_layout_manager;
if (lm != null && lm.rpc_lid == 0) {
    lm.allocate_vfunc(this, box);
    return;
}
```

On a normal desktop `clutter_actor_allocate` stores the box and clears `needs_allocation`. Step 9 then returns the real Y.

**Does not match.** The grid's layout manager is client-owned, so this branch runs and returns before `Clutter-Actor.allocate`. `needs_allocation` stays set. Calling `allocate` again from the smoke did not clear it. The volume list then moved down by the row's 28 pixel height only. The row is 50 pixels down the menu, and that 50 was still missing, so the list still covered the row.

### 11. A height-only offset moves the power list

Smoke trial, not `src/`:

```js
this._yBind.offset = sourceHeight;
```

On a normal desktop step 9 already added the control's Y, so adding the height is the whole correction.

**Does not match** for volume and Keyboard. The power list does move to the bottom of the button, because that button's Y is already 0 and 38 is the whole distance. The volume list moves down 28 pixels and is still 50 pixels too high. The Keyboard list moves down 48 pixels and is still 90 pixels too high.

### 12. Row Y plus height places all three

Smoke trial, not `src/`:

```js
menu.add_constraint(new Clutter.BindConstraint({
    coordinate: Clutter.BindCoordinate.Y,
    source: item,
    offset: relY + item.height,
}));
```

`relY` is the control's Y inside the list's parent. For volume that is 50. For Keyboard that is 90. For power that is 0.

On a normal desktop step 8 already places the list there.

**Matches** when the list has a real height. 2026-10-28 09:57. The power list starts under the button. The volume list starts under the volume row. The Keyboard list starts under the Keyboard toggle. `src/` was not edited.

### 13. `open()` gives the menu a height

This is the rest of `QuickToggleMenu.open` from step 5, after `this.actor.show()`:

```js
const previousHeight = this.actor.height;
this.actor.height = -1;
const [targetHeight] = this.actor.get_preferred_height(-1);
this.actor.height = previousHeight;
this.actor.ease({
    height: targetHeight,
    onComplete: () => {
        this.actor.height = -1;
    },
});
```

On a normal desktop the list grows from nothing to its natural height, then the fixed height is cleared so later layout uses that natural height.

**Does not match.** The volume list is left 402 pixels wide and 0 pixels tall. There is no list to see. One run left it 1 pixel tall. The Keyboard list is never given a box: its position and size come back as infinity, which is Clutter's unset box. On earlier passes its parent, the overlay, was 402 pixels wide and 0 tall.

### 14. A fixed height skips the layout

`clutter_actor_set_height_internal` in `clutter-actor.c`:

```c
if (height >= 0)
  {
    clutter_actor_set_min_height (self, height);
    clutter_actor_set_natural_height (self, height);
  }
else
  {
    clutter_actor_set_min_height_set (self, FALSE);
    clutter_actor_set_natural_height_set (self, FALSE);
  }
```

`clutter_actor_get_preferred_height`:

```c
if (priv->min_height_set && priv->natural_height_set)
  {
    *natural_height_p = info->natural.height + (info->margin.top + info->margin.bottom);
    return;
  }
```

On a normal desktop height `-1` clears those flags and the layout is asked how tall the children are.

**Does not match.** The overlay has been given a fixed height of 0. This function returns 0 and does not ask the layout, so the menu's 222 pixels are ignored. Giving the overlay the box pointer's 402 by 182 still left it 402 wide and 0 tall. Setting the menu actor's height did not change that. Setting the overlay's height to `-1` cleared the fixed height: the preferred height became 222 and the box became 402 by 222.

A product change that sent `-1` for a plain `Clutter.Actor` (`465b480`) then gave all three lists a real height. It was reverted with the other experiments. The screen from that day was still wrong: no icons, a power press that did nothing, a transparent popover. It has not been tried again on its own.

### 15. A server `notify::height` writes the height back

`libocrpc` `Client.vala`, inbound `notify::`:

```vala
this.proxies.get(notif.id).set_property(
    prop_name,
    notif.args.get(0));
```

On a normal desktop `notify::height` only tells listeners. It does not set the height again.

**Does not match.** This writes the notified height back with `set_property`, and the actor setter calls `Clutter-Actor.set_height` on mutter. Mutter keeps that as a fixed height. The overlay was stuck at 0. Subscribing every `bind_property` also looped on the icon name, and the client quit before any list was measured.

### 16. The client Y relay was applied and reverted

It notified height locally and added the control's client Y onto `offset`. The fences are in LLM efforts, 2026-10-28 rejected position relay.

**Does not match.** First run: the power list started 38 pixels too low. The walk added the box pointer's Y on top of the height that was already in the offset. Second run: the power list and the volume list started in the right place, but the volume list was 402 pixels wide and 1 pixel tall, and the Keyboard list still had no box. Reverted. `src/` is the baseline.

### 17. The same offset on the baseline only moves the power list

16:26, after the revert. The stock constraint still does step 5.

**Does not match.** Writing the step 12 offset again fixes only the power list: that list moves from on the button to under it. The volume list stays 402 pixels wide and 0 tall, at the top of the menu, so the new offset has no list to move. The Keyboard list still has no box.

`tests/gjs-embed/menu-expander-placement.js` now logs the list's height, its preferred height, and the control's Y, and sets `height = -1` when the box is empty. That version has not been run.

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

The smoke retains the failing stock constraint, then replaces it with the proven source-position-plus-height trial. Its post-change wait is 800 ms because 300 ms produced one run where the system menu had not reallocated yet. `GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=menu-expander-overlap/ui/init ./scripts/weston-gsr-prove.sh`: system `gap=0`, volume `gap=-0.0006`, Keyboard `gap=-0.0006`, then `menu-expander-overlap/ui/init: ok`. No `src/` edit. The major stock-boundary change is the rejected position relay at the end of this section.

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

### 2026-10-27 the ok smoke was the wrong check

The user sees the power list covering the quick settings menu, and the Show Applications icon jumping when the app picker opens. The earlier `ok` scored the menu container's Y. Those containers were height 0. The smoke never opened the app picker.

The smoke now also records the painted menu box and five dash samples after `overview.showApps()`. `GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=menu-expander-overlap/ui/init ./scripts/weston-gsr-prove.sh`. System painted `content=95+0` against preferred height 222. Volume `content=135+1` against 38. Keyboard `content=195+1` against 72. `high=true unopened=true`. Dash samples stayed `translation=0 showApps=509+91`. `menu-expander-overlap/ui/init: miss overlap`. `stop (smoke-fail) after 14s`. `src/` was not edited in this step.

### 2026-10-27 button open is still an empty box

`open(0)` is `PopupAnimation.NONE`. The power button calls `menu.open()` with no argument. The smoke now does that. Same command. Power `heightProp=0` `content=95+0` preferred 222. Volume `heightProp=1`. Keyboard `heightProp=0`. Dash samples stay `showApps=509+91`. `miss overlap`. `src/` was not edited.

### 2026-10-27 the panel has a box and the overlay does not

Same command, still `menu.open()`. `popup actor=0x0 boxPointer=402x182`. The power list's first row is `item=108+54`. The power button is `button=57+38`, so that row starts 13px below the button. The list container stays `content=95+0`. `miss overlap`. A follow-up that assigned the preferred height onto the menu actor did not reach its log line: Weston segfaulted, exit 139, after the popup line and before any menu measurement. That assignment was taken back out of the smoke. `src/` was not edited.

### 2026-10-27 button open is still an empty box

`open(0)` is `PopupAnimation.NONE`. The power button calls `menu.open()` with no argument. The smoke now does that. Same command. Power `heightProp=0` `content=95+0` preferred 222. Volume `heightProp=1`. Keyboard `heightProp=0`. Dash samples stay `showApps=509+91`. `miss overlap`. `src/` was not edited.

### 2026-10-27 the overlay height request was 0

Same command. `allocate_available_size` on the overlay with the box pointer's 402×182 left the overlay at 402×0. The grid itself was 364×98. Setting the overlay's height to the menu's preferred height made the overlay 402×183, the power list `content=107+171` `gap=12`, and the smoke `ok`. Setting the menu actor's height to that preferred height, or to -1, left the overlay preferred height at 0. `queue_relayout` on the overlay also left it at 0. Setting the overlay's height to -1 made its preferred height 222, the allocation 402×222, and the power list `content=107+210` `gap=12`.

The overlay is a plain `Clutter.Actor` with a `BinLayout`. Its height setter was called with 0. `get_preferred_height` then returns that request and does not ask the layout, so the visible menu's 222 is ignored. `Actor.height` now sends -1 for that actor. An `St.Widget` height of 0 is unchanged.

Same command after that setter landed. Power `content=107+173` `gap=12` `heightProp=185`. Volume `content=147+26` `gap=12` `heightProp=38`. Keyboard `content=206+62` `gap=11` `heightProp=74`. Dash sample 4 `translation=0 showApps=509+91`. `menu-expander-overlap/ui/init: ok`. Exit 137 is the prove killing Weston.

### 2026-10-27 the click picture is a solid list

The user sees four round buttons with no icons, a volume slider with no icon, a power click that does nothing, then a transparent popover that does not move the other rows. The smoke now logs those actors, sends the power button's `clicked` signal, and writes two stage shots. `global.fire_button_press` was tried first. The server logged `invalid cast from 'StButton' to 'GsrServerClutterActor'` and the client disconnected. That call was removed. `emit('clicked')` with no argument threw `Signal 'clicked' requires 1 args got 0`. The call is `emit('clicked', shutdown)`.

Same command at 17:27. Before the click the four buttons are 38×38 with 16×16 glyphs: `screenshooter-symbolic`, `org.gnome.Settings`, `system-lock-screen-symbolic`, `system-shutdown-symbolic`. The volume glyph is `NaNxNaN`. Every `quick-slider` grid child is hidden, including one allocated at `107+28`. `~/.cache/gnome-shell-rpc/menu-expander-panel.png` is an opaque menu (`36363a`, alpha 255) with those four icons and no slider. After the click, `open=true`, the list box background is `a=255 rgb=72,72,75`, `boxOpacity=255`, `overlayNat=222`. The toggles move from `107+48` to `329+48`. `menu-expander-power.png` shows the Power Off list under the buttons and those toggles below the list. Pixels in that list are alpha 255. `menu-expander-overlap/ui/init: ok`. Exit 137 is the prove killing Weston.

### 2026-10-27 the status said the menu was fine

The top said the 17:27 pictures did not show the reported screen. That account was wrong. The menu is failed: four round buttons with no icons, a volume slider with no icon, a power press that does nothing, then a transparent popover with the rows left where they are. The smoke's `ok` stays a log line, not the status.

### 2026-10-28 rollback and fresh failure prove

Inspected commits `20b783a` through `7b49b8e`. The product experiments were the bind-constraint signal subscriptions and server vfunc replacement from `88f1bae`, plus the actor-height special case from `465b480`; the source-only comment added in `20b783a` was rolled back with them. Reverted those eight `src/` paths in the working tree to their state at `8bed1cb`. The reproduction harness and bug record were retained. `git diff --exit-code 8bed1cb -- <eight paths>` passed, and `meson compile -C build` passed.

Ran `GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=menu-expander-overlap/ui/init ./scripts/weston-gsr-prove.sh`. The system list had `gap=-38`, the volume list `gap=-78.00062561035156`, and Keyboard `gap=-138.00062561035156`; all three logged `high=true`, followed by `menu-expander-overlap/ui/init: miss overlap`. The power screenshot shows the list covering the controls at the top of the quick-settings panel. The outer command exited 137 during Weston shutdown after the failure marker. No candidate fix was tried and no `src/` change remains beyond the rollback.

### 2026-10-28 minimized off-product fix

Added `tests/gjs-embed/menu-expander-placement.js` and pointed the existing `menu-expander-overlap/ui/init.js` entry point at it. The minimized smoke retains each failing stock menu long enough to record its position, then changes only the reproduction's constraint.

The first source-position-plus-height run at 08:54 moved system `gap=-38 → 0`, volume `gap=-78.0006 → -0.0006`, and Keyboard `gap=-138.0006 → -0.0006`, and printed `ok`. The stage image `~/.cache/gnome-shell-rpc/menu-expander-trial.png` showed the power list below the controls.

Tested narrower alternatives before proposing product code. `set_allocation` plus a height-only replacement constraint passed once because constructing the new constraint forced allocation. Reusing the existing stock constraint with `set_allocation` and `notify::height` left volume at `gap=-50`; adding immediate `queue_relayout`, or closing and reopening, was not reliable. Those are rejected.

The minimized source-position-plus-height smoke initially exposed infinite boxes when the next menu opened immediately. Added an 800 ms close-to-next-open settle, then reran the same Weston command at 09:57. System moved `-38 → 0`, volume `-78 → 0`, Keyboard `-138 → -1`, and the smoke printed `menu-expander-overlap/ui/init: ok` at 09:58:19. Product `src/` remained at the rollback baseline. The two-file proposal from this pass is at the end of this section. It was applied later the same day and reverted.

### 2026-10-28 proposal review and update

Reviewed the two-file proposal against `vendor/gnome-shell/js/ui/status/system.js`, `quickSettings.js`, the client Clutter overrides, and the `88f1bae` / `465b480` failure logs (`org.gnome.ShellRpc.debug.log:18776`):
1. `ShutdownItem` (the power button) is a child of `SystemItem`'s `St.BoxLayout` (`system.js:291`), and `SystemItem.menu = shutdownItem.menu` (`system.js:294`). Its `QuickToggleMenu` binds `ShutdownItem`'s `height` to the constraint's `offset`, not `SystemItem`'s. Because `SystemItem` allocates its `St.BoxLayout` and `ShutdownItem` on the server, client-side `Actor.allocate` never runs on `ShutdownItem`.
2. Why `88f1bae` failed when it subscribed `notify::height` on the server: whenever `notify::<prop>` arrives from the server, `libocrpc` (`Client.vala:1257-1275`) calls `proxy.set_property(prop_name, value)` on the client stub. On `Clutter.Actor`, the `height` property setter calls `Clutter-Actor.set_height` back on the server (`org.gnome.ShellRpc.debug.log:18776-18777`), which pins the server actor's explicit height request (`height-set = true`) — pinning `_overlay` to `0` when collapsed and locking sizes on any actor whose `notify::height` is subscribed.
3. To handle both `ShutdownItem` and client-allocated rows without subscribing `notify::height` on the server:
   - Keep `notify_property("height")` local-only on the client (which fires `GBinding` without calling `set_property("height")` or `Clutter-Actor.set_height`).
   - In `Actor.allocate`, emit `notify_property("height")` when either `height` or `y1` (with `height > 0`) changes.
   - In `Actor.show()`, when a constrained actor (`QuickToggleMenu.actor`) is shown (`QuickToggleMenu.open()` starts with `this.actor.show()`), call `priv_bind_constraint.refresh_from_source()`, which emits local `this.priv_source.notify_property("height")` (so `GBinding` reads `ShutdownItem.height` from the server) and calls `this.sync_offset()`. No `src/` files were modified.

### 2026-10-29 examination

No new prove. No `src/` edit. The account is `## Steps` at the top. Same runs as the entries above.

### 2026-10-29 step 6 applied

Applied only the active step 6 proposal. `Actor.show()` now asks its retained `BindConstraint` to emit the local source-height notification, and the constraint emits that notification without subscribing to server `notify::height`. No Y-position relay or second fix was applied.

`meson compile -C build` and `git diff --check` passed. Ran:

```sh
GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=menu-expander-overlap/ui/init ./scripts/weston-gsr-prove.sh
```

The outer command exited 137 while stopping Weston, but the smoke evidence in `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log` proves the scoped result. Before the smoke's trial replacement, the power list changed from the baseline `gap=-38`, `menuY=0` to `gap=0`, `menuY=38`, so the first issue is fixed exactly as predicted. Volume remains high (`gap=-235.0006103515625`, `402x1`) and Keyboard remains at an infinite box. Those are the next issue; this run did not attempt to fix them.

### 2026-10-29 closed

User confirmed that the first change fixes the whole user-visible problem. The remaining volume and Keyboard smoke results do not describe the observed UI. Closed and archived as done.

### 2026-10-28 rejected position relay

Inactive. Applied 2026-10-28 and reverted the same day. Steps 11, 12, and 16 are the result. The fences are the edit that ran. The active proposal is under step 6.

#### 1. `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` — emit local height/Y changes, attach the target, and refresh on `show()`

**Why:** The stock `bind_property('height', constraints, 'offset')` is local to the client. It needs a local `notify::height` when `Actor.allocate` changes the client allocation's height or `y1`, and when a constrained submenu actor is shown (`QuickToggleMenu.open()` calls `this.actor.show()`, which covers `ShutdownItem` whose allocation happens inside `SystemItem`'s server-side `St.BoxLayout` rather than client `Actor.allocate`). The `BindConstraint` also needs its constrained actor so it can stop the allocation walk at that actor's parent.

**Where:** `Actor.allocate(ActorBox)`, `Actor.show()`, and the write-only `constraints` property.

**Depends on:** proposal 2.

##### Part 1 — remember whether allocation changed height or y1

#### Remove
```vala
		this.allocation_priv = box;
		if (this.helper_attached) {
```

#### Replace with
```vala
		var height = box.y2 - box.y1;
		var notify_height = this.allocation_priv.y2 - this.allocation_priv.y1 != height
			|| (height > 0 && this.allocation_priv.y1 != box.y1);
		this.allocation_priv = box;
		if (this.helper_attached) {
```

##### Part 2 — notify after each allocation path completes

#### Add
After each allocation call, immediately before that branch returns, and after the final `Clutter-Actor.allocate` call:

```vala
			if (notify_height) {
				this.notify_property("height");
			}
```

##### Part 3 — refresh an attached bind constraint when the constrained actor is shown

#### Remove
```vala
	public void show()
	{
		this.actor_visible = true;
		if (this.prop_batch_open) {
			Gsr.Client.Clutter.Batch.call_value("Clutter-Actor.show", this, "visible",
				OLLMrpc.args("b", true));
		}
		Gsr.Client.Rpc.call_value("Clutter-Actor.show", this);
	}
```

#### Replace with
```vala
	private BindConstraint? priv_bind_constraint;

	public void show()
	{
		this.actor_visible = true;
		if (this.prop_batch_open) {
			Gsr.Client.Clutter.Batch.call_value("Clutter-Actor.show", this, "visible",
				OLLMrpc.args("b", true));
		}
		if (this.priv_bind_constraint != null) {
			this.priv_bind_constraint.refresh_from_source();
		}
		Gsr.Client.Rpc.call_value("Clutter-Actor.show", this);
	}
```

##### Part 4 — give a bind constraint its constrained actor

#### Remove
```vala
			if (value != null) {
				this.add_constraint(value);
			}
```

#### Replace with
```vala
			if (value != null) {
				this.add_constraint(value);
				if (value is BindConstraint) {
					this.priv_bind_constraint = (BindConstraint) value;
					((BindConstraint) value).attach(this);
				}
			}
```

#### 2. `src/client/libmutter-clutter-rpc-16/overrides/BindConstraint.override.vala` — include missing client Y and refresh locally from source

**Why:** The minimized smoke proves `relative source Y + source height`; height alone leaves volume 50 pixels and Keyboard 90 pixels high. `refresh_from_source()` emits a local-only `notify::height` on `priv_source` (triggering the C `GBinding` to read `source.height` from the server without subscribing server `notify::height`) and calls `sync_offset()`. `sync_offset()` computes the effective offset only for a Y bind whose server-facing source Y is zero. Other coordinates and already-positioned peers retain stock behavior.

**Where:** private fields, `attach()`, `refresh_from_source()`, and `sync_offset()`.

**Depends on:** proposal 1.

##### Part 1 — retain the constrained actor and refresh from source

#### Add
After `priv_offset`:

```vala
		private Actor? priv_actor;

		internal void attach(Actor actor)
		{
			this.priv_actor = actor;
			this.sync_offset();
		}

		internal void refresh_from_source()
		{
			if (this.priv_coordinate == BindCoordinate.y && this.priv_source != null) {
				this.priv_source.notify_property("height");
				this.sync_offset();
			}
		}
```

##### Part 2 — send the client-relative effective offset

#### Remove
```vala
			Gsr.Client.Rpc.call_value(
				"Clutter-BindConstraint.set_offset", this,
				OLLMrpc.args("f", (double) this.priv_offset));
```

#### Replace with
```vala
			var offset = this.priv_offset;
			if (this.priv_coordinate == BindCoordinate.y && this.priv_source != null && this.priv_actor != null && this.priv_source.y == 0) {
				if (this.priv_actor.get_parent() != null) {
					var current = this.priv_source;
					while (current != null && current != this.priv_actor.get_parent()) {
						offset += current.allocation.y1;
						current = current.get_parent();
					}
				}
			}
			Gsr.Client.Rpc.call_value(
				"Clutter-BindConstraint.set_offset", this,
				OLLMrpc.args("f", (double) offset));
```

### 2026-10-27 rejected allocation proposal

Inactive. This sat above the effort log, after the position relay. It is the earlier `allocate_public` attempt.

The replaced client-owned layout-manager shortcut came from commit `b5f0a319` and [`2026-09-15-gjs-layoutmanager-null-allocate.md`](2026-09-15-gjs-layoutmanager-null-allocate.md). Its gate is `layout-allocate-smoke`. The helper `allocate_public` branch came from commit `81fffd57` and [`2026-09-16-allocate-follow-reference.md`](2026-09-16-allocate-follow-reference.md). Its gates are `workspace-dot-align-smoke` and `startup-allocate-smoke` F. `constraint-allocate-smoke` covers public allocation updating constraints.

The proposed broad `allocate_public` path plus the `notify::height` subscription compiled. The historical gates did not regress:

- `layout-allocate-smoke`: GJS layout manager step 2 hit once; subclass step 3 hit; all allocate calls returned. Its deliberate step 4 clear still emits the expected `CLUTTER_IS_LAYOUT_MANAGER` criticals.
- `workspace-dot-align-smoke`: A, B, and C PASS.
- `startup-allocate-smoke`: A resolved; E PASS; F PASS with `hits=1`. B and C remain the smoke's known diagnostic failures.
- `constraint-allocate-smoke`: PASS with two `vfunc_update_allocation` hits.

It did not fix this bug. On the real menu smoke, the height subscription moved the system menu to `menuY=38`, but volume remained `source.y=0`, `menuY=28`, `gap=-50.0006`; Keyboard remained `source.y=0`, `menuY=48`, `gap=-90.0006`. Broadening `allocate_public` therefore does not establish the missing Y for these actors. All three `src/` experiments were reverted. The only complete off-product pass remains the smoke constraint whose offset is source Y relative to the overlay plus source height. That pass is step 12.

