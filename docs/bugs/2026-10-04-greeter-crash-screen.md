# Greeter login opens the crash screen

**Status:** ⏳ open. User 2026-10-05 09:10. The desktop came up and Log Out returned to GDM. Starting an app still killed the shell. The journal has the trap and not the abort string.

**Plan:** installed greeter session from [`../plans/done/1.1-installable-bootable-session.md`](../plans/done/1.1-installable-bootable-session.md). The screen itself is `on_crash()` from [`../plans/done/1.2-teardown-and-restart.md`](../plans/done/1.2-teardown-and-restart.md).

Separate from [`2026-10-03-greeter-login-black-screen.md`](2026-10-03-greeter-login-black-screen.md). That login aborted in `poll_drain_readable` (`Unexpected early end-of-stream`) and the VT stayed black. This login logs a JS error, then the surviving server paints the crash screen. No `Unexpected early end-of-stream` in this journal. No `GNOME Shell started`.

## Seen

2026-10-04 09:42:43. GDM password login for `alan2` (uid 1002). `gnome-session-manager@gsr.service` reached running. Installed that minute: `/usr/bin/gsr-client`, `/usr/bin/gsr-server`, `/usr/lib/x86_64-linux-gnu/libmutter-clutter-rpc-16.so` (mtime 09:42:27).

Two `gsr-server --wayland` processes, same split as the black-screen login:

| PID | Who started it | Result |
| --- | --- | --- |
| 160855 | `gnome-session-binary`, scope `app-gnome-org.gnome.ShellRpc-160855.scope` | Stayed up. This process paints the crash screen. |
| 160863 | `org.gnome.ShellRpc@wayland.service` | Exited 1 at 09:42:44. `Failed to setup: Native backend mode needs to be session controller`. Unit `Failed with result 'exit-code'`. |

Three `gsr-client` processes, then a kernel `trap int3` in `libglib-2.0.so.0.8400.1` for each:

| PID | Trap | Notes |
| --- | --- | --- |
| 161055 | 09:42:46.160 | First spawn. Last journal lines are the JS error below. |
| 161947 | 09:42:53 | Second spawn, about 6 s later. Same chrome criticals (`DateMenuButton`, `QuickSettings`). JS stack not copied out yet. |
| 162066 | 09:42:56 | `--disable-extensions` (crash-screen “Restart without extensions”). JS stack not copied out yet. |

First client, then nothing else from that pid. The trap is 2 ms after the second copy of the error.

```text
09:42:46.157953  JS ERROR: GLib.Error g-invoke-error-quark: Could not locate clutter_event_get_scroll_source: 'clutter_event_get_scroll_source': /lib/x86_64-linux-gnu/libmutter-clutter-rpc-16.so: undefined symbol: clutter_event_get_scroll_source
canHandleEvent@resource:///org/gnome/shell/ui/swipeTracker.js:350:13
_handleEvent@resource:///org/gnome/shell/ui/swipeTracker.js:368:19
@resource:///org/gnome/shell/ui/init.js:21:20
09:42:46.158351  same JS ERROR, same stack
09:42:46.159993  kernel: traps: gsr-client[161055] trap int3 … libglib-2.0.so.0.8400.1
```

`swipeTracker.js` `canHandleEvent` is `event.get_scroll_source() !== Clutter.ScrollSource.FINGER`. That runs while `init.js` is still on the stack.

Before the JS error, the same criticals as the 2026-10-03 login: `g_value_get_object`, repeated `g_atomic_ref_count_dec`, `property 'mapped' … DateMenuButton is not writable`, then the same for `QuickSettings`. `XDG_SESSION_ID` unset is the stock logind fallback.

`/var/crash/_usr_bin_gsr-client.1002.crash` (09:42, uid 1002, mode 640). Not read from this account.

## What is wrong

The crash screen is `on_crash()` in `src/server/rpc/Server.vala`. It runs when `gsr-client` exits. The client exits during `init.js` because `Clutter.Event.get_scroll_source` is missing from the stub library gjs is bound to.

Stock mutter 48 exports it: `clutter_event_get_scroll_source` in `/usr/lib/x86_64-linux-gnu/mutter-16/libmutter-clutter-16.so`, and `get_scroll_source` in `Clutter-16.gir`. Our typelib is that GIR passed to `g-ir-compiler --shared-library libmutter-clutter-rpc-16.so` (`src/meson.build`, `clutter_rpc_typelib`). gjs therefore looks the symbol up in the stub `.so`.

