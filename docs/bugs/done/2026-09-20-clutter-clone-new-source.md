# Clutter.Clone.new no-arg mint → `-32602`

**Status:** ✔️ **closed** (2026-09-21) — user: clone-new argument miss is gone.
Hand `Clone.override` mints `Clutter-Clone.new` with `args("o", source)`
(null ok); Actor construct skips `Clutter-Clone` so the leaf owns mint.
**Plan:** [`0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)

Overview thumbs row still missing visually stays on the chrome leftovers
row if it is still true — that is not this `-32602`.

## Symptom

`Clutter-Clone.new` `-32602`. Lease never set → every later method
`no rpc_lid on ClutterClone` (`set_source`, easing, `get_transition`, …).

## Stock

GIR `clutter_clone_new(source)` — source **nullable**. GJS:

- `new Clutter.Clone()` then `set_source`
- `new Clutter.Clone({ source })`

Generated lease construct called `.new` with **no args**. Actor parent
construct did the same on the way down.

## Landed

Hand `Clone.override`: mint `Clutter-Clone.new` with `args("o", source)`
(null ok). Actor construct skips `Clutter-Clone` (leaf owns mint).
Generated `Clone.new` / `source` denied (`Clutter.deny`).
