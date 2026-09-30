# `notify::allocation` sets a property that is not writable

**Status:** ✔️ archived 2026-09-30 — taken off the board with [`2026-09-28-allocation-two-paths.md`](2026-09-28-allocation-two-paths.md). Live UI is [`../2026-09-30-overview-boot-flicker.md`](../2026-09-30-overview-boot-flicker.md).

**Seen:** `org.gnome.ShellRpc.debug.log`. The connection stays up. No `unsupported bin value type`, no early end-of-stream.

`Clutter.ActorBox` is packed as four doubles (`src/rpc/helper/ActorBoxOverride.vala`, `src/shell-gi/ActorBoxOverride.vala`). The client then applies the notify with `set_property`. `allocation` is read-only, so each notify logs:

```text
notification method=notify::allocation
g_object_set_is_valid_property: property 'allocation' of object class 'StWidget' is not writable
```

Same critical for `StBoxLayout` (four times) and `Gjs_ui_layout_HotCorner`. Six `notify::allocation` lines, six criticals. `notify::visible` and `notify::checked` in the same boot do not log that critical.

Also in this boot, and not this bug:

- `Meta-Display.get_focus_window` then `g_value_get_object: assertion 'G_VALUE_HOLDS_OBJECT (value)' failed` (client, twice). Server at the same moment: `type id '0' is invalid`.
- `St-DrawingArea.get_surface_size`: `assertion 'priv->in_repaint' failed` (twice). The next `Clutter-Actor.allocate` still runs.