`Event` is denied as a type, not as this one method. `src/client/libmutter-clutter-rpc-16/Clutter.deny` lists `Event` (the sole Clutter GIR union). `Clutter.overrides` says the same: denied, Compact in `Clutter.override.vala`. The generator therefore emits no `Event` methods. The stock typelib still lists them (`g-ir-compiler` of `Clutter-16.gir` with `--shared-library libmutter-clutter-rpc-16.so`). The nested `Event.add_filter` / `Event.get` / `Event.remove_filter` lines in the deny file are the ones called out as “stock typelib still lists them”; those three have hand bodies. `get_scroll_source` has no deny line of its own and no hand body.

`nm -D` on the installed `libmutter-clutter-rpc-16.so` has the Event methods written in `Clutter.override.vala` (`get_button`, `get_coords`, `get_flags`, `get_key_symbol`, `get_related`, `get_state`). It does not have `clutter_event_get_scroll_source`.

`canHandleEvent` only calls `get_scroll_source` after `event.type() === Clutter.EventType.SCROLL`. The init.js stack reached that call, so this event is a scroll. The next clause is `event.get_source_device().get_device_type()`. `get_source_device` is also absent from that `.so`. A getter that returns anything other than `Clutter.ScrollSource.FINGER` falls through to it.

The session-controller race (desktop file and the systemd unit both start a server) is still the black-screen bug’s second finding. The unit still loses. The desktop-file server is the one that stays up and shows this screen.

## Fix

`Event.get_scroll_source` and `Event.get_source_device` are on the compact event (`Clutter.override.vala`). The actor event hook, `get_current_event` / `event_get`, and the event bin pack carry the scroll source and the source device's type. A device type of `-1` means there is no device. `event_add_filter`'s actor field moved to index 9.

## Seen again

2026-10-04 11:02:24. Same login, `alan2`. Installed at 11:02:09: `/usr/bin/gsr-client` and `libmutter-clutter-rpc-16.so`. That `.so` exports `clutter_event_get_scroll_source` and `clutter_event_get_source_device`. This run has no `JS ERROR` and no `scroll_source` line.

The unit still loses: `gsr-server` 185144, `Failed to setup: Native backend mode needs to be session controller`. Desktop-file server 185140 stays up.

| PID | Trap | Last client lines |
| --- | --- | --- |
| 185375 | 11:02:29.877 | `QuickSettings` `mapped` is not writable, then Notifications activation. No JS error. |
| 186077 | 11:02:38.580 | `--disable-extensions`. Same chrome criticals, then `Failed to create file /run/user/1002/gnome-shell-disable-extensions: File exists` at 11:02:38.535. |

Both traps are `int3` in `libglib-2.0.so.0.8400.1` at offset `0x73e0f`, the same offset as the 09:42 abort. Server 185140, 26 ms before the first trap: `st_widget_get_theme_node` on `panelBox` which is not in the stage, then a null `g_signal_connect_object`. Same three lines at 11:02:38.593 for the second client.

`ApplicationInterface.debug_log` writes stderr only for debug or `LEVEL_CRITICAL`. A `GLib.error` is `LEVEL_ERROR`, so the abort string is not in the journal. `/var/crash/_usr_bin_gsr-client.1002.crash` is still the 09:42 file. No new core. How to make the next one readable: [`2026-10-04-fatal-log-dropped.md`](2026-10-04-fatal-log-dropped.md).

## Not done

- JS stacks for clients 161947 and 162066.
- Core in `/var/crash/_usr_bin_gsr-client.1002.crash` (needs `alan2` or root). The int3 frame is not confirmed beyond “2 ms after the JS error, inside glib”.

## Seen again — 2026-10-05 08:33

`alan2` from GDM. `--debug` is on the desktop file and the systemd unit. The shell did start. It died about two seconds later. The crash screen stayed up. Log Out on that screen, and Log Out left on the blank desktop after Emergency mode, did not return to GDM. Session 131 (leader 244339, tty4) was still active minutes later.

Two servers, same split as before:

| PID | Who started it | Result |
| --- | --- | --- |
| 244612 | desktop file | Stayed up. Painted the crash screen. |
| 244611 | `org.gnome.ShellRpc@wayland.service` | `Failed to setup: Native backend mode needs to be session controller`. Exited. |

First client 244821 got through theme, `DateMenuButton`, and `QuickSettings`. Then:

```text
08:33:17  gsr-server[244612]: connection write error: Unregistered class type schema: MetaRendererViewNative
08:33:17  gsr-client[244821]: Unexpected early end-of-stream
08:33:17  kernel: gsr-client[244821] trap int3 … libglib-2.0.so.0.8400.1+0x73e0f
08:33:18  gsr-server[244612]: client exited manual-restart=false
```

