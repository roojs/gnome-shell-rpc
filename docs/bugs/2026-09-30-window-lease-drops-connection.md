# Launching a terminal closes the RPC socket, then the cursor sticks

**Status:** ⏳ open. User 2026-09-30. Session `~/.cache/gnome-shell-rpc/`. Weston started 18:48.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

## What happened

The nest came up. Typing `ter` and a click at 18:49:41 started a terminal. About nine seconds later the pointer stopped moving in the nested window.

Mutter was still logging motion (`xwayland-relative-pointer`) until 18:50:01. The shell client was already gone.

## The drop

`mutter-rpc.debug.log` at 18:49:50.452:

```
connection write error: live object MetaWindowWayland not in connection.lease_ids
```

`Connection.write` closes the socket on that error. The client log ends at 18:49:50.500 with `Unexpected early end-of-stream`.

`window_created` is logged at 18:49:50.515, after the write error. The export in that handler is too late. Something else serialized the new window first (a display signal such as `notify::focus-window`). `StreamValue` requires the object to already be in `lease_ids`.

The same click also threw `clutter_event_get_device` (`undefined symbol` in `libmutter-clutter-rpc-16.so`) from `dnd.js` `_onButtonPress`. The launch continued after that. The freeze is the socket close.

A probe that walked every outgoing message leased the window, then the same `write` died on `unsupported bin value type 'GraphenePoint'`. That walk is not in the tree. `Connection.vala` has no extra methods.

## Suggested code

`src/rpc/Server.vala`, the existing `display.window_created` handler. Export the window before `get_compositor_private` and `get_title`. Those run before the `window_created` log line, and the failed write sits in that gap. `export` is already called later in this handler for `Window.created`; calling it first reuses that id.

```vala
display.window_created.connect((meta_window) => {
    if (this.listen != null) {
        foreach (var connection in this.listen.connections) {
            connection.export(meta_window);
        }
    }
    if (!this.window_actor_aliased) {
```

In `src/rpc/Server.vala`.

`GraphenePoint` is a second `write` that closes the socket, seen while laying out the new window clone. `src/rpc/helper/GraphenePointOverride.vala` and `src/shell-gi/GraphenePointOverride.vala` are already in the tree and registered. Same shape as `ActorBoxOverride`: pack x, y as two doubles.
