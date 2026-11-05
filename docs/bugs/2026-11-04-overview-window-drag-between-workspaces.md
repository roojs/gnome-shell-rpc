# Dragging an overview window between workspaces does not work

**Status:** Guest on this machine is `alan@192.168.122.115` (`ubuntu2604`, mutter 18 / Shell 50.1). User 08:29 rebuilt, installed, and dragged an overview window. Session `gsr-server` 26381 / `gsr-client` 26629, binaries 08:29:28. Drag still does not start. Client log `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` at 08:29:46 and again at 08:29:54 / 08:29:56 / 08:30:05, while `WindowPreview` is built:

```text
RPC St-DndStartGesture.set_manual_mode: no rpc_lid on StDndStartGesture
RPC St-DndStartGesture.set_timeout_threshold: no rpc_lid on StDndStartGesture
RPC Clutter-Actor.add_action: no rpc_lid on StDndStartGesture
RPC Clutter-Gesture.can_not_cancel: no rpc_lid on StDndStartGesture
```

The same second logs `Clutter-ClickGesture.new` and `Clutter-LongPressGesture.new`. Nothing calls `Gsr-St-DndStartGesture.create` from that session. The running server has no handler for it (`RPC dispatch: no handler` at 08:42:04 when the gate did call create). Desktop window drag is the other report.

This is not the closed 2026-10-14 pick-hidden leftover-preview bug. `Gsr-Clutter-Actor.hidden` already ran at 10:08:25.146 before the first throw.

## Diagnosis

Shell 50 `vendor/gnome-shell/js/ui/dnd.js` constructs:

```js
this._dndGesture = new St.DndStartGesture({
    manual_mode: params.manualMode,
    timeout_threshold: params.timeoutThreshold,
});
this.actor.add_action(this._dndGesture);
```

The generated `St.DndStartGesture` has no lease construct. The GIR type has no `new`. `manual_mode` and `timeout_threshold` RPC immediately. Guest client log `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` at 10:08:25.150:

```text
RPC St-DndStartGesture.set_manual_mode: no rpc_lid on StDndStartGesture
RPC St-DndStartGesture.set_timeout_threshold: no rpc_lid on StDndStartGesture
RPC Clutter-Actor.add_action: no rpc_lid on StDndStartGesture
RPC Clutter-Gesture.can_not_cancel: no rpc_lid on StDndStartGesture
```

`Clutter-ClickGesture.new` and `Clutter-LongPressGesture.new` lease in the same construction. The 08:29 server's `Gsr-St-DndStartGesture` peer only registers the two event getters. This tree now has `create` (`g_object_new` of `StDndStartGesture`) and a client construct that stashes the two properties and sends them with that call. The running session has not loaded it.

This host is mutter 16 / Shell 48. Its `dnd.js` still uses `button-press-event`. Weston here is not this failure.

A mapped window on the regular desktop is a different path: mutter move grab or a content / clipboard drag, not `St.DndStartGesture`. That report is [`2026-11-04-desktop-window-drag-between-workspaces.md`](2026-11-04-desktop-window-drag-between-workspaces.md).

## Reproduction

Installed session on `alan@192.168.122.52`. Open the overview with a window present. The criticals are at preview construction, before the hand drag.

```bash
# API 18 only
meson test -C build st-dnd-start-gesture-lease --print-errorlogs
```

## LLM efforts

- 2026-11-04 10:09. User reported that dragging a window between workspaces in the overview is not working. Opened this report before investigation.
- 2026-11-04 10:10. Read the guest client log for the installed session (client pid 14554). The Applications crash is closed; the next failure is these `StDndStartGesture` `no rpc_lid` criticals while each preview calls `makeDraggable`.
- 2026-11-04 10:17. Guest GJS `new St.DndStartGesture({ manual_mode: false, timeout_threshold: 0 })` against the installed RPC St-18 typelib prints the same two criticals. GJS does not turn them into an exception; the object is left with no lease. `st-dnd-start-gesture-lease-gate.js` is that construct.
- 2026-11-04 14:35. User also could not drag a mapped window between workspaces on the normal desktop, and asked whether the clipboard took the gesture. That is not this `St.DndStartGesture` construct. Opened [`2026-11-04-desktop-window-drag-between-workspaces.md`](2026-11-04-desktop-window-drag-between-workspaces.md). Guest SSH from here was `No route to host`.
- 2026-11-04 18:05. User: drag-drop has not changed one iota. Live session is still the 14:32 `/usr/bin/gsr-server`. `Gsr-St-DndStartGesture` still has getters only (no `create`). Client override has no construct/`rpc_lid`. Gate still EXPECTEDFAIL. Desktop `recognize`/`may-recognize` blocking landed in this tree only and is a different path.
- 2026-11-05 08:28. This machine's Ubuntu guest is `192.168.122.115` (`ubuntu2604`). `192.168.122.52` does not answer. Read the 08:29 session the user just installed and dragged in. Same four `no rpc_lid` lines at preview construction. `ClickGesture.new` is on the wire; `DndStartGesture` create is not. Mutter log has zero `DndStart` lines for that drag.
- 2026-11-05 08:42. Client construct stashes `manual-mode` / `timeout-threshold` and calls `Gsr-St-DndStartGesture.create`. Server `create` is `g_object_new(StDndStartGesture)` with those two properties. Guest build of `libst-rpc-18` and `gsr-server` succeeded. Gate against the still-running 08:29 server: `recv method=Gsr-St-DndStartGesture.create` then `no handler`, gate `miss create failed`, no SIGSEGV. That server is not this binary. Not installed over `/usr/bin/gsr-server`.
- 2026-11-05 09:10. Walked Shell 50 `dnd.js` and `windowPreview.js` from the guest `libshell-18.so` against this tree. The only hole on that path is the lease. `create` is in this tree. `recognize` is already blocking on `Gsr-Clutter-Actor.add_signals`. `get_point_begin_event` / `get_drag_triggering_event` pack through `reply_event`, and the client event keeps coords and time. `get_sprite`, `get_grab_actor`, `set_cursor_type`, `can_not_cancel`, `get_transformed_extents`, and `change_workspace_by_index` / `move_to_monitor` are already stubbed. `start_drag` has no Shell 50 JavaScript caller. `manual-mode` and `timeout-threshold` are not construct properties, so `g_object_new` applies them after `create`; the override setters then send the real values (including `timeoutThreshold: 200`). The 08:29 session still does not have this binary.
