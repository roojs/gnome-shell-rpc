# System-menu Log Out does not end the session

**Status:** ✅ closed 2026-10-07. User: Log Out from the system menu is reasonably reliable. The client claims `org.gnome.Shell` in `command_line`. The picker click failure is [`2026-10-06-picker-click-get-time.md`](2026-10-06-picker-click-get-time.md).

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

## 2026-10-07 15:54 — click lands, session stuck in QUERY_END_SESSION

ℹ️ `alan@192.168.88.197`, logind session 49, GDM `gsr` from 15:53:01. `gsr-client` 16623, `gnome-session-binary` 16287. Still `active` after the Log Out click.

✔️ 15:54:16.089 press (`type=6`), 15:54:16.384 release (`type=7`), then `clicked`, two `Gsr-Clutter.get_current_event`, menu `hide`, `Clutter-Grab.dismiss`. Same path as 14:05: the power-menu item ran. No `JS ERROR`. No end-session dialog (`Clutter-Stage.grab` for a modal does not follow the dismiss).

✔️ `systemctl --user status gnome-session-manager@gsr.service` after that click: `Status: "GNOME Session Manager phase is QUERY_END_SESSION"`. It entered running at 15:53:02. logind has no `Session 49 logged out`.

✔️ `busctl --user call … NameHasOwner org.gnome.Shell` → `b false`. The user bus has `org.gnome.SessionManager` and `org.gnome.Shell.CalendarServer`. It does not have `org.gnome.Shell`. `IsInhibited(8)` (logout) is false.

Stock `gnome-shell` `src/main.c` `shell_dbus_acquire_name` takes `org.gnome.Shell` before JavaScript starts. `gsr-client` is `org.gnome.ShellRpc` and never takes that name. gnome-session `gsm_shell_is_running` is that name's watcher.

`Logout(0)` is normal mode. gnome-session moves to `QUERY_END_SESSION`, asks clients, then `show_shell_end_session_dialog`. That function returns immediately when the shell name is absent. It does not open the dialog, and it does not call `end_phase`. The phase stays `QUERY_END_SESSION`. A later Log Out click hits `user_logout` while already in that phase, sets the mode back to normal, and calls the same function, which returns again.

`Logout(1)` (no confirmation) from this phase, with logout not inhibited, calls `end_phase` and continues. That is the first step of crash-screen `on_crash_logout` (`SessionManager.Logout(1)`, then `login1.Session.Terminate`, then `context.terminate()`). `Terminate` is the step that still works if inhibitors are set, because `Logout(1)` would also try the missing dialog in that case.

🚫 Do not send `Logout(1)` or `Session.Terminate` against this live session from here. The user is on it.

## Fix — 2026-10-07

🔷 `gsr-client` claims `org.gnome.Shell` on its session bus before `init.js`. gnome-session watches that name and calls `Open` on it. The dialog is already exported on this connection.

🔷 One login session is active at a time, so this session is the one that owns `org.gnome.Shell`. Another user has a different bus. A second graphical login for this user is not the case this fix handles.

💩 `DO_NOT_QUEUE` is not what stock `main.c` does. If the name is already taken, the client warns and keeps running. It does not sit in the queue.

🚫 The server does not claim `org.gnome.Shell`.
🚫 Do not change the application id, drop `NON_UNIQUE`, or rename the desktop file, the systemd unit, or `RequiredComponents`.
🚫 Do not call `Logout(1)` or `Session.Terminate` from this fix.

### 1. `src/client/Application.vala` — `command_line`: claim the shell name

**Why:** gnome-session skips the end-session dialog when `org.gnome.Shell` has no owner, and the phase stays `QUERY_END_SESSION`.

**Where:** `command_line`, immediately after `this.prepare_host();`, before `open_context`.

**Depends on:** none.

#### Keep

```vala
			this.prepare_host();
```

#### Add — Request `org.gnome.Shell` on the session bus. Reply 1 or 4 is success. Any other reply, or a D-Bus error, is a warning. The client still starts.

```vala
			try {
				var result = GLib.Bus.get_sync(GLib.BusType.SESSION).call_sync(
					"org.freedesktop.DBus",
					"/org/freedesktop/DBus",
					"org.freedesktop.DBus",
					"RequestName",
					new GLib.Variant("(su)", "org.gnome.Shell",
						(uint) (GLib.BusNameOwnerFlags.ALLOW_REPLACEMENT
							| GLib.BusNameOwnerFlags.DO_NOT_QUEUE)),
					new GLib.VariantType("(u)"),
					GLib.DBusCallFlags.NONE,
					-1,
					null).get_child_value(0).get_uint32();
				if (result != 1 && result != 4) {
					GLib.warning("org.gnome.Shell not owned, reply %u", result);
				}
			} catch (GLib.Error e) {
				GLib.warning("org.gnome.Shell: %s", e.message);
			}
```

#### Keep

```vala
			var ctx = this.open_context({ "resource:///org/gnome/shell" });
```

## To verify

✅ 2026-10-07. User: Log Out from the system menu is reasonably reliable.

⏳ If `org.gnome.Shell` is already owned when the client starts, the client logs the warning and does not become the owner. That case was not the login they tried.
