# Frames stop after “GNOME Shell started”

**Status:** ✅ closed 2026-10-07. User: assume fixed.

**Plan:** [`../plans/done/1.2-teardown-and-restart.md`](../plans/done/1.2-teardown-and-restart.md) is archived. This is a separate boot hang.

## Seen

2026-10-03 09:14. `./scripts/weston-gsr-session.sh --debug` with `GI_RPC_JS_OVERRIDE_DIR=tests/shell-js-probe/dash-icons`.

`READY=1` at 09:14:51.283. Dash probe:

```text
gsr-dash-icons: adjust max=800x91 n=8 first=DashIcon icon=64x64 button=80x88 availH=43 old=64
gsr-dash-icons: adjust done iconSize=32
```

Then the client keeps making RPC until 09:14:56.113. Last call is `id=17558 method=Clutter-Actor.add_child`, and that reply arrives. The calls just before it are the welcome dialog: `MessageDialogContent` (two labels, ellipsize, line wrap) and two `St.Button`s (`set_button_mask`, `set_reactive`, `set_can_focus`, `set_x_expand`, `set_y_expand`, `set_label`, `rpc_signal`, `add_child`). That is `WelcomeDialog._buildLayout()` in `vendor/gnome-shell/js/ui/welcomeDialog.js`.

Same second, on the session log:

```text
09:14:56.065 GNOME Shell started at Sat Oct 03 2026 09:14:51 GMT+0800
09:14:56.113 Registering session with GDM
```

No `JS ERROR`. No `too much recursion`. No following “Error registering session with GDM”. Client debug log ends on the `add_child` reply. Mutter keeps running: a burst of `has no handler with id` (already archived, session survived it before), then pointer motion at 09:15:04. That motion does not show up as `captured-event` on the client. The session was closed about 09:15:11.

`has no handler` is [`2026-09-25-warning-unsubscribe-handler-not-on-instance.md`](2026-09-25-warning-unsubscribe-handler-not-on-instance.md). It is not this stop.

## What is stuck

The client main loop is not blocked. A stay-up boot through real `init.js` (so `Server-Bootstrap.begin_shell_startup` runs) logs a 1-second tick the whole time.

Probe: `tests/shell-js-probe/startup-stall/ui/init.js`.

```text
GSR_NESTED_TIMEOUT=16 GSR_NESTED_STAYUP=1 \
  GI_RPC_JS_OVERRIDE_DIR=tests/shell-js-probe/startup-stall \
  ./scripts/weston-gsr-prove.sh
```

2026-10-03 09:43:

```text
09:43:04.658 started frames=0
09:43:04.658 tick 1 frames=0 started=true
09:43:05.951 tick 2 frames=10
09:43:08.489 tick 3 frames=96
09:43:09.721 tick 4 frames=145
09:43:10.721 tick 5 frames=163
09:43:11.722 tick 6 frames=165
09:43:12.722 tick 7 frames=165
09:43:13.723 tick 8 frames=165
09:43:15.724 tick 10 frames=165
09:43:17.725 tick 12 frames=165
```

`READY=1` is 09:43:04.970. Frames run after the startup frame lock releases. They stop within about a second of the shell finishing startup, and they stay stopped. Ticks continue, so this is not `call_poll` waiting forever and not `RegisterSession` holding the main loop.

An earlier stay-up (09:35) did the same: frames stuck at 172 from tick 6 through tick 14.

The 09:14 client log going quiet is this. After the last animation frame there is nothing left to RPC. The picture does not update.

## Rejected

**🚫** Clamping the `-12` minimum height inside Clutter / St / libocrpc. That was tried on [`2026-09-25-box-layout-negative-min-height.md`](2026-09-25-box-layout-negative-min-height.md). The empty Quick Settings grid really is `(0 - 1) * 12`. Clamping hides the frame that observed it.

A gjs-embed smoke that does not go through `ui/init.js` skips `begin_shell_startup` (`src/client/ShellApplication.vala` only calls it for `init.js`). That boot dies in about 2 seconds:

```text
preferred-height base type=StWidget for=182 min=-12 nat=-12
ClutterBoxLayout child unnamed [GsrServerClutterActor] minimum height: -12.000000 < 0 for width 182.000000
nested-weston-prove: mutter exited ec=133 after 2s
```

That is the old exposure, not this hang. Do not “fix” it by clamping.

These already exist and do not name this stall:

- `tests/gjs-embed/style-reenter-smoke.js` — SquareBin `style-changed` re-entry. Passes. Not the 15:09 full-shell recursion.
- `tests/gjs-embed/dash-hover-style-smoke.js` — app-grid `_redisplay` → `BaseIcon.vfunc_style_changed`. Written for the 2026-10-02 recursion crash in [`../2026-09-30-overview-boot-flicker.md`](../2026-09-30-overview-boot-flicker.md). That crash is `too much recursion`, then SIGSEGV. This log has neither.

## Not done

The probe tried a virtual pointer at tick 8 (`stage` center x, y=16). `create_virtual_device` returned null (`poke-err TypeError: virt is null`), so this run does not show whether a real pointer schedules another frame.

No product change. Waking the frame clock after startup, or finding which inhibit is left, is the next step. It is not a clamp.
