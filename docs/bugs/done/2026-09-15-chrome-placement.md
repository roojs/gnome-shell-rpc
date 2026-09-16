# Notification / chrome placement wrong after layout CRITICAL fix

**Status:** ✔️ allocate path archived — open chrome → [`../2026-09-16-chrome-panel-menus-overlay.md`](../2026-09-16-chrome-panel-menus-overlay.md)  
**Hit:** 2026-09-15 — user: banners/menus not in the right place; panel bold  
**Plan:** [`0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)

**Roles:** **consumer** MessageTray / panel / BoxPointer allocate (client + Helper)

---

## Symptom

| Surface | Observed | Stock expectation |
| --- | --- | --- |
| MessageTray | `MonitorConstraint` leave `800×600` | Monitor-sized |
| dateMenu (before allocate wipe fix) | `@ 0,0 754×574` | Below source |
| dateMenu (after §B) | `@ **23,32** 754×574`; preferred `220,436,754,600` | Below source, ~content-sized |
| panel bold | user-reported | after menus |

Probe: `GI_RPC_JS_OVERRIDE_DIR=src/shell-js-probe` (`gsr-place:`).

---

## Cause

### A. Constraint pipe (landed)

1. `enabled` GParamSpec defaulted FALSE → `set_enabled(false)`.
2. Relay `update_allocation` Vala by-value dropped GJS `init_rect`.

Fix: `Constraint.override` — `enabled` default true +
`invoke_update_allocation(..., ref box)`.

Smoke: `constraint-allocate-smoke` → **PASS**.

### B. GJS allocate `set_allocation` wiped by Helper (landed)

Isolated smoke:

```bash
GI_META_SMOKE=actor-allocate-box-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
```

**FAIL pin (before):** vfunc `out=200,80` + client `set_allocation` RPC, then
final geom still `0,0`. Helper `measure_allocate` re-applied the
**pre-hook** box after reply `b=false`.

**Fix:** non-chain allocate hook → do **not** `set_allocation` in Helper;
GJS Class->allocate must call `set_allocation` (Clutter contract). Same
*class* as Constraint §A (mutations must stick), stock-shaped site.

**PASS:** `actor-allocate-box-smoke: PASS`.

**Nest:** dateMenu `y=32` (under panel); was `y=0`. Size still ~full stage.

### C. Menu size / x (open — preferred natural ≈ stage)

After §B: `dateMenu open @ 23,32 754×574` · source `@ 339,0 122×32`.

`get_preferred_size()` → `220,436,754,600`
(= min_w, min_h, nat_w, nat_h). Allocation matches **natural** ~stage
(`754×600`); min `220×436` is closer to a real calendar.

`_reposition` only `set_origin` — width/height come from parent allocate
using natural preferred.

**2026-09-16:** menus/clock no longer open; panel centre + grey overlay
also open. Chase continues under
[`../2026-09-16-chrome-panel-menus-overlay.md`](../2026-09-16-chrome-panel-menus-overlay.md)
(do not reopen size/`x` until menus toggle again).

---

## Prove

```bash
GI_META_SMOKE=constraint-allocate-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh   # PASS

GI_META_SMOKE=actor-allocate-box-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh   # PASS after §B
```

---

## 🚫 Do not revive

- `gsr_clutter_actor_update_constraints` + Helper.Actor.allocate pre-apply
- Helper `bdddd` rewrite (wiped fix is “don’t re-apply”, not wire coords)
- Layout.js ship hacks
