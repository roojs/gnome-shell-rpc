# Client `Shell-GLSLEffect` alias is not registered from `Runtime.register()`

**Status:** ⏳ open  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Chrome leftover:** [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md) (clock click)  
**Search leftover:** [`2026-09-19-overview-app-search-empty.md`](2026-09-19-overview-app-search-empty.md) (not this miss)

## Symptom

Click the top-panel clock. Client dies unpacking an effect:

```text
Unrecognized type alias: Shell-GLSLEffect
```

Mutter **ec=133**. Nested `date-menu-open-smoke` (`menu.open(0)`) names the same unpack on `get_effect`.

Server already registers the wire type from `Helper.rpc_register()` → `GLSLEffect.rpc_register()`. The **client** `Bin` map does not.

## One place

Client aliases go in `GiStub.Runtime.register()` (`src/gi-stub/Runtime.vala`), next to:

- `Clutter.register()`
- `meta_register_bins()` → `meta_register` in libmutter-rpc-16
- `st_register_bins()` → `st_register` in libst-rpc-16
- `Bin.register("Clutter-OffscreenEffect", …)`

Host already calls that once: `ShellApplication` → `Runtime.register()` then `Global.bind_display`. Server analog is `Helper.rpc_register()`.

`Runtime.vala` compiles into `libmutter-clutter-rpc-16.so` and cannot `typeof(Shell.GLSLEffect)` (circular). Same cross-lib pattern as St:

1. `src/gi-stub/shell-register.h` — `void shell_register(void);` (copy `st-register.h`)
2. Runtime: extern `shell_register` and call it from `register()` after `st_register_bins()`
3. `src/shell-gi/namespace.vala` — `Shell.register()` (`[CCode (cname = "shell_register")]`) calls `GLSLEffect.rpc_register()`
4. Per-type fill stays `GLSLEffect.rpc_register()` → `Bin.register("Shell-GLSLEffect", typeof(GLSLEffect))`

Construct `register_handle` after the Helper lease is the Clone/Interval proxy identity, **not** the alias. Do not mix the two.

## Rejected call sites (do not put it back)

| Place | Why not |
| --- | --- |
| `ShellApplication` `Bin.register("Shell-GLSLEffect", …)` after `Runtime.register()` | Wrong layer, one-off, swallowed errors |
| `GLSLEffect` `static construct { Bin.register(...) }` | Not a valid register path (`GLib.Error` on `Bin.register`) |
| `GLSLEffect.rpc_register()` from `Global.bind_display` | Not the aggregator. `bind_display` fills the Global singleton |

## Prove

```bash
GSR_NESTED_TIMEOUT=40 GI_META_SMOKE=date-menu-open-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
# expect: date-menu-open-smoke: ok
```

Live click-the-time is the user score after that. Search overlay is a different ticket. Do not reintroduce never-shrink allocation.
