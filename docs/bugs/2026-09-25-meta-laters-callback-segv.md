# `Meta.Laters` callback intermittently SIGSEGVs in GJS

**Status:** ⏳ open — reproduced twice on 2026-09-25 while trying to take the delayed overview snapshot.

**Plan:** [`0.8 init and interaction`](../plans/0.8-init-complete-and-interaction.md)

## Seen

Two full-shell probe runs reached `READY=1`, then `gnome-shell-rpc` died with SIGSEGV before the delayed overview snapshot:

```text
16:09:55 READY=1
16:09:58 gnome-shell-rpc SIGSEGV

16:17:00 READY=1
16:17:01 gnome-shell-rpc SIGSEGV
```

Both deaths are inside a stored `GLib.SourceFunc` that `run_before_redraw()` invoked from `ClutterStage::before-update`. The second stack was:

```text
g_type_is_a
libgjs
libffi
meta_laters_run_before_redraw
ClutterStage::before-update
shell_signals_emit
oll_mrpc_client_dispatch_message
```

The first core took the same path, but the `before-update` notification arrived nested, while `Clutter.Actor.is_mapped` was still in a sync poll. The second core was the ordinary main-loop dispatch.

`entry.func()` is a `GLib.SourceFunc`. GJS implements that as a C trampoline whose data pointer is the closure: the JavaScript function, plus the GObject that function was bound to (`this` on a `BEFORE_REDRAW` callback from `layout.js`, `workspaceThumbnail.js`, `dash.js`, or `Main.initializeDeferredWork`). `g_type_is_a` is the trampoline checking that GObject. The pointer is still non-null and the closure’s refcount was 2, but the GObject has already been destroyed, so the type check crashes.

GDB on the second core showed pending later id 6 still in our map. `LaterEntry` is only `func` and `when`. The function, data pointer, and destroy-notify GDB printed are the GJS closure, not fields we store, and not stock mutter’s `MetaLater`.

Nothing in the shell path watches a GJS object for destruction. `Shell.Signals` unsubscribes only on `disconnect` / `disconnect_id`, and the first `connect` does `proxies.set`, which keeps the client object. There is no “this lease is dead, drop anything further” mark. A later notification for that lease is still dispatched, and a `Laters` callback is still invoked. Stock GJS invalidates closures when the bound GObject is disposed. We never tell our layer that happened, so it keeps handing the dead object to GJS.

The flood of `instance ... has no handler with id ...` starts after the shell client dies, during teardown. It is not the initiating failure.

`workarea-panel-chrome-smoke` registers one `BEFORE_REDRAW` callback and still passes. The full shell had four pending callbacks in the crashing dispatch. The nested `is_mapped` poll only explains how the first core re-entered `run_before_redraw`. The second core died without that nest.

## Rejected

Two table tweaks were tried and the full shell still SIGSEGVed. Neither remains in the source.

- A reentrancy guard around `run_before_redraw()`.
- Holding finished entries until the whole callback snapshot returned.

Those assume the crash is the queue freeing or re-entering a closure. The closure for id 6 was still alive. Patching the queue again, or writing a gate that replays “several closures plus a deferred-work drain”, models a queue bug we have not seen.

## Next

Detect destruction of the GJS object and tell this layer to ignore anything further for that lease: signal notifications and `Laters` callbacks included. Naming later id 6’s JavaScript function only identifies which destroyed object the trampoline touched. Do not patch the `Laters` queue again.

This crash blocks the 15-second actor snapshot for [`overview picker`](2026-09-24-overview-picker-preview-gone.md). It does not replace that bug as the current UI target.
