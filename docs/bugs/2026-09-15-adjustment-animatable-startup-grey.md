# St.Adjustment missing Clutter.Animatable — startup grey + menus stick

**Status:** ⏳ Animatable iface ✔️; GValue `set_to` **design** (do not hack)  
**Hit:** 2026-09-15 — ibus menu hangs / grey over background; position OK  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

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

### 2. GValue IN args (open — needs design, not API salad)

`environment.js` then does `transition.set_to(target)` →
`clutter_transition_set_to_value(transition, GValue*)`.

**What already works in OPC (do not reinvent):**

| Layer | Behavior |
| --- | --- |
| Wire | `Request.args` is `ArrayList<GLib.Value?>`; `StreamValue` encodes DOUBLE/FLOAT/INT/… |
| Helper Gi | `GObject.Value` INTERFACE IN → pin into `value_keep`, pass `GValue*` to C |

**The actual gap:** `gi-stub-gen` does not treat `GObject.Value` as that
path. It falls through to “boxed blob” and emits:

```vala
// WRONG — memcpy of GLib.Value struct as ay
OLLMrpc.args("ay", bytes_of_value_struct);
```

That bypasses StreamValue/Gi and cannot work across processes.

---

## Design (GValue IN — one rule; Interval mint deferred)

**GIR `GObject.Value` IN → put the Vala `GLib.Value` in `call_value` args
as-is.** One method, one signature. No type switch, no Helper-*, no
`Interval.set_property("final", …)`.

1. **Generator** (`callable_wireable` + emit body): detect INTERFACE
   `GObject.Value`; wireable; pack by appending the Value to the args
   list. Deny/replace the `ay` memcpy path for this type.
2. **Same rule** for every GValue* API: `Transition.set_to` /
   `set_from`, `Interval.set_final_value` / `set_initial_value`, etc.
3. **Client GJS only:** `[CCode cname=clutter_transition_set_to_value]`
   thin alias → the one stub method.

**Interval construct (`value-type`) — removed for now.** No
`Helper-Clutter.new_interval_for_type`, no `Interval.override` mint.
Bring back only after an **isolated smoke outside this tree** proves
GType construct + GValue IN (not nested in shell/overview).

### Rejected (do not revive)

- `Helper-Transition.set_to_double` / float / int forks
- `Clutter-Interval.set_property` with `sd` / `sf` / `si` from Transition
- Reimplementing `set_to` by poking `Interval:final` from the client
- Inventing non-GIR methods on Adjustment / Transition
- Premature Interval mint Helpers without an external smoke

---

## Prove

```bash
GI_META_SMOKE=adjustment-animatable-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
```

| Gate | Meaning |
| --- | --- |
| Animatable + find_property | §1 |
| Interval / set_to / ease → value | deferred — external smoke first |

---

## Next

1. Isolated smoke (outside this tree) for GValue IN + Interval construct.
2. Generator GValue IN packing from that proof.
3. Nest: no Animatable CRITICAL; then ease/grey.
