# A `GTask` is written on the bin connection

**User goal:** nested mutter-rpc + gnome-shell-rpc stays up and answers pointer and keyboard. From [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md).

**Status:** ✅ closed 2026-09-24. `Shell.Signals.connect` does not subscribe `init-xserver`. The 14:43 prove reached `READY=1` with no `GTask` write.

**Seen:** 2026-09-24 14:24:44. `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`.

```text
Connection.vala:213: connection write error: Unregistered class type schema: GTask
```

The client log at 14:24:44.531:

```text
Client.vala:701: Error receiving data: Connection reset by peer
```

## How it got on the wire

**🔷** `Meta.Display::init-xserver` takes one argument, a `Gio.Task`. Mutter emits it from `on_xserver_started` when Xwayland's server is up.

**🔷** The shell connects `global.display` to `init-xserver` and passes the task to `_startX11Services`. That `.connect` subscribed the server, and `Subscription.emit` tried to pack the task.

**✔️** `Shell.Signals.connect` returns without `RPC-Live-Subscribe.rpc_signal` for `init-xserver`. Mutter then completes the task itself. `_startX11Services` does not run.
