# Desktop Icons shows as gjs, and the cube swipe does not rotate

**Status:** `Meta.Window.title` now accepts the notify write on the mutter 16 client. Weston:

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
