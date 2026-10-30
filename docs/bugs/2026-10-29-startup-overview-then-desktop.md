# Startup paints the overview, then the desktop, then the overview

**Status:** ⏳ open. User 2026-10-30. Freeze drawing when `overviewGroup` is shown. Allow it again when the controls actor sets opacity to 0. Once, at startup. Gate `overview-hold` passed. Product `src/` is unchanged. Proposal below.

**Plan:** [`../plans/1.0-run-to-end.md`](../plans/1.0-run-to-end.md) row 0.1.

## The difference

A normal shell draws when this script pauses. We draw when a call returns. The pause is the last line. The call returns after every line before it.

```js
Main.layoutManager.showOverview();
this._stateAdjustment.value = ControlsState.HIDDEN;
this._stateAdjustment.ease(ControlsState.WINDOW_PICKER, { ... });
this.opacity = 0;
await this.layout_manager.ensureAllocation();
```

- `showOverview()` — **Can catch. Stop rendering.** The overview goes on screen, fully visible, windows filling the screen. A normal shell draws nothing here. Our call return is what starts those pictures. 63 were measured. This is the stop we can see.
- `value = HIDDEN` — **Can catch. Rendering stays stopped.** Same full-screen size, still inside the stop. Another call return, not a new start.
- `ease(...)` — **Can catch. Rendering stays stopped.** The slide starts on our drawing side and asks for a picture every frame. A normal shell is still stopped, so this is not a start. 17 of those pictures were the window picker.
- `opacity = 0` — **Can catch. Start rendering.** This call makes the overview invisible. Pictures after it are the fade, not the full-screen windows. This is the start we can see.
- `await ensureAllocation()` — **Can't catch. Start rendering.** A normal shell starts here. The pause looks like the gap after any call above. Drawing has to begin by here or startup stays on this line. We cannot see this start, so the start we can use is the line before it.

Freeze when `overviewGroup` is shown. Allow frames again when the controls actor sets opacity to 0. That is once, at startup. Showing the overview later uses the same show and does not set that opacity to 0, so a freeze that waits for it would never end. Other actors under the overview set opacity to 0 earlier, while the controls are still fully visible, so the release has to be the controls actor.

Measured 2026-10-29 15:50, before `opacity = 0`: 63 full-screen pictures, then 17 of the picker. A normal shell on this machine has not been watched. In one process those wait for the pause.

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

`tests/call-sync-repro/startup-paint-gap-gate.vala`. Show, a short quiet, the opacity write. No mode links `src/`.

- `current` presents during the short quiet.
- `main-poll` does not.
  - Client is a `GLib.MainLoop`.
  - Poll func is `GLib.MainContext.set_poll_func`.
  - The frame runs from that func, after the idle returns.
  - The idle does not send the frame.
  - An input byte during the idle is handled.
- `overview-hold` freezes on show, ignores a child opacity, draws when the controls opacity write arrives, and still draws a later show.

```bash
./build/tests/call-sync-repro/startup-paint-gap-gate current
./build/tests/call-sync-repro/startup-paint-gap-gate main-poll
./build/tests/call-sync-repro/startup-paint-gap-gate poll-wake
./build/tests/call-sync-repro/startup-paint-gap-gate overview-hold
```

2026-10-29. `current` exit 1. `main-poll` exit 0: `PASS main-poll: frame ran when the main loop polled, after the source returned`. `flow-idle` exit 0. `poll` exit 0. `poll-short` exit 1.

2026-10-30. `overview-hold` exit 0: `PASS overview-hold: frozen from show until the controls opacity write, later show still draws`. `current` still exit 1.

## Proposed behavior

Freeze the frame clocks when the actor named `overviewGroup` becomes visible. Allow frames again when the actor whose style class is `controls-manager` sets opacity to 0. Then schedule one update, so `ensureAllocation()` gets its layout. Do that once. A later show of the overview does not set that opacity to 0, and a child opacity (the thumbnails) is not the release.

`notify_ready` has already released `StartupFrameLock` before this show. This hold is separate. It runs from the show call and the opacity call, not from a frame. The shell script stays as it is.

Proved off `src/` by `startup-paint-gap-gate overview-hold`, exit 0. No frame while frozen, including after a child opacity. A frame at opacity 0 when the controls write arrives. A later show still draws.

### 1. `src/server/OverviewPaintHold.vala` — hold the clocks from overview show until the controls opacity write

**Why:** `showOverview()` shows `overviewGroup`. `ControlsManager` (`style_class` `controls-manager`) then sets `opacity` to 0. The slide between those two calls is on the server and keeps scheduling frames. Inhibiting the stage-view clocks for that span stops those frames. `uninhibit` plus `schedule_update` is the frame `ensureAllocation()` waits on.

