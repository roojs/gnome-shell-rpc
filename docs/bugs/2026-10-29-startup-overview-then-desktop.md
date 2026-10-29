# Startup paints the overview, then the desktop, then the overview

**Status:** ⏳ open. User 2026-10-29. Split from the closed picker-button ticket [`done/2026-09-30-overview-boot-flicker.md`](done/2026-09-30-overview-boot-flicker.md). The clock waits on the client main loop's poll. Product `src/` is unchanged. The wake from that poll to the server clock is not written.

**Plan:** [`../plans/1.0-run-to-end.md`](../plans/1.0-run-to-end.md) row 0.1.

## Seen

On our startup the picture is an overview, then the desktop, then an overview again. The session is supposed to finish on the overview. The overview that appears before the desktop is the complaint.

Proved 2026-10-29 15:50. After the overview group is shown, the controls stay at opacity 255 for 80 frames: 63 at adjustment 0 (full-screen workspace), then 17 at adjustment 1 (the window picker). Opacity 0 comes after that. Those 80 frames are the turn a single process does not paint.

The controls adjustment is already 0 when it is created. Stock constructs it at `WINDOW_PICKER`.

A stock session on this machine has not been watched. The comparison is the stock JS in one process.

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

**Does not match.** `showOverview` returns with the adjustment at 0 and the opacity at 255 (`show-return v=0 o=255`). The adjustment was constructed at 0. The server then paints that full-screen workspace, and paints the window picker while the ease runs, before the opacity write in step 5. A single process paints none of those frames.

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

**Matches the ending.** The session finishes on the window picker. On ours the fade is the last picture, after the full-opacity frames in steps 3 and 4. The divergence is those frames. Step 5 does not put the desktop back.

## Reproduction

```bash
GSR_NESTED_TIMEOUT=40 \
  GI_META_SMOKE=startup-overview-sequence/ui/init \
  ./scripts/weston-gsr-prove.sh
```

`tests/gjs-embed/startup-overview-sequence.js`. A `before-update` is one frame. The adjustment and the opacity are the values last notified on the controls.

2026-10-29 15:50:28, `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`:

```text
startup-overview-sequence/ui/init: controls-init v=0 o=255
startup-overview-sequence/ui/init: show-return v=0 o=255
startup-overview-sequence/ui/init: miss desktop,overview,clear,move
startup-overview-sequence/ui/init: samples desktop@ov=0 v=0.00 o=255 n=23 | desktop@ov=1 v=0.00 o=255 n=63 | overview@ov=1 v=1.00 o=255 n=17 | clear@ov=1 v=1.00 o=0 n=4 | move@ov=1 v=1.00 o=16 n=20
```

`ov=1` is the overview group shown. `v=0` is the full-screen workspace. `v=1` and `o=255` is the window picker. `o=0` is the controls hidden. The fade had started (`o=16`) when the probe stopped receiving frames.

## Discarded trial

Rejected as a fix, user 2026-10-29. The stock script already sets this opacity. Reordering it in JavaScript is not the change. The run only shows what the picture is when that opacity is already 0 before `show`.

Same smoke, with the controls opacity forced to 0 and the easing duration forced to 0 before `overviewGroup.show()`:

```bash
GSR_NESTED_TIMEOUT=40 \
  GI_META_SMOKE=startup-overview-sequence/ui/init \
  GI_META_SMOKE_CMD=hide-before-show \
  ./scripts/weston-gsr-prove.sh
```

2026-10-29 15:55:56:

```text
startup-overview-sequence/ui/init: hide-set o=0
startup-overview-sequence/ui/init: show-return v=0 o=0 trial=true
startup-overview-sequence/ui/init: miss no-overview desktop,clear,move
startup-overview-sequence/ui/init: samples desktop@ov=0 v=0.00 o=255 n=20 | clear@ov=1 v=0.00 o=0 n=45 | clear@ov=1 v=1.00 o=0 n=11 | move@ov=1 v=1.00 o=17 n=17 | move@ov=1 v=1.00 o=17 n=0
```

The 63-frame full-screen workspace and the 17-frame window picker are gone. Every shown frame is opacity 0 until the fade starts. The last read is still opacity 17: the probe stops receiving `before-update` during the fade, on the failing run as well. That stall is the probe. It is not a second product failure.

## Shrink

`tests/call-sync-repro/startup-paint-gap-gate.vala`. Show, a short quiet, the opacity write. `current` presents during the short quiet. `main-poll` does not. Its client is a `GLib.MainLoop` whose poll func is `GLib.MainContext.set_poll_func`. The frame runs from that func, after the idle source has returned. The idle does not send the frame. An input byte during the idle is handled. `flow-idle` still presents after a long quiet. That duration is not the rule. No mode links `src/`.

```bash
./build/tests/call-sync-repro/startup-paint-gap-gate current
./build/tests/call-sync-repro/startup-paint-gap-gate main-poll
./build/tests/call-sync-repro/startup-paint-gap-gate flow-idle
```

2026-10-29. `current` exit 1. `main-poll` exit 0: `PASS main-poll: frame ran when the main loop polled, after the source returned`. `flow-idle` exit 0. `poll` exit 0. `poll-short` exit 1.

## Proposed behavior

No JavaScript change. `signals.js` stays the connect relay. `vendor/gnome-shell` stays as it is. The smoke's opacity write before `show` is not a fix. No `GLib.Idle.add`. The read-loop poll is withdrawn: it stops the compositor main loop, not only the clock.

