# Launching a terminal closes the RPC socket, then the cursor sticks

**Status:** ✔️ closed 2026-09-30. `window_created` exports the window before `get_compositor_private` and `get_title`.

**Plan:** [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)

## What happened

The nest came up. Typing `ter` and a click at 18:49:41 started a terminal. About nine seconds later the pointer stopped moving in the nested window.

Mutter was still logging motion (`xwayland-relative-pointer`) until 18:50:01. The shell client was already gone.

## The drop

`mutter-rpc.debug.log` at 18:49:50.452:

```
connection write error: live object MetaWindowWayland not in connection.lease_ids
```

`Connection.write` closes the socket on that error. The client log ends at 18:49:50.500 with `Unexpected early end-of-stream`.

`window_created` is logged at 18:49:50.515, after the write error. The export in that handler was too late. `get_compositor_private` and `get_title` run before that log line, and the failed write sits in that gap. `StreamValue` requires the object to already be in `lease_ids`.

The same click also threw `clutter_event_get_device` (`undefined symbol` in `libmutter-clutter-rpc-16.so`) from `dnd.js` `_onButtonPress`. The launch continued after that. The freeze is the socket close.

A probe that walked every outgoing message leased the window, then the same `write` died on `unsupported bin value type 'GraphenePoint'`. That walk is not in the tree. `Connection.vala` has no extra methods.

## Fix

`src/rpc/Server.vala`. The existing `display.window_created` handler calls `connection.export(meta_window)` before `get_compositor_private`. The later `Window.created` write reuses that id.

`GraphenePoint` is packed as x, y in `src/rpc/helper/GraphenePointOverride.vala` and `src/shell-gi/GraphenePointOverride.vala`, same shape as `ActorBoxOverride`.