One object, same shape as `StartupFrameLock`. `St.rpc_register` constructs it and keeps it on the helper that mints widgets. `spent`, `held`, the signal ids, the controls actor, the clocks, and the connection are fields on that object.

The `clutter_stage_view_get_frame_clock` binding stays a `static extern`. It is a C function, the same as on `StartupFrameLock`.

**Where:** New file.

**Depends on:** none.

#### Add

New file `src/server/OverviewPaintHold.vala`.

```vala
namespace Gsr.Server
{
	/**
	 * Stops stage updates from the first {@code overviewGroup} show
	 * until the controls actor sets opacity to 0.
	 *
	 * One shot. A later overview show does not take the hold.
	 * A child opacity is not the release. Do not call this from a
	 * frame: virtio keeps scanning a frame that was inhibited.
	 *
	 * == Example ==
	 *
	 * {{{
	 * var hold = new OverviewPaintHold();
	 * hold.watch(actor, connection);
	 * }}}
	 */
	public class OverviewPaintHold : GLib.Object
	{
		private bool spent;
		private bool held;
		private ulong opacity_id;
		private ulong stopped_id;
		private ulong added_id;
		private global::Clutter.Actor? controls;
		private global::Clutter.FrameClock[] clocks = {};
		private Gsr.Server.Rpc.Connection? connection;

		[CCode (cname = "clutter_stage_view_get_frame_clock", cheader_filename = "clutter/clutter.h")]
		private static extern unowned global::Clutter.FrameClock view_frame_clock(global::Clutter.StageView view);

		/**
		 * Watch one newly minted actor for the overview-group name.
		 *
		 * @param actor widget just minted
		 * @param connection shell connection that minted it
		 */
		public void watch(
			global::Clutter.Actor actor,
			Gsr.Server.Rpc.Connection connection)
		{
			actor.notify.connect((pspec) => {
				if (this.spent) {
					return;
				}
				if (pspec.name != "visible" && pspec.name != "name") {
					return;
				}
				if (actor.name != "overviewGroup" || !actor.visible) {
					return;
				}
				this.connection = connection;
				this.on_shown(actor);
			});
		}

		private void on_shown(global::Clutter.Actor group)
		{
			if (this.spent || this.held) {
				return;
			}
			var found = this.find_controls(group);
			if (found != null) {
				this.hold(group, found);
				return;
			}
			if (this.added_id != 0) {
				return;
			}
			this.added_id = group.actor_added.connect((child) => {
				if (this.spent || this.held) {
					return;
				}
				var late = this.find_controls(group);
				if (late != null) {
					this.hold(group, late);
				}
			});
		}

		private global::Clutter.Actor? find_controls(global::Clutter.Actor actor)
		{
			var widget = actor as global::St.Widget;
			if (widget != null) {
				var style = widget.get_style_class_name();
				if (style == "controls-manager") {
					return actor;
				}
			}
			for (var i = 0; i < actor.get_n_children(); i++) {
				var child = actor.get_child_at_index(i);
				if (child == null) {
					continue;
				}
				var found = this.find_controls(child);
				if (found != null) {
					return found;
				}
			}
			return null;
		}

		private void hold(
			global::Clutter.Actor group,
			global::Clutter.Actor controls)
		{
			var stage = group.get_stage() as global::Clutter.Stage;
			if (stage == null || stage.peek_stage_views().length() == 0) {
				return;
			}
			foreach (var view in stage.peek_stage_views()) {
				var clock = view_frame_clock(view);
				clock.inhibit();
				this.clocks += clock;
			}
			this.controls = controls;
			this.held = true;
			this.opacity_id = controls.notify["opacity"].connect(() => {
				if (controls.opacity != 0) {
					return;
				}
				this.release(stage);
			});
			if (this.connection != null) {
				this.stopped_id = this.connection.stopped.connect(() => {
					this.release(stage);
				});
			}
		}

		private void release(global::Clutter.Stage stage)
		{
			if (!this.held) {
				return;
			}
			if (this.controls != null && this.opacity_id != 0) {
				this.controls.disconnect(this.opacity_id);
				this.opacity_id = 0;
			}
			if (this.connection != null && this.stopped_id != 0) {
				this.connection.disconnect(this.stopped_id);
				this.stopped_id = 0;
			}
			foreach (var clock in this.clocks) {
				clock.uninhibit();
			}
			this.clocks = {};
			this.controls = null;
			this.connection = null;
			this.held = false;
			this.spent = true;
			stage.schedule_update();
		}
	}
}
```

### 2. `src/meson.build` — compile the hold

**Why:** The new file has to be in the server library.

**Where:** `compositor_sources`, the line after `server/StartupFrameLock.vala`.

**Depends on:** §1.

#### Add

After `server/StartupFrameLock.vala`.

