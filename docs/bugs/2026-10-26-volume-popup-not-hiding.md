# Volume pop-down does not hide

**Status:** ⏳ open. Fixed in `Shell.Signals.connect`. Weston outside click hides the quick settings pop-down. The guest install does not have this build.

`PopupMenuManager` closes on `captured-event`. That connect ran and `Shell.Signals.connect` returned a handler id, but the id was for a queued name list (`pending_signals`), not `captured-event`. A second connect of the same name got a new id, and the outside click then hid the menu. `Shell.Signals.connect` now sends the requested name with that queued list.

Guest `alan@192.168.122.52`, 2026-10-26 14:10–14:13: presses land on `StWidget` `style=panel-menu`, server `captured_event` `hook=0`, client has no `notification method=captured-event`, and `PopupMenu.close` never starts. `192.168.88.197` has no route.

Weston after the fix, 2026-10-26 14:58, `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`:

```
volume-popup-hide/ui/init: after open open=true actor=0,0 0x0 visible=true mapped=true
volume-popup-hide/ui/init: after outside open=false actor=0,0 0x0 visible=false mapped=false
volume-popup-hide/ui/init: settings hid
volume-popup-hide/ui/init: volume button hidden
volume-popup-hide/ui/init: ok
```

The nested session has no volume arrow. That submenu uses the same `captured-event` subscribe. An empty quick-settings grid still aborts mutter with minimum height -12, so the smoke adds one visible row before the click.

**Reproduce:**

```bash
GI_META_SMOKE=volume-popup-hide/ui/init ./scripts/weston-gsr-prove.sh
```

## LLM efforts

### 2026-10-26 read the guest session

`ssh alan@192.168.88.197` returned `No route to host`. `alan@192.168.122.52` answered, hostname `alan-VirtualBox`. Logs `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` and `mutter-rpc.debug.log`, both written at 14:12.

Client: zero `captured-event`, zero `clicked`. Three `stopped` at 14:10:14.933–14:10:15.240, then no `remove_all_transitions`. Four `button-press-event` notifications, all 14:10:25–14:10:27, each followed by `Clutter-Grab.dismiss` (the slider). `JS ERROR: this.layout_manager is null` at 14:10:28 is `iconGrid.js` `FolderGrid` during app-grid redisplay, not the menu.

Server `ClutterActor.vala:452`: one `type=6` on `QuickSettings` at 14:10:16.969 (`hook=0` on capture, `hook=1` on `event`). From 14:10:18 through 14:13:20 the presses are `panel-menu` `hook=0`, plus four `BoxPointer` `hook=1` during the slider. `src/` not edited.

### 2026-10-26 Weston open aborts on -12

`GI_META_SMOKE=volume-popup-hide` (no `ui/init.js`) and then `GI_META_SMOKE=volume-popup-hide/ui/init`, before and after `meson compile -C build`. Each open allocated `ClutterBoxLayout child unnamed [GsrServerClutterActor] minimum height: -12.000000 < 0 for width 182.000000` and mutter stopped. The smoke's `after open` lines in those runs are against a dead server (`mapped=false`, actor `-1x-1`). `begin_shell_startup` ran once the script path ended in `ui/init.js`. The guest binaries from 12:29 do not log that -12 line. Local `src/` matches that tree apart from `README.md` (`0449686`).

`captured-event-smoke` in the same window printed `ok` (`sawCaptured=1`, picked the stage). That grabber is a GJS `St.Widget` subclass.

### 2026-10-26 Weston outside click leaves the menu up

`GSR_NESTED_TIMEOUT=30 GI_META_SMOKE=volume-popup-hide/ui/init ./scripts/weston-gsr-prove.sh` at 14:41. The smoke adds one 40×40 child to `menu._grid` before the click (`grid children 2`). No -12 line. `after outside open=true ... visible=true mapped=true`. `after close() open=false ... visible=false`. Then `volume button hidden` and `miss outside button`. Client log: no `captured-event`. `remove_all_transitions` at 14:41:39.802 is the explicit `close()`, not the outside click at 14:41:34.672. The second panel click used the +38,+59 offset (`click 752,0 48x32 ... at 814,75`); that press is not scored as a toggle. `src/` not edited.

### 2026-10-26 the first captured-event connect does not record that name

`Shell.Signals.connect` on the `panel-menu` actor returned handler id 656. Calling it again on the same actor returned 657, and the outside click then hid the menu (`after outside open=false`). The first call had consumed `pending_signals` and stored those names instead of `captured-event`. A connect made only at click time also hid it (`saw=6`, `inside=false`). A plain `St.Widget` with nothing queued does receive `captured-event` (`plain-captured-event: ok`).

`Shell.Signals.connect` now sends the requested name in front of that queued list. `meson compile -C build`. `GI_META_SMOKE=volume-popup-hide/ui/init` at 14:58: the panel click left the menu open, the outside click hid it (`settings hid`), then `volume button hidden` and `ok`. Client log has `notification method=captured-event`.
