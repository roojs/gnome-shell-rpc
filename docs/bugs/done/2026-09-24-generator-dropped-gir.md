# Generator dropped GIR construct properties and interfaces

**Status:** ✔️ fixed — 2026-09-24 20:22 boot

`org.gnome.ShellRpc.debug.log` has no `JS ERROR`. Absent:

```text
Property MetaBarrier.backend is not writable
Object is of type St.Bin - cannot convert to ClutterAnimatable
```

Those were the 16:34 failures: `Meta.Barrier.backend` emitted get-only, and `St.Widget` missing `Clutter.Animatable`. `Meta-Barrier.new` replies at 20:22:02.
