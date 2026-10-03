# Opening a window kills the shell client

**Status:** ✔️ fixed in libocrpc 2026-10-03. Found while proving [`../../plans/1.2-teardown-and-restart.md`](../../plans/1.2-teardown-and-restart.md).

## Seen

Nested stay-up session, shell started, then `WAYLAND_DISPLAY=wayland-mutter-gsr weston-terminal`. The client dies within a second of the window opening. Server log:

```text
14:32:18.195405 Connection.vala:228: connection write error: live object MetaWindowWayland not in connection.lease_ids
14:32:18.224487 Client.vala:702: Unexpected early end-of-stream
14:32:18.251258 Server.vala:163: window_created title=(null) frame=0,0 0x0 minimized=false
```

The write error comes before our `window_created` handler runs. That handler is where the server exports a new window to each connection.

Before 1.2 this took the server down too. With 1.2, the server tears the session down and spawns a new client.

## Cause

`OLLMrpc.Live.Subscription.emit` (`libocrpc/Live/Subscription.vala`) packs the signal parameters with `TypeOverride.pack_params` and writes them as they are. With `live_handles`, `Bin/StreamValue.vala` needs every non-Serializable GObject to be in `connection.lease_ids`. If it is missing, StreamValue throws `StreamError.PROTOCOL`. `Transport.Connection.write` catches that and calls `stop()`.

Mutter emits signals the shell subscribes to (workspace `window-added`, display `window-entered-monitor`) while the new `Meta.Window` is still being constructed. `Meta.Display::window-created` comes later. The server has no earlier hook where it could export the window.

Filed on OLLMchat: `~/gitlive/OLLMchat/docs/bugs/2026-10-03-subscription-emit-unexported-object-arg.md`.

## Gate

`tests/call-sync-repro/subscribe-unexported-object-arg-gate.vala`. The server makes a `Peer` and the client subscribes to `spawned(Child)`. The server then emits it with a `Child` it never exported.

```text
meson compile -C build
timeout 8 ./build/tests/call-sync-repro/subscribe-unexported-object-arg-gate
```

- 2026-10-03 before the fix: **FAIL** (`live object Child not in connection.lease_ids`, then end-of-stream).
- 2026-10-03 after the libocrpc update: **PASS** (`spawned=true args=1`, ping ok). `subscribe-signal-args-gate`, `subscribe-boxed-signal-arg-gate`, `subscribe-notify-args-gate` still PASS.

## Live after the fix

16:37 nested: `weston-terminal` opened after `GNOME Shell started`. One client spawn, no write error, and the workspace thumbnail picked up the window.
