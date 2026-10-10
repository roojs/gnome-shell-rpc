# Panel menu closes on the click that opens it

**Status:** Fixed in `signal_overrides`. A panel click used to run `vfunc_event` twice, so the menu toggled open and then shut. `event` and `captured-event` are no longer subscribed there. The relay hook is the one vfunc call.

`panel-menu-stay-smoke` at 11:26: `date open` four seconds after the clock click. Quick Settings then got one `BUTTON_PRESS` (`hook=1`) and `Clutter-Stage.grab`, with no `Clutter-Grab.dismiss` before the nest was stopped. The volume device arrow (`QuickSlider._menuButton` `clicked`) was not scored.

Reproduction: `GI_META_SMOKE=panel-menu-stay-smoke` under Weston. The live session is `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` and `mutter-rpc.debug.log` from 11:04:43 to 11:05:31.

## What the 11:05 session did

`gsr-client` connected at 11:04:43. Two `button-press-event` notifications, at 11:05:06 and 11:05:18. No `clicked`. The session socket closed at 11:05:31 (`mutter exited ec=133` in `weston-autolaunch-prove.log`).

Quick Settings at 11:05:21, server `ClutterActor.vala`:

```text
11:05:21.164  captured-event type=6  QuickSettings  hook=0
11:05:21.281  event          type=6  QuickSettings  hook=1
```

`type=6` is `BUTTON_PRESS`. The client shows the menu during the first delivery (`Clutter-Actor.show`, `ShutdownItem` mapped, volume `Gsr-St-DrawingArea.paint`) and `Clutter-Grab.dismiss` about 70ms later, still inside that click. The same grab-then-dismiss pair is at 11:05:23 and 11:05:24.

`signal_overrides` subscribes every replaced vfunc that has a GObject signal, including `event`. `Signals.emit` then runs the vfunc. The server `event` override also runs it through the relay hook. `G_SIGNAL_RUN_LAST` runs the subscribe handler first, so the menu toggles open, then the relay toggles it shut.

The volume row's own menu is `QuickSlider._menuButton` `clicked` → `menu.open()` (`vendor/gnome-shell/js/ui/quickSettings.js`). That is not this toggle. The system menu never stayed up long enough to use it.

## Fix

`signal_overrides` skips `event` and `captured-event`. The relay hook is the vfunc path. A GJS `.connect('captured-event')` still subscribes through `Shell.Signals.connect`.

## LLM efforts

2026-10-10 11:05. Read `org.gnome.ShellRpc.debug.log` and `mutter-rpc.debug.log` for the session that connected at 11:04:43. Quick Settings `BUTTON_PRESS` was delivered twice (`event` subscribe, then the relay). The client showed the menu and dismissed the grab inside that click. Same grab/dismiss at 11:05:23 and 11:05:24.

2026-10-10 11:26. `GSR_NESTED_STAYUP=1 GI_META_SMOKE=panel-menu-stay-smoke`, prove mode. Clock click stayed open (`panel-menu-stay-smoke: date open`). Quick Settings press was a single `type=6` `hook=1`, then `Clutter-Stage.grab`. The nest got signal 15 during the quick-settings wait, before the smoke printed that result.
