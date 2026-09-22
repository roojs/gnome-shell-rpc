# gi-stub-gen silent GIR property skip — generate must fail

**Status:** open — generate still exits **0** while properties GJS needs are omitted  
**Hit:** 2026-09-22 — live overview search catch named `vfade.fade_margins is undefined`  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Search product miss:** [`2026-09-19-overview-app-search-empty.md`](2026-09-19-overview-app-search-empty.md)  
**Earlier same hole (bool, no getter):** [`done/2026-09-11-gir-property-no-getter-missing-on-stub.md`](done/2026-09-11-gir-property-no-getter-missing-on-stub.md)

This is the **generator** ticket. Do not treat a deny-list hide as closed.
Do not invent `fade_margins` on `Clutter.Effect`.

## Next

**Generate must print that it cannot emit the property, flag failed, and
stop compile.** Skips cannot be left behind or hidden. That silent omit
is what kept the search overlay broken: GJS reads `vfade.fade_margins`,
the stub had only `get_fade_margins()`, `St_generated.missing.md` had
**no row**, generate succeeded.

Carry-on order:

1. Enumerate **every** GIR property the generator still drops across
   **St / Clutter / Meta** (and any other generated ns). Temporary
   undeny of `ScrollViewFade.fade_margins` is a valid way to **prove**
   `fail_skipped_properties()` actually throws — it did **not** stop
   `ninja -C build src/St_generated.vala` (exit 0, “gaps 37”).
2. Each listed symbol: emit as a real Vala property (boxed `ay` getters
   already have unpack), **or** an explicit deny **plus** an override
   that owns the GObject property name. Deny alone is a hide.
3. Generate must **exit non-zero** if any `skipped_property` remains.
   Meson `custom_target` then cannot compile stubs. `*.missing.md`
   lists every skip with a reason.
4. Then finish `St.ScrollViewFade.fade_margins` so smoke `fade-margins`
   PASS and live `updateSearch-callback threw` is gone. Product stay on
   the search bug.

**Forbidden:** expanding deny to make generate green; inventing GI names
that are not in the typelib; vendor `search.js`.

## Symptom

`emit_object_properties` `continue`s when a readable GIR property is not
a scalar `gprop` (`biyuxftds`). Boxed getters (`dbus_letter` = `ay`,
e.g. `Clutter.Margin`) become **methods only**. GJS uses the **property
name**. Stock:

```
const vfade = scrollView.get_effect('fade');
if (vfade)
    offset = vfade.fade_margins.top;
```

Live 10:05 (user typed in the hold):

```
updateSearch-callback threw vfade.fade_margins is undefined
clear … stack=search.js:278
```

`get_effect('fade')` is truthy `St_ScrollViewFade`. GIR has
`fade-margins` / `ClutterMargin` (`st-scroll-view-fade.c`). Generated
stub had `get_fade_margins` / `set_fade_margins`, no property. Smoke
10:08: `fade=St_ScrollViewFade fadeMargins=undefined` → **`miss fade-margins`**.

Same class as 2026-09-11 (`night-light-supported` / `unsafe-mode` skipped
when `pi.get_getter()` was null). That one was patched per-property.
This ticket is: **never skip silently again**.

## Required behaviour

| Case | Generate |
| ---- | -------- |
| Can emit a Vala property (method getter, scalar gprop, or boxed `ay` unpack) | emit it |
| Cannot emit | print the symbol + reason, `gaps.add(skipped_property)`, **throw**, **exit ≠ 0** |
| Hand override owns the name | deny **and** override file; still fail if any *other* skip remains |

`*.missing.md` “Denied” is an audit, not a pass. Goal of
`St_generated.missing.md` “zero gaps” must not mean “we denied the hard
ones.”

## Tree state 2026-09-22 (not done)

Partial work in `src/gi-stub-gen/Generator.vala`:

- `gaps.add` on several skip paths (`skipped_property` / `denied`)
- `fail_skipped_properties()` after `write_missing_summary`
- `reason_order` includes `skipped_property`

**Fail did not fire.** St generate: “gaps 37 → `St_generated.missing.md`”,
“emitted 321 stub(s)”, **exit 0**. `ScrollViewFade.fade_margins` is in
`src/gi-stub-gen/St.deny`, so it is recorded as **denied**, not
`skipped_property`. `fail_skipped_properties()` only throws on
`reason == "skipped_property"`.

Also in tree (search product, not this close):

- `src/gi-stub/overrides-st/ScrollViewFade.override.vala` — client-local
  `fade_margins` (`Clutter.Margin`). Do not put this on `Clutter.Effect`.
- `src/meson.build` lists that override as a St generate input.

Other `continue` paths in `emit_object_properties` still omit without a
skip gap (e.g. `!readable && !writable`). Those must gap+fail too if
GIR listed the property.

Clutter / Meta generate not yet re-run against the new fail. Inventory
is incomplete.

## Prove generate actually fails

```bash
# After removing the hide (or leaving a real skip):
ninja -C build src/gi-stub-gen src/St_generated.vala
# expect: non-zero, stderr lists skipped GIR properties
# expect: no St_generated.vala used as compile input after that fail
```

Then regenerate **St, Clutter, Meta**. Every leftover symbol gets emit
or deny+override. Re-run generate — **zero** `skipped_property`, or the
build is red.

Search smoke (after fade_margins is a real property, not methods-only):

```bash
GSR_NESTED_TIMEOUT=60 GI_META_SMOKE=app-search-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
# expect: fade-margins PASS (fadeMargins defined on St.ScrollViewFade)
```

Live: user types `ter` then `m` in a hold. Agent reads
`~/.cache/gnome-shell-rpc/nested-weston-prove.tee.log`. No
`updateSearch-callback threw vfade.fade_margins`.

## Rejected

| Move | Why not |
| ---- | ------- |
| Deny `fade_margins` so generate stays green | Hide. This ticket exists because hide caused the long search bug |
| Invent `fade_margins` on `Clutter.Effect` | Not the GIR type. Effect from `get_effect` is `St.ScrollViewFade` |
| Vendor `search.js` / skip `ensureActorVisibleInScrollView` | Forbidden on the search ticket; does not fix the generator |
| Treat `*.missing.md` rows as enough | Generate still compiles; GJS still sees undefined |

## Related files

- `src/gi-stub-gen/Generator.vala` — `emit_object_properties`,
  `fail_skipped_properties`
- `src/gi-stub-gen/{St,Clutter,Meta}.deny`
- `src/gi-stub/overrides-st/ScrollViewFade.override.vala`
- `build/src/St_generated.missing.md` (Denied already lists
  `ScrollViewFade.fade_margins` — that is the hide)
- `src/gjs-embed/app-search-smoke.js` — FAIL name `fade-margins`
