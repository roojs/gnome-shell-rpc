# St.Adjustment missing Clutter.Animatable — startup grey + menus stick

**Status:** ⏳ diagnose pinned — FAIL smoke next, then stub implements  
**Hit:** 2026-09-15 — user: ibus menu hangs / can’t hide; big grey over main background; menu **position** OK  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Roles:** **consumer** `St.Adjustment` / overview startup ease (client stub)

---

## Symptom

| Surface | Observed |
| --- | --- |
| Boot desktop | Large grey plane over wallpaper / stage bg |
| Ibus / input-source menu | Opens; cannot dismiss |
| Panel menus | Position OK after allocate wipe (§ chrome-placement B) |

Nest CRITICAL (prove tee):

```
TypeError: Object is of type .Gjs_ui_overviewControls_OverviewAdjustment
  - cannot convert to ClutterAnimatable
Caused by: Error: This JS object wrapper isn't wrapping a GObject…
  _easeActorProperty@ui/environment.js:229  (actor.find_property)
  St.Adjustment.prototype.ease@environment.js:310
  runStartupAnimation@overviewControls.js:804
  … → layout._startupAnimationSession
```

---

## Cause

Stock `St.Adjustment` **implements** `Clutter.Animatable` (`vendor/gnome-shell/src/st/st-adjustment.c` —
iface only overrides `get_actor`; defaults for `find_property` / state).

Our typelib is compiled from **distro** `St-16.gir` (schema claims Animatable).
Generated stub is only:

`class Adjustment : GLib.Object, OLLMrpc.Live.Handle`

`Namespace emit_implements=1` emits **same-namespace** ifaces only (e.g.
`Scrollable`) — skips foreign `Clutter.Animatable` (St.overrides note:
“until Animatable ready”).

`St.Adjustment.prototype.ease` → `_easeActorProperty` → `find_property`
(Animatable). GJS cast fails → startup animation throws.

`overview.runStartupAnimation` already called `showOverview()` and left
`OverviewShownState.SHOWING`. Throw skips `_showDone` / hide path →
overview group stays up → **grey cover**. Layout `finally` still destroys
layout `_coverPane`; this is **overview**, not that pane.

Incomplete client `add_transition` (no `set_animatable` / no
`timeline.start`) would hang ease even after the cast works — stock
`st_adjustment_add_transition` does both.

Ibus “can’t hide”: dismiss clicks / grab fight the stuck overview layer
(same root). Not a separate BoxPointer position bug.

---

## Prove

```bash
GI_META_SMOKE=adjustment-animatable-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
```

**FAIL pin:** `Adjustment` not usable as Animatable / `ease` throws
`ClutterAnimatable`. **PASS:** `instanceof Clutter.Animatable`,
`find_property('value')`, `ease` → `stopped`.

---

## Fix (after FAIL smoke)

1. `Adjustment.implements=Clutter.Animatable` (+ generator honor foreign
   `implements=`).
2. Override: Animatable methods (GObject property defaults + `get_actor`);
   `add_transition` → `set_animatable` + `start` (stock-shaped).
3. Smoke PASS → nest: no Animatable CRITICAL; grey gone; ibus dismisses.

---

## 🚫 Do not

- layout.js / overview.js ship hacks to skip `ease`
- Invent non-GIR APIs on Adjustment
