# A `GTask` is written on the bin connection

**User goal:** nested mutter-rpc + gnome-shell-rpc stays up and answers pointer and keyboard. From [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md).

**Status:** ⏳ open

**Seen:** 2026-09-24 14:24:44. `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`.

```text
Connection.vala:213: connection write error: Unregistered class type schema: GTask
```

The client log at 14:24:44.531:

```text
Client.vala:701: Error receiving data: Connection reset by peer
```

The `handler_id > 0` lines after that are teardown. This is not the earlier `ClutterEvent` write. That type is now packed as fields (`docs/bugs/done/2026-09-24-signal-register-forward-override.md`).

## Existing flow

```text
mutter-rpc write
  -> Bin.Stream.write_reg_gtype
  -> gtype_to_alias has no GTask
  -> StreamError.REGISTRATION
  -> connection reset
```

The throw is `libocrpc/Bin/Stream.vala` `write_reg_gtype`. It runs for an object `GType` that was never passed to `Bin.register` / `Gi.register`.

The last recv lines before the write are a run of `St-Button.new`, `St-Button.set_label`, `St-Widget.set_can_focus`, `Clutter-Actor.get_text_direction`, and `RPC-Live-Subscribe.rpc_signal`. The log does not name which value was the `GTask`.

## How it got on the wire

**🔷** `Meta.Display::init-xserver` takes one argument, a `Gio.Task` (`G_TYPE_TASK`). Mutter emits it from `on_xserver_started` when Xwayland's server is up, and passes that task:

```c
g_signal_emit (display, display_signals[INIT_XSERVER], 0, task, &retval);
```

`src/core/display.c` around the `INIT_XSERVER` emit. The return is a `gboolean`. The shell handler is expected to return `true` if it will complete the task itself.

**🔷** The shell connects it:

```js
global.display.connect('init-xserver', (display, task) => {
    IBusManager.getIBusManager().restartDaemon(['--xim']);
    this._startX11Services(task);
    return true;
});
```

That `.connect` is `Shell.Signals.connect` → `RPC-Live-Subscribe.rpc_signal`. The server closure is `Subscription.emit`, which packs every argument. The task is a live object, so `Stream.write_gtype` runs before the lease check and throws `Unregistered class type schema: GTask`.

**🔷** The 14:24 recv lines are shell UI (`St-Button.new`) still in flight. Xwayland start is interleaved with that. The button calls are not the value being written.

**🚫** Registering `GTask` as a bin class. The task is the server's async handle for X11 init. The client cannot complete it through a lease.

## Next

**✔️** `Shell.Signals.connect` returns without `RPC-Live-Subscribe.rpc_signal` for `init-xserver`. No server handler means mutter's `on_xserver_started` takes the `retval == false` path and completes the task itself. The shell's `_startX11Services` handler does not run.
