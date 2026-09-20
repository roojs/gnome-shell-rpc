# Overview app search — text fills, results empty

**Status:** ⏳ open — 0.8 Search row (not chrome placement).  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Prove:** `GI_META_SMOKE=app-search-smoke` → named miss, then `ok` once icons land.

**Roles:** consumer of stock `searchController` / `search.js` / `AppSearchProvider` · **not** a new search UI.

Split from [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md) (panel inset / thumbs / popdowns) and from hang-after-settle (closed).

---

## Symptom

**User live (2026-09-18 / 2026-09-19):** nested session stays up. Overview search field accepts typing — **text fills**.

Two observations after that, same bug:

| What you see | What it is |
| ------------ | ---------- |
| Results list empty (no app icons) | First live miss |
| Icons flash once, then stuck on **Searching…**; application icons missing at the **top** of overview | Same path after `text-changed` started working |

Stock: type a letter → `SearchController` becomes active → `SearchResultsView` shows `GridSearchResults` for applications (icons).

## Not this

| Claim | Reality |
| ----- | ------- |
| Search bar too high / panes too high / thumbs missing | Chrome leftover — panel inset / WINDOW_PICKER content |
| Session hang after settle | Closed — OPC `bin.in_stream.get_available()` |
| Cannot get a key into the entry | Live: **text fills**. Old `fire_key` smoke named Event; that is not the live miss |
| Click / Enter a hit launches | Later — 1.0 S.27 `Shell.App` launch surface |

## Stock path (do not vendor)

```
Clutter.Text 'text-changed'
  → SearchController._onTextChanged
  → SearchResultsView.setTerms(terms)     // 150 ms
  → AppSearchProvider.getInitialResultSet
       parental.initialized?
       Shell.AppSystem.search(query)
       lookup_app + shouldShowApp
  → getResultMetas (name / create_icon_texture)
  → GridSearchResults / GridSearchResultsLayout
       BaseIcon.vfunc_style_changed → create_icon_texture
       laters.add(BEFORE_REDRAW) from ClutterStage::before-update
```

`app-search-smoke` names the miss (`getResultMetas` when `appResults>0` but no first result / empty grid). `ok` when `getFirstResult()` or the applications `IconGrid` has children.

## Forbidden

**🚫** vendor `search.js` / `searchController.js`. **🚫** layout.js. **🚫** Idle / Timeout / Runtime flush-delegate as a product fix. **🚫** invented GI methods.  
**🚫** Python/XML rewrite, scanner merge, in-place overwrite of valac’s GIR.

**Allowed (user 2026-09-19):** product GIR uses `xsltproc` + `scripts/gir-inject.xsl` (append `AppSystem.search`, rewrite `App.get_app_info` / `app-info` to `Gio.DesktopAppInfo`). Nested GStrv gate still uses `scripts/gir-inject-placeholder.sh`. valac’s `Shell-16.gir` kept for ninja. **🚫** fake `Gio.DesktopAppInfo` subclass vapi. **🚫** `internal` as a GIR dodge. **🚫** upstream Vala issue. **🚫** Vala dummy placeholders on the product GIR.

---

## Done (Do 1–4)

| # | Work | Evidence |
| - | ---- | -------- |
| 1 | FAIL smoke | `app-search-smoke: miss AppSystem.search` (`search is not a function`) |
| 2 | PoC | `meson test gstrv-gir-gate` PASS |
| 3 | Product GIR inject | valac `Shell-16.gir` keeps placeholder; inject → `Shell-16.injected.gir` / typelib. Nested: `AppSystem.search(f) hits=136`, `lookup_app ok`, `getInitialResultSet n=69`. Then **`miss text-changed`**. |
| 4 | `text-changed` | `St.Entry.clutter_text` `ensure_signal_subscribe`. Nested: `searchActive=true` `textChangedN=1` `terms=["f"]` `appResults=69`. Then **`miss getResultMetas`**. |

**GI facts (keep):** C `shell_app_system_search` is nested `char***` / GIR `string[][]`. Vala cannot emit stacked arrays. A Vala `search()` that stole the C symbol and emitted one `GStrv` caused `malformed UTF-8` — reverted. Parental controls `initialized=true`.

OPC `Notification.args` for named signals is **✔️** (`tests/call-sync-repro/subscribe-signal-args-gate`). Runtime re-emits those args onto the client object. That was an OPC bug, not a consumer workaround.

## Open — Do 5: getResultMetas / icons

Two stock pieces after `appResults` is non-empty. Smoke `ok` needs both.

### Icons (`BaseIcon`)

GJS `BaseIcon` is an **`St.Bin` subclass** (first Bin-registered ancestor is `St.Bin` → `St-Bin.new`, **not** `Helper-Actor.create`).

App textures are created in GJS **`vfunc_style_changed`**, not `connect('style-changed')`. `signal_prefer=style_changed` split the GIR method slot from the signal, so a signal emit does not run the vfunc by default.