```meson
  'server/OverviewPaintHold.vala',
```

### 3. `src/server/libst-16/St.vala` — the helper owns the hold and watches each new widget

**Why:** `overviewGroup` is an `St.Widget` minted here, before its name and its later `show()`. `rpc_register` already builds one helper. That helper owns the hold. `mint` calls `watch` on it.

**Where:** the field, `rpc_register`, the constructor, and `mint` immediately after `request.connection.export(created)`.

**Depends on:** §1.

#### Remove

```vala
		public static void rpc_register()
		{
			var helper = new St();
```

#### Replace with

```vala
		/**
		 * Startup overview paint hold for actors this helper mints.
		 */
		private OverviewPaintHold paint_hold;

		public static void rpc_register()
		{
			var helper = new St(new OverviewPaintHold());
```

#### Remove

```vala
		[CCode (cname = "gnome_shell_rpc_rpc_helper_st_create")]
		public St()
		{
		}
```

#### Replace with

```vala
		[CCode (cname = "gnome_shell_rpc_rpc_helper_st_create")]
		public St(OverviewPaintHold paint_hold)
		{
			this.paint_hold = paint_hold;
		}
```

#### Add

In `mint`, immediately after `request.connection.export(created)`.

```vala
			var actor = created as global::Clutter.Actor;
			if (actor != null) {
				this.paint_hold.watch(
					actor,
					(Gsr.Server.Rpc.Connection) request.connection);
			}
```

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

**2026-10-30.** `poll-wake` on the same gate. The poll func writes a wake, `GLib.poll` includes the read fd, the server writes a blocking before-update and waits for the reply, then the poll func writes hold and reads the ack. A timeout of 0 skips the wake. Exit 0: `PASS poll-wake: frame ran from the poll wake, before-update was read during that poll`. `main-poll` still exit 0. `current` still exit 1. Proposal written: `set_poll_func` on `run_main_loop`, a side socket, and `after-update` inhibit. Product `src/` unchanged.

**2026-10-30.** User: banned from running main-loop work, and will not accept it again. The `set_poll_func` proposal is withdrawn. Fences removed. Product `src/` unchanged. No replacement.

**2026-10-30.** User: the step list does not say what blocks the updates, and the JavaScript walk is not the account. Rewrote the top around the hold. In one process the startup idle keeps the frame-clock source from dispatching until `await ensureAllocation()`. Here `call_poll` returns the server to its main loop after each reply, and `emit_wait_poll` is not on the stack. The work-area box is what those unblocked frames show. Product `src/` unchanged. No fences.

**2026-10-30.** User: the hold account is too dense to read past two paragraphs. Same facts, broken into bullets. Product `src/` unchanged.

**2026-10-30.** User: that account is jargon and does not help. Rewrote Seen, the hold, and the proposed behavior in plain language. Same facts. Product `src/` unchanged.

**2026-10-30.** User: the smoking gun is still buried in words. The thing to watch is a drawing of the overview while it is still fully visible. Normal shell: not drawn. This session: 63 full-screen, then 17 picker. Replaced the two prose sections with that table. Product `src/` unchanged.

**2026-10-30.** User: that reduction has no value. The table named the pictures and dropped the reason. Put back the two moments: a normal shell draws when the script reaches `await ensureAllocation()`. We draw when a call returns, and `ease()` then keeps drawing until `opacity = 0`. Product `src/` unchanged.

**2026-10-30.** User: flag each line can catch or can't catch. `showOverview`, `value = HIDDEN`, `ease`, and `opacity = 0` are calls or a slide we see. The `await` pause looks like the gap after any of those calls. Product `src/` unchanged.

**2026-10-30.** User: also mark each line as stop rendering or start rendering. Stop we can catch: `showOverview()`. Stay stopped through `value = HIDDEN` and `ease()`. Start we can catch: `opacity = 0`. Start we cannot catch: the `await`. Product `src/` unchanged.

**2026-10-30.** User: freeze on the overview show and enable framing at opacity 0. That pair works once, at startup. A later overview show does not set the controls opacity to 0, and an earlier opacity 0 on a child (the thumbnails) would release while the controls are still fully visible. Product `src/` unchanged. No fences.

**2026-10-30.** User: proposal for that pair. `startup-paint-gap-gate overview-hold` exit 0: frozen from show through a child opacity, a frame at opacity 0 on the controls write, a later show still draws. `current` still exit 1. Proposal written in the bug. Product `src/` unchanged.

**2026-10-30.** User: that proposal leans on static variables. `OverviewPaintHold` is one object. `St.rpc_register` constructs it and stores it on the helper. `mint` calls `watch` on that object. The frame-clock lookup stays a `static extern`, as on `StartupFrameLock`. Product `src/` unchanged.
