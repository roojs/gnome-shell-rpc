# Overview app search — text fills, results empty

**Status:** ⏳ open — 0.8 Search row (not chrome placement, not hang).  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Prove:** `GI_META_SMOKE=app-search-smoke` → named miss, then `ok` once icons land.

**Roles:** consumer of stock `searchController` / `search.js` / `AppSearchProvider` · **not** a new search UI.

Split from [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md) (panel inset / thumbs / popdowns) and from hang-after-settle (closed).

---

## Symptom

**User live (2026-09-18 / 2026-09-19):** nested session stays up. Overview search field accepts typing — **text fills**. The **results list stays empty** (no app icons).

Stock: type a letter → `SearchController` becomes active → `SearchResultsView` shows `GridSearchResults` for applications (icons).

## Not this

| Claim | Reality |
| ----- | ------- |
| Search bar too high / panes too high / thumbs missing | Chrome leftover — panel inset / WINDOW_PICKER content |
| Session hang after settle | Closed — OPC `bin.in_stream.get_available()` |
| Cannot get a key into the entry | Live: **text fills**. Old `fire_key` smoke named Event; that is not the live miss |
| Click / Enter a hit launches | Later — 1.0 S.27 `Shell.App` launch surface |

## Known

| Fact | Evidence |
| ---- | -------- |
| `AppSystem.search` GI identifier | C `shell_app_system_search` with gtk-doc nested GStrv. Vala cannot emit stacked arrays. |
| Vala `search()` was the wrong split | It stole `shell_app_system_search` and put one `GStrv` (`gchar**`) in vala_gir. Smoke then: `malformed UTF-8 character sequence`. Reverted. |
| Stock GIR is nested utf8 | `/usr/share/gnome-shell/Shell-16.gir` `char***` → `<array><array><type name="utf8"/></array></array>` |
| Product GIR clutch | valac → `Shell-16.gir` (stamp, not installed). Inject → `Shell-16.injected.gir`. Typelib / install use that (installed name `Shell-16.gir`). Gate PASS. Nested GJS: nested `string[][]`, 136 hits for `f`. |
| Parental controls initialized | smoke `parental.initialized=true` |
| `clutter_text.text` after inject | Nested 2026-09-19: after Entry subscribe, **`searchActive=true` `appResults=69`**, then **`miss getResultMetas`**. Live: results flash once, then **Searching…**. `Laters` Idle/Timeout/Runtime-flush-delegate are **🚫**. OPC named-signal args on `Notification.args` ✔️; Runtime re-emits them. |
| Launch of a hit | Later — 1.0 S.27 |

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
```

## Forbidden

**🚫** vendor `search.js` / `searchController.js`. **🚫** layout.js. **🚫** Idle as a product fix. **🚫** invented GI methods.  
**🚫** Python/XML rewrite, scanner merge, in-place overwrite of valac’s GIR.

**Allowed (user 2026-09-19):** dummy vala_gir marker + `scripts/gir-inject-placeholder.sh` + snippet file. valac’s `Shell-16.gir` kept for ninja, **not** installed. Injected `Shell-16.injected.gir` is what `g-ir-compiler` uses; install ships it as `Shell-16.gir`.

## Do

1. ~~**FAIL smoke**~~ — ✔️ `app-search-smoke: miss AppSystem.search` (`search is not a function`).
2. ~~**PoC**~~ — ✔️ `meson test gstrv-gir-gate`.
3. ~~**Product inject**~~ — ✔️ valac `Shell-16.gir` keeps placeholder; inject → `Shell-16.injected.gir` / typelib. Nested: `AppSystem.search(f) hits=136`, `lookup_app ok`, `getInitialResultSet n=69`. Smoke then **`miss text-changed`** (`startingUp=true`, `searchActive=false`, `terms=[]`).
4. ~~**text-changed**~~ — ✔️ `St.Entry.clutter_text` `ensure_signal_subscribe`. Nested: `searchActive=true` `textChangedN=1` `terms=["f"]` `appResults=69`. Then **`miss getResultMetas`**.
5. **getResultMetas / icons** — grid needs `BaseIcon.vfunc_style_changed` → `create_icon_texture`. `style-changed` is 0-arg (subscribe + `style_changed_vfunc`). `Laters` `BEFORE_REDRAW` runs from client `before-update` (Notification.args).
6. Launch of a hit stays 1.0 S.27.

## Prove

```bash
GSR_NESTED_TIMEOUT=40 GI_META_SMOKE=app-search-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
# want: app-search-smoke: miss <name>   (until fixed)
# then: app-search-smoke: ok
```

Logs: `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log`.
