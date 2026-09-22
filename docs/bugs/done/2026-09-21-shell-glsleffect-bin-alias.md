# `get_effect` encoded Helper.GLSLEffect as `Shell-GLSLEffect`

**Status:** ✔️ archived 2026-09-22 — user: stop GLSL, resume search.
Nested `date-menu-open-smoke: ok`. Wire is `Clutter-OffscreenEffect` +
`register_handle`. Do **not** put `Shell-GLSLEffect` on mutter. Live
click-the-time leftover, if any, stays on chrome.
**Plan:** [`0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)
**Chrome leftover:** [`../2026-09-16-chrome-panel-menus-overlay.md`](../2026-09-16-chrome-panel-menus-overlay.md)
**Search:** [`../2026-09-19-overview-app-search-empty.md`](../2026-09-19-overview-app-search-empty.md)

## Symptom

Click the top-panel clock. Client dies unpacking an effect:

```text
Unrecognized type alias: Shell-GLSLEffect
```

Mutter **ec=133**. Nested `date-menu-open-smoke` (`menu.open(0)`) names the same unpack on `get_effect`.

## Cause

`Shell.GLSLEffect` is a **client** class that extends `Clutter.OffscreenEffect`. The compositor peer is `Helper.GLSLEffect` (also a `Clutter.OffscreenEffect`) so snippets can run on the stage Cogl pipeline.

Helper `rpc_register()` did `Bin.register("Shell-GLSLEffect", typeof(Helper.GLSLEffect))`. That invents a Shell wire name on mutter. `get_effect` then encodes the helper GType as `Shell-GLSLEffect`; the client Bin map has no such alias.

Stock Clutter types are already registered (`Gi.register("Clutter")` on the server, `Runtime.register()` on the client). Same pattern as `Clutter-Stage` / `Clutter-Constraint`: `Bin.register_alias` maps the concrete helper GType onto the existing Clutter alias. Do **not** put `Shell-*` on the server.

`add_effect` already works — `call_value` sends the lease as `uint64`, not the GJS GType. Only the **return** of `get_effect` hits `write_gtype`.

Client construct must `Runtime.register_handle` after the Helper lease (Clone / Interval). Otherwise `parse_object` mints a new `Clutter.OffscreenEffect` stub and GJS `===` / `get_uniform_location` break.

## Fix

1. Helper `rpc_register()` — `Bin.register_alias("Clutter-OffscreenEffect", typeof(GLSLEffect))` (after `Gi.register("Clutter")`). Drop `Bin.register("Shell-GLSLEffect")`.
2. Client `Shell.GLSLEffect` construct — `Runtime.register_handle(this)` after `rpc_lid`.
3. Mock `Helper-GLSLEffect.create` mints `Clutter-OffscreenEffect` (already the `get_effect` reply). Drop mock `Shell-GLSLEffect` Bin + `MockShellGLSLEffect`.

## Rejected call sites (do not put it back)

| Place | Why not |
| --- | --- |
| Server `Bin.register("Shell-GLSLEffect", …)` | Shell type on mutter. Wire name the client does not own |
| `Shell.register()` / `shell_register` from `Runtime.register()` to unpack `Shell-GLSLEffect` | Treats the bad server alias as the contract. Client aggregator is for owned Shell types, not this miss |
| `ShellApplication` `Bin.register("Shell-GLSLEffect", …)` after `Runtime.register()` | Wrong layer, one-off, swallowed errors |
| `GLSLEffect` `static construct { Bin.register(...) }` | Not a valid register path (`GLib.Error` on `Bin.register`) |
| `GLSLEffect.rpc_register()` from `Global.bind_display` | Not the aggregator. `bind_display` fills the Global singleton |

## Prove

```bash
GSR_NESTED_TIMEOUT=40 GI_META_SMOKE=date-menu-open-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
# expect: date-menu-open-smoke: ok
```

Do not reintroduce never-shrink allocation.
