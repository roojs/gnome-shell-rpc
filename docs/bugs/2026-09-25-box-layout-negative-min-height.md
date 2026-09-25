# `ClutterBoxLayout` child minimum height is `-12`

**Status:** ⏳ open — 2026-09-25 13:15 prove. Mutter exits `ec=133` after 4s. Not a prove SIGKILL.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

## Seen

`mutter-rpc.debug.log`, last lines:

```text
preferred-height base type=StWidget for=-1 min=-12 nat=-12
ClutterBoxLayout child unnamed [GnomeShellRpcRpcHelperActor] minimum height: -12.000000 < 0 for width 182.000000
```

Then `nested-weston-prove: mutter exited ec=133 after 4s`.

The client is in `Clutter-Actor.allocate`. The socket closes. No `JS ERROR`. No `READY=1`. No `Helper-Text.get_layout`.

`get_preferred_height` logged that `-12` from the base measure (`src/rpc/helper/ClutterActor.vala`). The box layout then rejects it.

## Not this bug

`Clutter.Text.get_layout` — [`done/2026-09-25-text-get-layout-pango-layout.md`](done/2026-09-25-text-get-layout-pango-layout.md).
