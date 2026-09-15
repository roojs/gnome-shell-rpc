# Notification / chrome placement wrong after layout CRITICAL fix

**Status:** ⏳ partial — constraint pipe ✔️ (`constraint-allocate-smoke` PASS); tray still content-sized in nest probe  
**Hit:** 2026-09-15 — user: banners/menus not in the right place; panel bold  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Roles:** **consumer** MessageTray / panel / constraints (client `Constraint.override`)

---

## Symptom

| Surface | Observed | Stock expectation |
| --- | --- | --- |
| MessageTray at show | still `@ 0,0 **521x106**` after fix (2026-09-15 probe) | Monitor-sized via `Layout.MonitorConstraint({primary: true})` |
| bannerBin | width 521; `y=-102` (slide-in) | Same tray allocation, then local slide |
| panelBox | `@ 0,0 800x32` | OK — panel uses `set_position` / `set_size` on primary, **not** MonitorConstraint |
| Menus / “panel bold” | user-reported | AlignConstraint / theme — re-check after tray |

Probe: `GI_RPC_JS_OVERRIDE_DIR=src/shell-js-probe` (`gsr-place:`).

---

## Cause (proven for smoke; tray residual open)

Two client `Constraint.override` bugs; both required for JS constraint geometry to stick.

### 1. `enabled` GParamSpec defaulted FALSE

Hand-written `enabled` construct property emitted
`g_param_spec_boolean(..., FALSE, … | CONSTRUCT)`. Construct overwrote field
init `true`, then `sync_actor_meta_enabled()` RPCd `set_enabled(false)`.

Stock `clutter_actor_update_constraints` skips disabled metas → JS
`vfunc_update_allocation` never ran.

Tee: `Helper-Constraint.create enabled=true` → `Clutter-ActorMeta.set_enabled`
→ `Helper-Actor.allocate … enabled=false`.

### 2. ActorBox by-value dropped `init_rect` mutations

Relay callback called `self.update_allocation(actor, box)` (Vala by-value
copy). GJS mutated the copy; reply `dddd` used the original box. After (1)
alone: hits ≥ 1 but geom stayed 50×50.

---

## Fix (landed)

`src/gi-stub/overrides-clutter/Constraint.override.vala`:

1. `public bool enabled { get; set construct; default = true; }` (same as
   Brightness/Desaturate mirrors).
2. Relay calls `clutter_constraint_update_allocation` via
   `invoke_update_allocation(..., ref box)` so mutations land in the reply.

Smoke `constraint-allocate-smoke` also checks geom ≥ 800×600.

Temporary Helper-Actor / Helper-Constraint DBG messages removed.

---

## Prove

```bash
GI_META_SMOKE=constraint-allocate-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
```

**2026-09-15 after fix:** `hits=2 geom=800x600` → **PASS**.

**Tray probe (same day, stay-up + `shell-js-probe`):** still
`gsr-place: tray @ 0,0 521x106` at `_showNotification`. Constraint pipe for a
plain GJS `Clutter.Constraint` subclass is fixed; MessageTray /
`MonitorConstraint` path still wrong — next chase (when / how tray is
allocated, whether MonitorConstraint early-returns, chrome track), **not**
another Helper allocate pre-pass.

---

## 🚫 Do not revive

- `gsr_clutter_actor_update_constraints` + Helper.Actor.allocate pre-apply
- Speculative client pre-apply before enabled was fixed
- Layout.js ship hacks
