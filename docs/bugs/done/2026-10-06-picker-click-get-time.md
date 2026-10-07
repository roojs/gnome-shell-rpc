# Application picker clicks throw on event time

**Status:** ✅ closed 2026-10-07. User: assume fixed. The empty window overview is [`../2026-10-06-overview-no-thumbnails.md`](../2026-10-06-overview-no-thumbnails.md). Log Out is [`../2026-10-06-system-menu-logout.md`](../2026-10-06-system-menu-logout.md).

`alan@192.168.88.197`, host `alan-VirtualBox`. Session 6 from GDM at 14:03:19. `gsr-client --debug` 5781. The user could type, delete, and search in the application picker. Clicks on the picker did nothing. The system menu still opened.

The two launches that did work both threw, then continued:

```text
14:03:34.936  JS ERROR: Could not locate clutter_event_get_time
            _onButtonPress@dnd.js:189
            _onCapturedEvent@searchController.js:311
14:03:34.990  notification method=clicked
14:03:35.762  Gsr-Mutter-AppLaunch.launch_desktop_file
```

Same three lines at 14:03:54.922 / 14:03:54.925 / 14:03:55.537 for the terminal.

GNOME Shell 48 `dnd.js` `_onButtonPress` calls `_grabActor` and then `event.get_time()`. `Clutter.Event` exported `get_device` and did not export `clutter_event_get_time`. The throw is inside the button-press handler, after the grab is taken. Later picker clicks produced no `clicked` and no second `get_time` error. Pointer motion kept calling `Clutter-Stage.get_actor_at_pos`.

This is not the Log Out failure. A power-menu item click at 14:05:19 ran `popupMenu.js` `activate(Clutter.get_current_event())` and closed the menu. That handler does not call `get_time()`.

## Fix

`Clutter.Event` now keeps the compositor timestamp and exports `clutter_event_get_time`. The button-press, signal, and `get_current_event` packs append that `uint32` after the device type. `gsr-client` and `gsr-server` rebuild. Not proven on a new login yet.
