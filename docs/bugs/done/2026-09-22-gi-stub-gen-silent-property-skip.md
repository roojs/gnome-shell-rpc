# gi-stub-gen silent GIR property skip — generate must fail

**Status:** ✔️ **closed** (2026-09-22) — user: live search is fixed.
Leftover `skipped_property` fails generate; `St.ScrollViewFade.fade_margins`
is a real GObject property; nested `app-search-smoke` **ok** (`fadeMargins=0`).
**Plan:** [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)
**Search product:** [`2026-09-19-overview-app-search-empty.md`](2026-09-19-overview-app-search-empty.md)

## Symptom

`emit_object_properties` omitted readable GIR properties that were not
scalar `gprop` (`biyuxftds`). Boxed `ay` getters (`Clutter.Margin`) became
methods only. GJS uses the property name:

```
const vfade = scrollView.get_effect('fade');
if (vfade)
    offset = vfade.fade_margins.top;
```

Live 10:05: `updateSearch-callback threw vfade.fade_margins is undefined`.
Smoke: `fade=St_ScrollViewFade fadeMargins=undefined` → **`miss fade-margins`**.

`ScrollViewFade.fade_margins` in `St.deny` recorded as **denied**, not
`skipped_property`, so `fail_skipped_properties()` never threw.

## Fix

- Boxed `ay` / object `o` emit as Vala properties (method getters or
  unique `*_gprop` C accessors so GIR `get_size` OUT floats stay methods).
- Client-local `St.overrides`: `ScrollViewFade.fade_margins local=1`.
  Not on `Clutter.Effect`. No deny hide. Hand `ScrollViewFade.override.vala`
  removed.
- `Clutter.Margin` `[CCode (has_type_id = true)]` so GJS can read the boxed
  GParamSpec. `GObject.Value` is not a memcpy blob.
- Property wins over a same-named GIR signal (`Meta.Display.focus_window`).
- Generate prints each leftover skip and **exits ≠ 0**. `*.missing.md` has
  **zero** `skipped_property` on St / Clutter / Meta.

Deny+override leftovers (not silent omit): `Clutter.Interval.value_type` /
`initial` / `final` (`Interval.override.vala`); `InputDeviceTool.type`
(Vala reserved identifier; `get_tool_type` stays generated).
`Clutter.Text.attributes` / `font_description` are `local=1` (Pango boxed).

## Prove

Empty deny on Clutter generate (2026-09-22):

```
gi-stub-gen: 4 GIR properties skipped with no stub. Deny+override or emit:
  InputDeviceTool.@type
  Interval.final
  Interval.initial
  Interval.value_type
exit 1
```

Product deny/overrides: generate exit 0, no `skipped_property` rows.

```bash
GSR_NESTED_TIMEOUT=60 GI_META_SMOKE=app-search-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
```

2026-09-22 12:40 nested: `fade=St_ScrollViewFade fadeMargins=0`
`fadeMarginsErr=""` · `after-ter` `nGrid=6` · `after-term` `nGrid=5`
`first=true` · **`app-search-smoke: ok`**. No `updateSearch-callback threw`.

User 2026-09-22: live type-in-hold search works. Search ticket closed.

## Rejected

| Move | Why not |
| ---- | ------- |
| Deny `fade_margins` so generate stays green | Hide. This ticket existed because hide caused the search overlay throw |
| Invent `fade_margins` on `Clutter.Effect` | Not the GIR type |
| Vendor `search.js` | Forbidden on the search ticket |
