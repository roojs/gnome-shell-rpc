# Barrier construct setter runs before the lease

**Status:** ✔️ fixed — 2026-09-24 20:22 boot

`org.gnome.ShellRpc.debug.log` has no `no rpc_lid` and no empty `Meta-Barrier.new`. Three calls reply:

```text
id=2024 method=Meta-Barrier.new  replied id=2024
id=2026 method=Meta-Barrier.new  replied id=2026
id=2027 method=Meta-Barrier.new  replied id=2027
```

The 17:07 failure was construct setters calling `Meta-Barrier.set_property` before `rpc_lid` was set, then `.new` with no arguments (`-32602`). The generator now sends one `.new` with the property bag.