In tree:

- `St.Widget` construct: **local** `style_changed.connect(() => style_changed_vfunc())` only. Do **not** `ensure_signal_subscribe` in construct — nested RPC mid-`.new` reply parse (`expected object type byte, got 0x00`).
- `Clutter.Actor` construct: after `St-Bin.new` mint, if the GJS type has `style-changed`, `ensure_signal_subscribe(this, "style-changed")`.
- Helper-Actor path (`relay_style_changed`) still `emit_by_name("style-changed")` for types that have the signal. BaseIcon is not that path.

Not re-proved after the connection-reset era.

### Searching overlay (`Laters` `BEFORE_REDRAW`)

Stock mutter runs `LaterType.BEFORE_REDRAW` from **`ClutterStage::before-update`**, then `schedule_update`. `GridSearchResults.updateSearch` queues that later (hide / clear / add after allocation). If the later never runs, the **Searching…** status sticks and the grid does not settle.

In tree (`Laters.override.vala`): queue + `stage.schedule_update()` + local `stage.before_update.connect` → `run_before_redraw()` for `before_redraw` only. **🚫** Idle / Timeout as a stand-in.

`before-update` args are **`(Clutter.StageView, Clutter.Frame)`**. Concrete view on nested mutter is `MetaRendererView`. Frame is a **compact boxed** (`clutter_frame_get_type` / ref-unref), not a GObject.

### Nested 2026-09-19 — boot lockup, then first keypress

1. **16:54** (alias, no export): `hook` then `live object MetaRendererView not in connection.lease_ids` → client reset.
2. **17:27** (alias + `connection.export` on `connection_ready`): `get_laters` → subscribe `before-update` → `unsupported bin value type 'ClutterFrame'` → client reset. Mutter keeps running; shell is dead. Looks like boot locked.
3. **OPC boxed ✔️** (`subscribe-boxed-signal-arg-gate` PASS). Both peers `Bin.register("Clutter-Frame")`. Wire subscribe **on**. Compact client Frame for `typeof`.
4. **19:18** stay-up nest: `before-update` arrives; Compact marshal `frame != NULL` fails (OPC length-0 boxed GValue is unset). Laters handler never runs. First keypress: `unsupported bin value type 'ClutterEvent'` → client EOS. `St.Entry.clutter_text` had subscribed `key-press-event`. Event is Compact / not on the wire (`boxed_ok` rejects the union). Dropped that subscribe (`text-changed` stays). Runtime mints an empty `Clutter.Frame` when the boxed GValue is unset so `before-update` can run Laters.
5. **19:39** nest stays up; results flash then **Searching…**. Overview folder icons: `Unable to resolve arg type 'DesktopAppInfo'` — valac GIR `GLib.DesktopAppInfo` vs stock/GJS `Gio.DesktopAppInfo`. Separate bug: [`2026-09-19-vala-gir-desktopappinfo-glib-vs-gio.md`](2026-09-19-vala-gir-desktopappinfo-glib-vs-gio.md).

Icons (`style-changed` after mint) are not re-proved on a stay-up nest after this.

**21:51:** dash `notify::scale-x` → `queue_relayout()` was a sync RPC per call (~55k + Helper-Actor allocate loop, 1.6 GB log, host secrets bus timeout). Client method coalesces until allocate. No extra signal.

**21:53:** coalesce did not unclog the connection. `queue_relayout` dropped (55k → 416); remaining was layout reads: `.visible` via `is_visible()`, `.name`/`.scale_*` RPCs, plus a preferred-height `GLib.debug` that evaluated those properties on every measure. Visible/scale/name are local on the client (stock flag / last set); debug stripped. `is_visible()` still RPCs (mapped chain). Allocate/preferred Live.Invoke remains.

**09:20:** those caches held (`is_visible` 67, `get_name`/`get_scale` gone). Next flood: `layout.js` `_updateRegions` every `BEFORE_REDRAW` → `set_builtin_struts` (936) + local `workareas-changed` → `queue_relayout` → `notify::allocation` → `_queueUpdateRegions` again, plus `get_workspace_by_index` 4103 / `get_work_area_for_monitor` 3155. Skip identical struts; cache workspace index / n_workspaces / work area / display.

**09:28:** workarea loop gone. Boot construction numbers look right. End CRITICALs are Clone mint — [`2026-09-20-clutter-clone-new-source.md`](2026-09-20-clutter-clone-new-source.md). Also `set_label_actor` null `-32602` (not this).

## Do 6 — not this bug

Launch of a hit stays 1.0 S.27.

## Prove

```bash
GSR_NESTED_TIMEOUT=40 GI_META_SMOKE=app-search-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
# want: app-search-smoke: miss <name>   (until fixed)
# then: app-search-smoke: ok
```

Logs: `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc,nested-weston-prove.tee}.debug.log` / `.log`.
