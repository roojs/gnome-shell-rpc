# Desktop Icons shows as gjs, and the cube swipe does not rotate

**Status:** Open on the installed guest. On this mutter 16 client both remaining throws now pass.

The footer `gjs` name: `Shell.App` counts windows that are not `skip-taskbar`. Weston today:

```text
gjs-app-skip: name=GTK Demo before=2 after=0 listed=false skip=true
gjs-app-skip: ok
nested-weston-prove: stop (smoke-ok) after 1s
```

`before=2` is `AppState.RUNNING`. After `skip_taskbar = true` the app is `STOPPED` and `get_running()` drops it. That is `src/client/libshell-16/App.vala`. The 09:53 run was `after=2 listed=true` and this count was not installed on the guest.

The cube: `actors[0].get_parent()` is null when `Stage.perspective` is read as a raw `ClutterPerspective` and the bin writer closes the connection. The getter in `Stage.override.vala` reads `Clutter-Stage.get_perspective` instead. Weston today:

```text
desktop-cube-lockup/ui/init: workspaces=6 parent=[… GsrServerClutterActor.workspaces-view …]
desktop-cube-lockup/ui/init: ok
nested-weston-prove: stop (smoke-ok) after 16s
```

The guest log at 08:51:25 still has `parent is null` on a client that already exported `stage_get_perspective_gprop`. This client's smoke does not reproduce that null parent.

Desktop Icons still launched twice on the guest at 09:37 (09:37:24 and 09:37:27). That second launch is not these two smokes.

Logs: `/var/log/syslog`. `~/.cache/gnome-shell-rpc/` was last written 2026-11-05. The installed session does not pass `--debug`, so it does not truncate those files. No `gsr-client` or `gsr-server` core under `/var/lib/systemd/coredump/`.

Session 1, 12:31:14–12:32:46. `gsr-server` 25000, `gsr-client` 25571. `GNOME Shell started` at 12:31:16. `Launching DING process` at 12:31:31. `Received notification for window. 0 notifications remaining.` at 12:31:34. Ended because `gdm.service` was stopped. Peak 8.3G, 4min 23s CPU.

Session 2, 12:33:08–12:33:38. `gsr-server` 34906, `gsr-client` 35452. Shell started at 12:33:11. DING at 12:33:20, claimed at 12:33:21. `gnome-session-wayland@gsr.target` stopped and the login returned to the greeter. Peak 460.6M.

The core at 12:31:01 is stock `/usr/bin/gnome-shell` pid 9739, signal 6. `org.gnome.Shell@x11.service` exited `code=dumped, status=6/ABRT`. Apport file `/var/crash/_usr_bin_gnome-shell.1001.crash`. Core `core.gnome-shell.1001.d0f04ebc44e34f4aac2829de063949b8.9739.*`. Stack top is `g_assertion_message_expr` in `libglib-2.0.so.0`, then `libmutter-16.so.0`, then `g_object_run_dispose`. That X11 session died immediately before the first GSR login.

`st_icon_info_load_symbolic_async` is in the build of `libst-rpc-16.so` (`nm -D` shows `T`). `IconInfo.override.vala` runs `load_symbolic` and completes a `GLib.Task`. `load_symbolic_finish` reads that task. The installed `/lib/x86_64-linux-gnu/libst-rpc-16.so` is still the 12:30 library, which does not export the symbol. The gate `tests/call-sync-repro/symbolic-icon-async-gate` printed `symbolic-icon-async: ok`.

Both GSR sessions, from `appindicatorsupport@rgcjonas.gmail.com` and `ubuntu-appindicators@ubuntu.com`:

```text
Could not locate st_icon_info_load_symbolic_async: 'st_icon_info_load_symbolic_async': /lib/x86_64-linux-gnu/libst-rpc-16.so: undefined symbol: st_icon_info_load_symbolic_async
```

Stock `/usr/lib/gnome-shell/libst-16.so` exports `st_icon_info_load_symbolic_async`. The installed `/lib/x86_64-linux-gnu/libst-rpc-16.so` (12:30) exports `st_icon_info_load_symbolic` and `st_icon_info_load_symbolic_finish` and not the async symbol. The name is still in the temporary block of `src/client/libst-rpc-16/St.deny`. `st_icon_info_load_symbolic_finish` calls `gsr_client_rpc_call_value`.

