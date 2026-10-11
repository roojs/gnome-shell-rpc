# Menu expander sits on the opened list

**Status:** ⏳ open. No `src/` edit. The power list and the volume list are drawn on the control that opened them. On a normal desktop each list starts underneath that control.

The volume control is the arrow on the volume row. The power control is the shutdown button, which opens the list that contains Log Out. The slider paint is [Volume slider](done/2026-10-08-volume-slider-drawing.md), closed. The menu staying open is [Panel menu closes on the click that opens it](done/2026-10-10-menu-closes-on-open-click.md), closed.

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
GI_META_SMOKE=menu-expander-overlap ./scripts/weston-gsr-prove.sh
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
