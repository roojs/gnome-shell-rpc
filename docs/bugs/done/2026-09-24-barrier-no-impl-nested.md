# Nested Wayland has no Meta.Barrier implementation

**Status:** ✔️ construct succeeds — 2026-09-24 20:22. Warning remains.

`Meta-Barrier.new` uses `GLib.Object.new(typeof(Meta.Barrier), ...)` in `src/rpc/helper/Barrier.vala`. That skips `GInitable`, so "Failed to create barrier impl" does not run. Ids 2024, 2026, and 2027 reply. The client keeps going.

Mutter still logs, three times:

```text
(../src/backends/meta-barrier.c:258):init_barrier_impl: runtime check failed: (priv->impl)
```

Nested Wayland is not the native backend and is not the X11-only branch, so `priv->impl` stays null. `release` / `is_active` no-op. `hit` and `leave` do not fire. A Vala subclass on the wire is an unregistered schema and drops the socket. Do not put a no-op impl in Mutter C.