`Shell.App.state` follows `interesting_windows`. The 09:53 Weston miss is still the one on record (`gjs-app-skip: miss name=GTK Demo after=2 listed=true`). Not re-run after these sessions. The guest 09:37 account is unchanged: title notify is in, one `ding.js` was claimed, the footer still showed one `gjs` app, and DING launched twice there (09:37:24 and 09:37:27).

Weston command for the footer name:

```bash
GSR_NESTED_STAYUP=0 GSR_NESTED_TIMEOUT=30 GI_META_SMOKE=gjs-app-skip \
  ./scripts/agent-nested-smoke-prove.sh
```

`Meta.Window.title` now accepts the notify write on the mutter 16 client. Weston:

```bash
GSR_NESTED_STAYUP=0 GSR_NESTED_TIMEOUT=30 GI_META_SMOKE=window-title-set \
  ./scripts/agent-nested-smoke-prove.sh
```

`nested-weston-prove: stop (smoke-ok) after 1s`. Client log `window-title-set: title=Desktop Icons 1 notified=true` then `window-title-set: ok`. Before the setter the same command was `stop (smoke-fail)` with `window-title-set: miss Property MetaWindow.title is not writable`.

The guest `libmutter-rpc-18.so` and `mutter-rpc-18/Meta-18.typelib` were installed from the guest build at 09:07 and `org.gnome.ShellRpc@wayland.service` was restarted. New session 09:08:02, `gsr-server` 5210, `gsr-client` 5232. Shell started. By 09:08:46 there was no `Launching DING process` and no `title` reject. The second DING launch and the cube `parent is null` throw are not fixed.

DING launched at 08:50:58 and again at 08:51:01. One process remains:

```text
gjs /usr/share/gnome-shell/extensions/ding@rastersoft.com/app/ding.js -E -P /usr/share/gnome-shell/extensions/ding@rastersoft.com/app
```

Each launch logs `property 'title' of object class 'MetaWindow' is not writable`. The server, at the same two moments, logs `g_subprocess_get_if_exited: assertion 'pid == 0' failed` four times. The second launch then logs `Received notification for window. 0 notifications remaining.`

`Meta.Window.title` in Meta-18.gir is get-only (`getter="get_title"`, no setter). The server sends `notify::title` and the client applies it with `set_property`. That write is rejected, so `notify::title` does not run. DING's `EmulateX11WindowType` connects `notify::title` and calls `_parseTitle()`, which is what calls `hide_from_window_list` when the title starts with `Desktop Icons `. The window stays a normal window and the shell lists it as the `gjs` process.

The cube, at 08:51:25, from the panel overview toggle:

```text
JS ERROR: TypeError: can't access property "set_child_at_index", parent is null
_depthSortCubeFaces@file:///home/alan/.local/share/gnome-shell/extensions/desktop-cube@schneegans.github.com/extension.js:876:7
enable/WorkspacesView.prototype._updateWorkspacesState@.../extension.js:255:21
_updateWorkspaceMode@resource:///org/gnome/shell/ui/workspacesView.js:327:14
```

`actors[0].get_parent()` is null, so the cube update throws and the faces are not rotated. The installed clutter client already has `stage_get_perspective_gprop`. This throw is not the earlier `ClutterPerspective` disconnect.

## LLM efforts

