# Dragging an overview window between workspaces does not work

**Status:** Guest `alan@192.168.122.115` session pid 14554. Opening the overview makes each window preview construct `St.DndStartGesture` with `rpc_lid == 0`. The generated setters then throw, so `add_action` never attaches the gesture and a later drag cannot start.

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

`Clutter-ClickGesture.new` and `Clutter-LongPressGesture.new` lease in the same construction. The existing `Gsr-St-DndStartGesture` peer only registers the two event getters; it has no `create`.

This host is mutter 16 / Shell 48. Its `dnd.js` still uses `button-press-event`. Weston here is not this failure.

A mapped window on the regular desktop is a different path: mutter move grab or a content / clipboard drag, not `St.DndStartGesture`. That report is [`2026-11-04-desktop-window-drag-between-workspaces.md`](2026-11-04-desktop-window-drag-between-workspaces.md).

## Reproduction

Installed session on `alan@192.168.122.115`. Open the overview with a window present. The criticals are at preview construction, before the hand drag.

```bash
# API 18 only
meson test -C build st-dnd-start-gesture-lease --print-errorlogs
```

## LLM efforts

- 2026-11-04 10:09. User reported that dragging a window between workspaces in the overview is not working. Opened this report before investigation.
- 2026-11-04 10:10. Read the guest client log for the installed session (client pid 14554). The Applications crash is closed; the next failure is these `StDndStartGesture` `no rpc_lid` criticals while each preview calls `makeDraggable`.
- 2026-11-04 10:17. Guest GJS `new St.DndStartGesture({ manual_mode: false, timeout_threshold: 0 })` against the installed RPC St-18 typelib prints the same two criticals. GJS does not turn them into an exception; the object is left with no lease. `st-dnd-start-gesture-lease-gate.js` is that construct.
- 2026-11-04 14:35. User also could not drag a mapped window between workspaces on the normal desktop, and asked whether the clipboard took the gesture. That is not this `St.DndStartGesture` construct. Opened [`2026-11-04-desktop-window-drag-between-workspaces.md`](2026-11-04-desktop-window-drag-between-workspaces.md). Guest SSH from here was `No route to host`.
