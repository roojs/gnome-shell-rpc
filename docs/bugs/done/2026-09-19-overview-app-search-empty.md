# Overview app search — first query shows icons; next keystroke shows Searching…

**Status:** ✔️ **closed** (2026-09-22) — user: live type-in-hold is fixed.
Named miss was stock `updateSearch` catch on `vfade.fade_margins is
undefined`. Generator now emits `St.ScrollViewFade.fade_margins` and
fails leftover GIR property skips
([`2026-09-22-gi-stub-gen-silent-property-skip.md`](2026-09-22-gi-stub-gen-silent-property-skip.md)).
Nested `app-search-smoke: ok` (`fadeMargins=0`, `after-ter` nGrid=6,
`after-term` nGrid=5). **🚫** vendor `search.js`. **🚫** never-shrink
allocation (clock crash).
**Plan:** [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)

Chrome leftovers (search/panes too high, thumbs row) stay on
[`../2026-09-16-chrome-panel-menus-overlay.md`](../2026-09-16-chrome-panel-menus-overlay.md).

## Symptom

Type `ter` → application icons. Type `m` or wait → overlay **Searching…**,
grid empty, **stays that way**. Overlay still open.

Live 10:05 (user typed `term`):

```
updateSearch-callback threw vfade.fade_margins is undefined
clear … stack=search.js:278
```

Stock `ensureActorVisibleInScrollView`:

```
const vfade = scrollView.get_effect('fade');
if (vfade)
    offset = vfade.fade_margins.top;
```

`get_effect('fade')` was truthy `St.ScrollViewFade`. GIR has `fade-margins`
/ `Clutter.Margin`. Stub had only `get_fade_margins()`. GJS uses the
property name. Catch `_clearResultDisplay()` (no hide) emptied the grid.

Smoke 10:08: `fadeMargins=undefined` → **`miss fade-margins`**.

## Fix

Client-local generated property `St.ScrollViewFade.fade_margins`
(`St.overrides` `local=1`). Boxed `ay` GIR properties emit; generate
**exits ≠ 0** on leftover `skipped_property`. Do not invent
`fade_margins` on `Clutter.Effect`.

## Prove

```bash
GSR_NESTED_TIMEOUT=60 GI_META_SMOKE=app-search-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
```

2026-09-22 12:40 nested: `fade=St_ScrollViewFade fadeMargins=0`
`fadeMarginsErr=""` · **`app-search-smoke: ok`**.

User 2026-09-22: live hold search works; close this ticket.

## Do not put back

Never-shrink `actor_allocation` on every actor (clock crash). 1px product
`allocate`. Idle / Timeout as the overlay fix. Vendor `search.js`. Invented
GI. `call_depth` / local `get_laters` / undeny `queue-relayout` without a
FAIL that names a new miss.

Allocation getter still skips non-finite mutter width so the first query
is not poisoned — that is not never-shrink.