- 2026-11-10 08:14. Previous session 08:06 (`gsr-client` 164273) had the same two `Launching DING process` lines, the same `title` reject, and the same `parent is null` stack from the panel overview toggle. `get_if_exited` asserted `pid == 0` on the server at each launch. The guest was then shut off.
- 2026-11-10 08:50. Started `ubuntu26.04`. New session 08:50:53. Same DING pair, same title reject, same cube stack at 08:51:25. One `ding.js` left, pid 3877.
- 2026-11-10 08:59. `GSR_NESTED_TIMEOUT=30 GI_META_SMOKE=window-title-set ./scripts/agent-nested-smoke-prove.sh`. `window-title-set: miss Property MetaWindow.title is not writable`. `stop (smoke-fail) after 1s`.
- 2026-11-10 09:00. Setter on `Window.title` in both overrides, denied in both `Meta.deny` files. `ninja -C build src/gsr-smoke`. Same smoke, `GSR_NESTED_STAYUP` still 1 from the shell: `window-title-set: ok`, then `stop (timeout) after 30s` because `window-title-set: ok` was not in the prove pattern.
- 2026-11-10 09:02. Added `window-title-set: ok` to the prove pattern. `GSR_NESTED_STAYUP=0` same smoke: `window-title-set: title=Desktop Icons 1 notified=true`, `window-title-set: ok`, `stop (smoke-ok) after 1s`.
- 2026-11-10 09:07. Copied the 18 override and `Meta.deny` to the guest checkout and built `libmutter-rpc-18.so` and `Meta-18.typelib` there. Installed both and restarted `org.gnome.ShellRpc@wayland.service`. Pids 5210 / 5232. `GNOME Shell started` at 09:08:04. No DING line and no `title` reject by 09:08:46. `column_spacing` / `layout_manager is null` still logs four times.
- 2026-11-10 09:37. User session after the title install. `gsr-server` 10236, `gsr-client` 10477. `Launching DING process` at 09:37:24 and 09:37:27. `g_subprocess_get_if_exited: assertion 'pid == 0' failed` four times at each of those stamps. `Received notification for window. 0 notifications remaining.` at 09:37:28 only. No `property 'title' … is not writable`. One `ding.js` pid 11013, started 09:37:27. `too much recursion` at 09:37:56 from `emulateX11WindowType.js:412` `_refreshWindows` → `Main.activateWindow`.
- 2026-11-10 09:53. `GSR_NESTED_STAYUP=0 GSR_NESTED_TIMEOUT=30 GI_META_SMOKE=gjs-app-skip ./scripts/agent-nested-smoke-prove.sh`. Client log `gjs-app-skip: name=GTK Demo before=2 after=2 listed=true skip=true` then `gjs-app-skip: miss name=GTK Demo after=2 listed=true`. `AppState.RUNNING` is 2. `skip_taskbar` is true and `get_running()` still contains the app.
- 2026-11-10 10:11. User stopped. Both remaining issues are open: doubled desktop icons, and one `gjs` still registered in the footer. The `Shell.App` skip-taskbar count in `src/client/libshell-16/App.vala` was not proven after the 09:53 miss and was not installed on the guest.
- 2026-11-10 14:00. This host, `/var/log/syslog`. Two GSR sessions, 12:31:14 (`gsr-client` 25571) and 12:33:08 (`gsr-client` 35452). Debug cache untouched since 2026-11-05. No gsr core. Session 1 ended on `Stopping gdm.service` at 12:32:46, peak 8.3G. Session 2 ended at 12:33:38 when the session target stopped, peak 460.6M. Stock `gnome-shell` pid 9739 dumped core at 12:31:01 (`status=6/ABRT`) before the first GSR login. Each GSR session logged one `Launching DING process` and one `Received notification`. Both logged `undefined symbol: st_icon_info_load_symbolic_async` from the two appindicator extensions. `nm -D` on the installed `libst-rpc-16.so` has `st_icon_info_load_symbolic` and `st_icon_info_load_symbolic_finish` and not `st_icon_info_load_symbolic_async`. Stock `libst-16.so` has all three.
- 2026-11-10 14:55. `timeout 5 ./build/tests/call-sync-repro/symbolic-icon-async-gate` printed `symbolic-icon-async: ok`. Copied that task pair into `src/client/libst-rpc-16/overrides/IconInfo.override.vala`. Denied `IconInfo.load_symbolic_finish` so the generated RPC finish is not linked. `ninja -C build src/client/libst-rpc-16/libst-rpc-16.so`. `nm -D` shows `T st_icon_info_load_symbolic_async`. Header is `StIconInfo*`, `StIconColors*`, `GCancellable*`, `GAsyncReadyCallback`, `gpointer`.
- 2026-11-10 14:59. `GSR_NESTED_STAYUP=0 GSR_NESTED_TIMEOUT=30 GI_META_SMOKE=gjs-app-skip ./scripts/agent-nested-smoke-prove.sh`. `gjs-app-skip: name=GTK Demo before=2 after=0 listed=false skip=true`, `gjs-app-skip: ok`, `stop (smoke-ok) after 1s`.
- 2026-11-10 15:00. `GSR_NESTED_TIMEOUT=70 GI_META_SMOKE=desktop-cube-lockup/ui/init ./scripts/agent-nested-smoke-prove.sh`. `workspaces=6 parent=[… GsrServerClutterActor.workspaces-view …]`, `desktop-cube-lockup/ui/init: ok`, `stop (smoke-ok) after 16s`.