`write_reg_gtype` throws that string when `gtype_to_alias` has no entry for the object's exact GType (`libocrpc` `Bin/Stream.vala`). The parent alias does not cover a subclass. `Gi.register` maps `ClutterStageView`. `Gsr.Server.Clutter.register_alias` maps `meta_renderer_view_get_type()` (`MetaRendererView`) onto `Clutter-StageView`. On this greeter the live view is `MetaRendererViewNative`. The write of that view closes the socket. The client aborts on the short read. That is the crash screen.

A second client 245384 started at 08:33:20 (a Restart click) and trapped in the same glib offset at 08:33:22. The schema line was not in the slice kept for that pid. Do not treat that death as the same write until the line is there.

## Log Out

Both controls call `SpawnClient.on_crash_logout`. Nested mutter (`MetaBackendX11Nested`) calls `context.terminate()` and returns. Any other backend asks `org.gnome.SessionManager.Logout` with mode 1 and then returns. A failed call would `GLib.error` and the journal would contain `log out:`. The 08:33 journal has no such line, and the session was still up minutes later, so the call did not fail and did not end the display.

The shell is already dead. Nothing is left to handle the session manager's end-session and exit the compositor. The method has to exit this mutter after the logout request. Nested must still skip the request: that bus is the host session.

## Fix

`Gsr.Server.Clutter.register_alias` aliases `MetaRendererView` and, when mutter has already registered it, `MetaRendererViewNative`, both as `Clutter-StageView`. `meta_renderer_view_native_get_type` is not exported.

`on_crash_logout` still skips `Logout` on `MetaBackendX11Nested`. Otherwise it requests logout with a 2 second timeout, and then calls `context.terminate()` whether that request succeeded or not. A failed request is a warning, not an abort, so the terminate still runs.

## Seen again — 2026-10-05 09:09

User: the desktop came up, starting an app crashed, Log Out worked.

`gsr-server` 256483 stayed up. `gsr-client` 256685 got through startup. No `Unregistered class type schema` line. `gnome-session` entered the running state at 09:09:56.

During that startup, not the later crash: `Expected an object of type MetaWorkspace for argument 'workspace' but got type undefined`, then `Failed to setup quick settings` (`Unsupported type void` in `volume.js` `getMixerControl`). The shell was still up after those. `gsr-client` was already `--debug`. Another debug login will not fill in the missing abort line: the journal stopped recording that pid mid RPC flood at 09:09:58, thirteen seconds before the trap.

`n-workspaces` was logged not writable in the same second as the workspace error. `WorkspaceTracker` fills `_workspaces` from `notify::n-workspaces`. The read-only property dropped that update, so `remove_workspace` was passed undefined. The property now has a setter that stores the count and clears the index cache, which emits the notify.

`Gvc.MixerControl` is `libgvc.so` in `/usr/lib/gnome-shell`. `gsr-client`'s runpath did not include that directory, so the type came out void. The client runpath now includes the gnome-shell pkglibdir. 09:43 installed that binary and the void error remained: gjs dlopens `libgvc.so` by name, and that search does not use the executable runpath. The client spawn now puts the pkglibdir on `LD_LIBRARY_PATH`.

09:10:11, about fourteen seconds later: kernel `trap int3` for `gsr-client` 256685 in `libglib-2.0.so.0.8400.1` at offset `0x73e0f`. Same offset as the earlier aborts. The journal for that pid stops at 09:09:58 on `St-Bin.get_child`, mid RPC flood. No `Unexpected early end-of-stream`, no schema line, no `client exited` before the trap. The server pid has three journal lines for the whole login (`started`, the mutter banner, and nothing else).

Session scopes stopped at 09:10:27. That matches Log Out returning to GDM.

## Seen again — 2026-10-05 09:43

Installed `gsr-client` runpath includes `/usr/lib/gnome-shell` (mtime 09:43:07). User: first crash came quickly, the second after going back to pick an app. The second restart was with debug. Log Out on the crash screen was sluggish.

First client 266609 was spawned `--debug` at 09:43:23 because the server has `--debug`. `notify::n-workspaces` fired at 09:43:26. No `MetaWorkspace` / undefined error. Quick settings still failed: `Unsupported type void` in `getMixerControl`. Last journal line 09:43:28, still in theme RPCs. No kernel trap for this pid. The session agent dropped at 09:43:31. Next client 267404 is up by 09:43:38, same void error, and `trap int3` at 09:43:47. Same glib offset `0x73e0f`. No schema line and no end-of-stream line before it.

Host `gnome-shell` logged `Xwayland exited unexpectedly` at 09:44:21. That is the session leaving, about half a minute after the trap. `on_crash_logout` waits up to 2 seconds for `SessionManager.Logout`, then terminates the compositor. No `log out:` line.
