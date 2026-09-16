# St.Adjustment missing Clutter.Animatable — startup grey + menus stick

**Status:** ⏳ Animatable iface ✔️; set_to relay ✔️; Interval mint → D1.8  
**Hit:** 2026-09-15 — ibus menu hangs / grey over background; position OK  
**Plan:** [`1.0-run-to-end.md`](../plans/1.0-run-to-end.md) D1.7–D1.8

**Roles:** **consumer** `St.Adjustment` + **generator** GValue IN args

---

## Symptom

Nest CRITICAL:

```
TypeError: …OverviewAdjustment — cannot convert to ClutterAnimatable
  _easeActorProperty → find_property → St.Adjustment.prototype.ease
  → overviewControls.runStartupAnimation → layout startup
```

Overview left `SHOWING` → grey. Menu dismiss fights that layer.

---

## Two separate gaps (do not conflate)

### 1. Animatable on Adjustment (landed)

Stock `St.Adjustment` implements `Clutter.Animatable`. Distro typelib
claims it; stub was only `GLib.Object, Handle`. Generator skips foreign
ifaces unless `Type implements=…`.

**Fix:** `Adjustment implements=Clutter.Animatable` + Animatable methods
in `Adjustment.override` (GObject property defaults + `get_actor`).
`add_transition` = stock (`set_animatable` + `start` + subscribe).

Smoke: `instanceof Animatable` + `find_property('value')` ✔️.

### 2. GValue from/to on Transition (D1.7 — code landed)

[`2026-09-16-transition-interval-gvalue-wire.md`](2026-09-16-transition-interval-gvalue-wire.md)

### 3. Interval `value_type` mint (D1.8 — next for ease)

[`2026-09-16-interval-value-type-mint.md`](2026-09-16-interval-value-type-mint.md) —
same kind letters; Helper creates the compositor Interval. D1.7 alone
does not mint it.

---

## Prove

```bash
meson compile -C build gvalue-in-gate
timeout 5 ./build/tests/call-sync-repro/gvalue-in-gate

GI_META_SMOKE=adjustment-animatable-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
```

| Gate | Meaning |
| --- | --- |
| Animatable + find_property | §1 ✔️ |
| nest ease / Adjustment value | after D1.7 + D1.8 (Interval mint) |

---

## Next

1. ~~D1.7 Transition relay~~ code ✔️
2. Land D1.8 Interval mint
3. Nest ease / clear grey
