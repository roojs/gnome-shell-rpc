# Clutter.Clone.new no-arg mint → `-32602`

**Status:** ⏳ open — nested 09:28 CRITICALs after workarea flood dropped.  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Not previously filed.** Overview thumbs / altTab `new Clutter.Clone()` then `set_source`.

## Symptom

`Clutter-Clone.new` `-32602`. Lease never set → every later method
`no rpc_lid on ClutterClone` (`set_source`, easing, `get_transition`, …).

## Stock

GIR `clutter_clone_new(source)` — source **nullable**. GJS:

- `new Clutter.Clone()` then `set_source`
- `new Clutter.Clone({ source })`

Generated lease construct called `.new` with **no args**. Actor parent
construct did the same on the way down.

## Do

Hand `Clone.override`: mint `Clutter-Clone.new` with `args("o", source)`
(null ok). Actor construct skips `Clutter-Clone` (leaf owns mint).
