# Overview app search — text fills, results empty

**Status:** ⏳ `H-allocation` PASS (property landed). Nested `app-search-smoke` still the live prove.  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**🚫** vendor `search.js` / `searchController.js`. **🚫** layout.js. **🚫** Idle / Timeout as a product stand-in. **🚫** invented GI.

---

## Known problem

Stock `GridSearchResults._getMaxDisplayedResults` (`search.js` ~519) does
`this.allocation.get_width()` **before** `SearchResultsBase.updateSearch`'s
try/catch (~264). `GridSearchResults.updateSearch` (~515) drops the Promise
from `super.updateSearch`.

GJS 1.82 `actor.allocation` is **not** `get_allocation_box()`. It lazy-defines
a JS getter only when `g_object_class_find_property(klass, "allocation")`
returns a `GParamSpec` (`gjs` `ObjectPrototype::uncached_resolve` →
`g_object_get_property`).

The generator skips `Clutter.Actor.allocation` because the GIR getter is
caller-allocates OUT `ActorBox` (`has_out_values` + `gprop_ok` false for `ay`).
`get_allocation_box` **is** emitted; the **GObject property is not**.
`'allocation' in Clutter.Actor.prototype` is false → `this.allocation` is
`undefined` → TypeError → unhandled rejection → overlay **Searching…**,
`nGrid=0`. Nested 10:56 matches (`getResultMetas`/`createResultObject` ok,
`miss Searching`).

Zero-width `allocation` would still return `provider.maxResults` (6). This is
a missing property, not a 0×0 box.

---

## FAIL (off-code, no Weston)

```bash
meson test -C build --print-errorlogs app-search-empty-gate
```

`H-allocation` **FAIL**’d (`'allocation' in Clutter.Actor.prototype` false;
control `'width'` true). After `Actor.allocation` on the override: **PASS**.

---

## Named fix

**`Clutter.Actor.allocation`** — GObject property on
`src/gi-stub/overrides-clutter/Actor.override.vala` (same pattern as
`pivot_point`: generator skipped an OUT getter). Getter calls the existing
`get_allocation_box` RPC and returns `ActorBox`. Deny `Actor.allocation`.

Not: vendor search.js, wrap `updateSearch`, Idle, or a new GI method.

---

## Already closed (not this miss)

| Named | Gate |
| ----- | ---- |
| `AppSystem.search` / GStrv | `gstrv-gir-gate` |
| `GLib.DesktopAppInfo` marshal | `H-appinfo-gir` / `H-appinfo-call` |
| Dash `vfunc_clicked` smash | [`2026-09-20-spurious-appicon-clicked.md`](2026-09-20-spurious-appicon-clicked.md) |
| Hang-after-settle OPC | closed |