In one process the frame clock is another source on the shell's main context. It does not run while a source callback is on the stack. The startup animation's synchronous prefix is that callback. It returns at `await this.layout_manager.ensureAllocation()`, and the loop then polls. That poll is the block. Nothing in the shell decides that the stage should wait.

Our client runs that callback on its own context. `call_poll` waits with `GLib.poll` and does not enter the main context poll, so the gaps between RPCs are still inside the callback. The server context is free in those gaps, and its frame clock runs. `emit_wait_poll` is the same kind of wait, and it ends when the signal reply is read. The follow-up `St-Widget.get_theme_node` (id 10537, 0.4ms after reply 10536) was the callback continuing, not the main loop polling.

`main-poll` hooks `GLib.MainContext.set_poll_func`. The short quiet is still the callback, so it does not paint. Input during the callback is handled. The frame is opacity 0, and it runs from the poll func after the idle returns. `flow-idle` reaches the same picture by waiting out a quiet. That wait is a guess at this poll, and it is not the hook.

The poll func has to wake the server without `call_poll`. `call_poll` is the inner wait, and it removes the client's read watch. The server answers that wake by letting the frame clock run, then the poll func blocks in the real poll so a blocking `before-update` can be read. Product `src/` is unchanged. That wake is not written.

## Not this bug

The Activities button staying highlighted while the overview is closed, and the click that hits the hot corner. Closed with the 2026-09-30 ticket, user 2026-10-29.

---

## LLM efforts

**2026-10-29.** User: close the picker-button ticket. Class the startup picture as its own bug. Read `vendor/gnome-shell/js/ui/layout.js` `_prepareStartupAnimation` / `_startupAnimationSession`, `overview.js` `runStartupAnimation`, `overviewControls.js` `runStartupAnimation`. No Weston run.

**2026-10-29.** User: walk the startup the way the menu expander ticket walks its steps, and name where the reference and ours diverge. Read `layout.js` overview-group construct (`visible: false`), `_loadBackground` stage show, `showOverview` / `_updateVisibility`, `overview.js` `runStartupAnimation`, `overviewControls.js` `ControlsManager.runStartupAnimation` and `ControlsManagerLayout` `HIDDEN` box, `environment.js` `ease`. No Weston run. Divergence written as step 3 (picker painted after `show`) and step 4 (`HIDDEN` work-area box painted before `opacity = 0`).

**2026-10-29.** Stage 2. `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` and `mutter-rpc.debug.log` end at 15:16:41 with the socket closing during `before-update`. `weston-autolaunch-prove.log` is the menu-expander prove. None of them names this startup sequence.

**2026-10-29 15:46.** `GSR_NESTED_TIMEOUT=40 GI_META_SMOKE=startup-overview-sequence/ui/init ./scripts/weston-gsr-prove.sh`. Stop `smoke-fail` after 9s. `miss no-overview`. The wrapper finished during the fade (`o=16`). Samples were incomplete. Weston killed, ec=137, not a shell crash.

**2026-10-29 15:50.** Same command. `controls-init v=0 o=255`. `show-return v=0 o=255`. `miss desktop,overview,clear,move`. Shown frames: 63 at v=0 o=255, then 17 at v=1 o=255, then o=0. Probe frames then stop at o=16.

**2026-10-29 15:53.** `GI_META_SMOKE_CMD=hide-before-show` but `state.controls` was never stored, so the opacity write did not run. Same miss as 15:50. Discarded.

**2026-10-29 15:55.** Trial with the controls reference stored. `hide-set o=0`, `show-return v=0 o=0`. Samples stay at o=0 while the overview is shown, until the fade starts at o=17. Final read o=17. `miss no-overview` because the probe's frames stop. The early picker is gone. Proposal written. Not applied.

**2026-10-29.** User: `signals.js` is only the signal relay. The `Actor.show` wrap is not an acceptable place for this. Proposal removed. The trial result stays. No product edit.

**2026-10-29.** User: do not hack the JavaScript. The stock script already does this. The opacity write before `show` is discarded as a fix. No product edit.

**2026-10-29.** User: the JavaScript rejection is not a stop. `startup-paint-gap-gate` `current` exit 1 (frame at opacity 255 while the turn is open). `in-process` exit 0. `hold-turn` exit 0 (first frame is opacity 0 after the turn yields). Product `src/` unchanged. Proposal written. Not applied.

**2026-10-29.** User: an idle will not be approved. The idle proposal is withdrawn. 15:50 prove, client id 10537 `St-Widget.get_theme_node` was sent 0.4ms after `RPC-Live-Callback.reply` id 10536; the server read it 73ms later. In 15:50:06–09, where the server read within 2ms of the send, seven gaps were 5ms or more and the longest was 10.6ms, all before `show-return`. `poll` exit 0. `poll-short` exit 1. Product `src/` unchanged.

**2026-10-29.** User: the read-loop poll is too risky. Withdrawn. The clock should stop while the signal flow is busy and start when that flow is idle, the way a current pointer event already holds `before-update`. `flow-idle` exit 0, and the input event in the hold was handled. Product `src/` unchanged. No fences.

**2026-10-29.** User: do not second-guess the stage, and do not intercept it. Hook the wait the shell already blocks in. `flow-idle`'s quiet duration is that guess. `main-poll` sets `GLib.MainContext.set_poll_func` on the client loop. The idle source writes show, the short quiet, input, and opacity. It does not write the frame. Exit 0: `PASS main-poll: frame ran when the main loop polled, after the source returned`. The first `GLib.Idle.add` attached to the global context and the private loop polled forever; the idle is an `IdleSource` attached to that loop. Product `src/` unchanged. The wake from the poll func to the server clock is not written.
