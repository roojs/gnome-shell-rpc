# Startup paints the overview, then the desktop, then the overview

**Status:** ⏳ open. User 2026-10-29. Split from the closed picker-button ticket [`done/2026-09-30-overview-boot-flicker.md`](done/2026-09-30-overview-boot-flicker.md).

**Plan:** [`../plans/1.0-run-to-end.md`](../plans/1.0-run-to-end.md) row 0.1.

## Seen

On our startup the picture is an overview, then the desktop, then an overview again. The session is supposed to finish on the overview. The overview that appears before the desktop is the complaint.

That first overview is step 3. The desktop after it is step 4. A normal desktop does those writes in one turn and paints neither of them. The first picture it paints of the overview is the fade in step 5, which is also the last picture. A stock session on this machine has not been watched. User 2026-10-29: not sure the normal client does the same. The comparison is the stock JS in one process.

## Steps

`vendor/gnome-shell` (same text as GNOME Shell 48). A stock session on this machine has not been watched. "On a normal desktop" below is that JS in one process: the writes in one step share a turn, and the stage paints when the turn returns. Our client does each write as its own RPC. The server frame clock can paint after a call returns, before the next one is sent.

### 1. The overview group is created hidden

`layout.js`, `LayoutManager` construct:

```js
this.overviewGroup = new St.Widget({
    name: 'overviewGroup',
    visible: false,
    ...
});
```

`ControlsManager` is parented under that group (`overview.js` `init`). `OverviewAdjustment` is created at `WINDOW_PICKER`. Control opacity is 255. None of that is on screen while the group is hidden.

**Matches.**

### 2. The stage is shown with the overview still hidden

`layout.js` `_loadBackground`, after the system background loads, on a low-priority idle:

```js
this._systemBackground.show();
global.stage.show();
this._prepareStartupAnimation()
```

`user` mode has `hasOverview: true`, so `_prepareStartupAnimation` does not scale `uiGroup` or set its opacity to 0. That scale-from-centre path runs only when `hasOverview` is false. Ubuntu dock skips the overview startup only when `disable-overview-on-startup` is true. Schema default is false.

On a normal desktop the picture is the desktop. The panel is up. The overview group is still hidden. `_prepareStartupAnimation` then awaits `_updateBackgrounds()` before the startup animation, and the picture stays the desktop across that wait.

**Matches.** This desktop is before the sequence in Seen. Seen starts at the first overview.

### 3. The session startup shows the overview

`layout.js` `_startupAnimationSession`:

```js
if (Main.sessionMode.hasOverview)
    await Main.overview.runStartupAnimation();
```

`overview.js` `runStartupAnimation`:

```js
this._shown = true;
this._visible = true;
this._visibleTarget = true;
Main.layoutManager.showOverview();
this._changeShownState(OverviewShownState.SHOWING);
await this._overview.runStartupAnimation();
```

`showOverview` shows `overviewGroup`, sets `_inOverview`, and `_updateVisibility` hides `window_group`.

On a normal desktop this is not its own picture. The next lines run in the same turn, and they force the controls to opacity 0 before the stage paints. The window picker that is already the adjustment's value does not get a frame.

**Does not match.** `overviewGroup.show()` is its own RPC. The server paints after it returns. The adjustment is still `WINDOW_PICKER` and the opacity is still 255, so that frame is the window picker. That is the overview at the start of Seen.

### 4. The adjustment is parked on the full-screen workspace

`overviewControls.js` `ControlsManager.runStartupAnimation`, still before the first `await` on a normal desktop:

```js
this._stateAdjustment.value = ControlsState.HIDDEN;
this._stateAdjustment.ease(ControlsState.WINDOW_PICKER, { ... });
```

`ControlsState.HIDDEN` is 0. `ControlsManagerLayout` gives that state the work-area box: the workspace origin and size are the work area. The dash is covered. That picture is the desktop. The old picker ticket recorded the same box (`800x568` on an `800x568` work area) and the same look.

On a normal desktop this assignment is still the turn from step 3. The stage has not painted it.

**Does not match.** `St.Adjustment.value` is `St-Adjustment.set_value`. The server applies `HIDDEN` and can paint it before the client reaches the opacity write in step 5. `window_group` is already hidden, so the full-screen workspace is the desktop in the middle of Seen.

### 5. Opacity is forced to 0, then the window picker fades in

Same function, still in that turn on a normal desktop:

```js
// Set the opacity here to avoid a 1-frame flicker
this.opacity = 0;
await this.layout_manager.ensureAllocation();
```

After the allocation it eases opacity to 255, drops the search in, and raises the dash. The adjustment ease from step 4 finishes on `WINDOW_PICKER`. `overview.js` then moves to `SHOWN` unless the overview was hidden during the fade.

On a normal desktop the first painted overview is this fade, and it is the last picture. The opacity write is what suppresses steps 3 and 4.

**Matches the ending.** The session finishes on the window picker. On ours this fade is the third picture, because steps 3 and 4 already painted. The divergence is step 3. Step 4 is the desktop that follows it. Step 5 does not put the desktop back.

## Reproduction

```bash
GSR_NESTED_TIMEOUT=40 \
  GI_META_SMOKE=startup-overview-sequence/ui/init \
  ./scripts/weston-gsr-prove.sh
```

`tests/gjs-embed/startup-overview-sequence.js`. A `before-update` while the overview group is shown is a frame of the cached adjustment and opacity. `miss` means a solid window picker, or a full-screen workspace, was painted before opacity reached 0. Not run yet.

## Not this bug

The Activities button staying highlighted while the overview is closed, and the click that hits the hot corner. Closed with the 2026-09-30 ticket, user 2026-10-29.

---

## LLM efforts

**2026-10-29.** User: close the picker-button ticket. Class the startup picture as its own bug. Read `vendor/gnome-shell/js/ui/layout.js` `_prepareStartupAnimation` / `_startupAnimationSession`, `overview.js` `runStartupAnimation`, `overviewControls.js` `runStartupAnimation`. No Weston run.

**2026-10-29.** User: walk the startup the way the menu expander ticket walks its steps, and name where the reference and ours diverge. Read `layout.js` overview-group construct (`visible: false`), `_loadBackground` stage show, `showOverview` / `_updateVisibility`, `overview.js` `runStartupAnimation`, `overviewControls.js` `ControlsManager.runStartupAnimation` and `ControlsManagerLayout` `HIDDEN` box, `environment.js` `ease`. No Weston run. Divergence written as step 3 (picker painted after `show`) and step 4 (`HIDDEN` work-area box painted before `opacity = 0`).

**2026-10-29.** Stage 2. `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` and `mutter-rpc.debug.log` end at 15:16:41 with the socket closing during `before-update`. `weston-autolaunch-prove.log` is the menu-expander prove. None of them names this startup sequence.
