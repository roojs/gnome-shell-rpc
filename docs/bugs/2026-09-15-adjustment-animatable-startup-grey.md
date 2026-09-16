# St.Adjustment missing Clutter.Animatable — startup grey + menus stick

**Status:** ⏳ Animatable iface ✔️; GValue `set_to` → typed Helper (1.0 D1.7)  
**Hit:** 2026-09-15 — ibus menu hangs / grey over background; position OK  
**Plan:** [`1.0-run-to-end.md`](../plans/1.0-run-to-end.md) D1.7 (was 0.8 hit)

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

### 2. GValue IN args (open)

`environment.js` then does `transition.set_to(target)` →
`clutter_transition_set_to_value(transition, GValue*)`.

Generator still `ay`-memcpy’s the `GLib.Value` struct (wrong). **Do not**
“fix GValue through” the generator — that path is rejected.

**Chosen design (typed from/to Helper relay):**
[`2026-09-16-transition-interval-gvalue-wire.md`](2026-09-16-transition-interval-gvalue-wire.md)

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
| nest ease / Adjustment value | after typed from/to relay (linked bug) |

---

## Next

1. Land typed from/to Helper per linked bug (B; A rejected)
2. Nest ease / clear grey
