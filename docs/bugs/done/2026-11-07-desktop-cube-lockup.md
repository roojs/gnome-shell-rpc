# Enabling desktop-cube locks the session

**Status:** ✔️ archived 2026-11-14. Fixed on the local mutter 16 client (`desktop-cube-lockup/ui/init: ok`). Later cube swipe work is [`../2026-11-14-desktop-cube-swipe-drag.md`](../2026-11-14-desktop-cube-swipe-drag.md).

Desktop Cube's patched `WorkspacesView._updateWorkspacesState` reads
`global.stage.perspective` while the overview is constructed. The
stock property getter is `Clutter-Stage.get_property`. The reply is a
raw `ClutterPerspective` `GValue`. The bin writer throws
`unsupported bin value type 'ClutterPerspective'`, the server closes
the connection, and the next `get_parent()` returns null. Cube then
throws at `extension.js:876` (`parent.set_child_at_index`). The
`no rpc_lid` dash errors are that dead connection.

`Stage.perspective` is denied on the client, and the override reads
it through `Clutter-Stage.get_perspective`, which already returns the
record as bytes. The stock `clutter_stage_get_perspective` symbol is
kept. Same edit in the mutter 16 and 18 client stubs. Server sources
are unchanged.

Reproduction, and the bar that passed:

```bash
GSR_NESTED_TIMEOUT=70 GI_META_SMOKE=desktop-cube-lockup/ui/init \
  ./scripts/agent-nested-smoke-prove.sh
```

`nested-weston-prove: stop (smoke-ok) after 15s`. Client log
`desktop-cube-lockup/ui/init: ok` with
`parent=[… GsrServerClutterActor.workspaces-view …]`. No
`ClutterPerspective` write error and no `parent is null`. The
script then kills Weston (shell exit 137). Before the client edit,
the same command was `stop (smoke-fail)` with
`desktop-cube-lockup/ui/init: miss TypeError: parent is null`.

`gsettings get org.gnome.shell enabled-extensions` is

```text
['apps-menu@gnome-shell-extensions.gcampax.github.com', 'desktop-cube@schneegans.github.com', 'ding@rastersoft.com']
```

Journal is `journalctl -b` for pid 127542. At 09:55:06 enabling
`desktop-cube@schneegans.github.com` logged:

```text
JS ERROR: TypeError: can't access property "set_child_at_index", parent is null
_depthSortCubeFaces@file:///home/alan/.local/share/gnome-shell/extensions/desktop-cube@schneegans.github.com/extension.js:876:7
enable/WorkspacesView.prototype._updateWorkspacesState@file:///home/alan/.local/share/gnome-shell/extensions/desktop-cube@schneegans.github.com/extension.js:255:21
```

`_depthSortCubeFaces` takes `actors[0].get_parent()` and calls
`parent.set_child_at_index`. `actors[0]` had no parent. The same
second the client logged a run of `no rpc_lid` on
`Gjs_ui_dash_DashItemContainer`, `DashIcon`, and `StLabel`, then:

```text
JS ERROR: TypeError: can't access property "connectObject", cache is null
_init@resource:///org/gnome/shell/ui/iconGrid.js:106:9
… _redisplay@resource:///org/gnome/shell/ui/dash.js:749:32
```

The client was still in `poll` at 09:55, not aborted.
`tests/gjs-embed/desktop-cube-lockup-smoke.js` enables the cube and
then shows the overview, which is the guest order:
`WorkspacesView._init` → `_updateWorkspaces` → the patched
`_updateWorkspacesState`.

Earlier in the same enable pass, 09:54:14, apps-menu logged
`property 'mapped' … ApplicationsButton is not writable`. From 09:54:18
DING printed `Launching DING process` about every 3 seconds. At
09:54:21 the client logged `this.layout_manager is null` on
`column_spacing`, four times. At 09:54:53, `can't access property
"toUpperCase", target is undefined`.

## LLM efforts

- 2026-11-07 09:55 HKT. User: one extension locked the session while
  they were enabling extensions. The DING abort and the window-gone
  wait are closed. `192.168.122.52` has no route. `ubuntu2604` is this
  session: server 127300 and client 127542 since 09:53:58, extensions
  apps-menu, desktop-cube, and ding. Journal for 127542 hits
  `desktop-cube` `extension.js:876` `parent is null` inside
  `_depthSortCubeFaces` from `enable` at 09:55:06, then the dash
  `no rpc_lid` criticals and `iconGrid.js` `cache is null`. Both
  processes still in `poll`. Did not edit `src/`.
- 2026-11-07. First nest, `GI_META_SMOKE=desktop-cube-lockup-smoke`
  with no `ui/init.js`, died in `main.start()`:
  `global.stage.context is null`, mutter ec=133. Not the cube throw.
- 2026-11-07. `GSR_NESTED_TIMEOUT=70 GI_META_SMOKE=desktop-cube-lockup/ui/init ./scripts/agent-nested-smoke-prove.sh`
  with the overview shown before enable. Log
  `workspaces=12 parent=[GsrServerClutterActor.workspaces-view]`
  and `extension-state=1`. The patched method never ran during
  `_init`. Nest then sat until the wall kill because the ok line
  was not in `SMOKE_OK_PAT`.
- 2026-11-07. Same command, enable then `overview.show()`. First
  attempt `extension-state=undefined` (map entry exists before
  `loadExtension` sets state). Second attempt
  `SyntaxError: redeclaration of let extension`. Third attempt
  `stop (smoke-fail)`:
  `desktop-cube-lockup/ui/init: miss TypeError: parent is null`
  at cube `extension.js:876` from `overview.show()`. Mutter log:
  `connection write error: unsupported bin value type 'ClutterPerspective'`
  on `Clutter-Stage.get_property` id=11914. Client:
  `Unexpected early end-of-stream`.
- 2026-11-07. Denied `Stage.perspective` in both `Clutter.deny`
  files and pointed the property getter at
  `Clutter-Stage.get_perspective`. First compile:
  `The name get_perspective does not exist` because the property
  deny also drops the method. Getter now calls the wire method
  and unpacks `response.args[0]` as bytes. Also exports
  `clutter_stage_get_perspective` so the stock GIR getter name
  still resolves. `nm -D` on
  `libmutter-clutter-rpc-16.so`: both
  `clutter_stage_get_perspective` and
  `stage_get_perspective_gprop`.
- 2026-11-07 11:52 and 11:54 HKT. Same prove command, twice, after
  the client rebuild. Both `stop (smoke-ok) after 15s`.
  `desktop-cube-lockup/ui/init: extension-state=1`,
  `workspaces=12 parent=[… GsrServerClutterActor.workspaces-view …]`,
  `desktop-cube-lockup/ui/init: ok`. No `parent is null` and no
  `ClutterPerspective` write error. Weston is killed afterwards
  (shell exit 137). Guest mutter 18 still has
  `clutter_stage_get_perspective` and a `perspective` property
  whose getter is `get_perspective`. The 18 stub has the same
  edit and was not installed on `ubuntu2604`.
- 2026-11-14. User: archive old desktop cube / icons / DING bugs. Moved to `docs/bugs/done/`.
