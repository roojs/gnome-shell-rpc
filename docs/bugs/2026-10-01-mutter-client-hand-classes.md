# Mutter client hand files that look like overrides

**Status:** ⏳ open. `RpcSubprocess` and `PaintedContent` still hand files. User 2026-10-01 will come back to those.

## Done

`BackgroundContent` is a generated stub. `Meta.overrides` has `implements=Clutter.Content` because namespace `emit_implements` is off. Lease-aware setters, `set_rounded_clip_bounds`, the blank constructor, and the `Clutter.Content` methods are in `BackgroundContent.override.vala`. Those properties stay denied so a generated setter does not RPC during GJS construct. Stock `new` is a static method (`meta_background_content_new`); the blank constructor uses `gsr_meta_background_content_blank` so the C names do not clash. `BackgroundContent.register()` is emitted.

`get_settings` is on `Backend.override`. The extern is `gsr_meta_backend_get_settings_vala`. The method stays `gsr_meta_backend_get_settings_method` so it does not clash with `meta_backend_get_settings` in `c-meta-shell-gaps.c`.

## Still hand files

These are not stock classes. There is no generated type to splice into.

| File | Why it stays |
| --- | --- |
| `RpcSubprocess.vala` | Not in Meta-16. Stock `spawn` returns `Gio.Subprocess`. `register=hand`. |
| `PaintedContent.vala` | Our type in `Gsr.Client.Rpc`. Implements `Clutter.Content`. Not in the typelib. |
