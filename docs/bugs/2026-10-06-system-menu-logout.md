# System-menu Log Out does not end the session

**Status:** ⏳ open. The picker click failure is [`done/2026-10-06-picker-click-get-time.md`](done/2026-10-06-picker-click-get-time.md).

`alan@192.168.88.197`, session 6, still `active` at 14:08. The user opened the system menu and chose Log Out. The session stayed up, and the desktop did not come back.

The power button did receive the click. `Gjs_status_system_ShutdownItem` is the GNOME Shell 48 power menu. Its `clicked` handler opens that menu.

| Time | What the client log shows |
| --- | --- |
| 14:05:16.165 | `clicked`, then `Clutter-Actor.show`, grid layout, `Clutter-Stage.grab`. Menu opens. |
| 14:05:19.063 | `clicked`, then `Gsr-Clutter.get_current_event`, then `hide` and `Clutter-Grab.dismiss`. Menu closes. |
| 14:05:24.235 | Menu opens again. |
| 14:05:27.684 | Menu closes again. `Clutter-Grab.dismiss` at 14:05:28.136. |

`popupMenu.js` connects `Clutter.ClickAction::clicked` to `this.activate(Clutter.get_current_event())`. That is the 14:05:19 and 14:05:27 pair: the item click ran. There is no `JS ERROR` at either time, so `activateLogout()` did not throw. Stock `systemActions.js` `activateLogout` calls `Main.overview.hide()` and then `SessionManager.LogoutAsync(0)`.

`Logout(0)` is the normal mode. It asks the shell for the end-session dialog. It does not remove the logind session by itself. logind never records `Session 6 logged out`. The journal has no `SessionManager.Logout`. No end-session dialog showed up.

The picker bug throws inside `dnd.js` `_onButtonPress` before a normal click finishes. This menu item got past `clicked` and `get_current_event` and closed. Different path.

`mapped` is not writable on `ShutdownItem`, and `pressed` is not writable on `ClutterClickAction`. The menu still opened and closed after those.

## 2026-10-06 18:29 — disconnected client, different cause

The `alan2` session 230 Log Out attempt is not another clean reproduction of the failure above. At 18:24:19 the RPC connection had already been stopped by an unregistered `MetaSurfaceActorWayland` result. The client stayed alive but every later server operation failed with `not connected`. Opening the system menu at 18:29:30 reached `Clutter-Stage.grab`, which also failed for that reason. There is no later `clicked` notification or Logout call in the client log. The session remained online.

That disconnect is the RPC bug [`2026-10-07-unregistered-runtime-parent.md`](file:///home/alan/gitlive/OLLMchat/docs/bugs/2026-10-07-unregistered-runtime-parent.md).
