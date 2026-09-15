# Notification / chrome placement wrong after layout CRITICAL fix

**Status:** ⏳ debug — prove, do not patch yet  
**Hit:** 2026-09-15 — user: banners/menus not in the right place; panel bold  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Roles:** **consumer** MessageTray / panel / constraints

---

## Probe (`GI_RPC_JS_OVERRIDE_DIR=src/shell-js-probe`)

Post-READY + `_showNotification` (tee `GNOME Shell-Message:`):

| Actor | Geometry |
| --- | --- |
| primaryMonitor | `@ 0,0 800x600` |
| panelBox | `@ 0,0 800x32` |
| MessageTray (at show) | `@ 0,0 **521x106**` |
| bannerBin | width 521; `y=-102` (slide-in) |

Panel horizontal layout looks sane. Tray is content-sized, not monitor-sized.
Stock uses `Layout.MonitorConstraint({primary: true})` on the tray.

## Smoke pin (`GI_META_SMOKE=constraint-allocate-smoke`)

GJS `Clutter.Constraint` subclass on `St.Widget` (Helper.Actor peer):

| Check | Result |
| --- | --- |
| `has_constraints` | true |
| `is_mapped` | true |
| `vfunc_update_allocation` hits | **0** (stage layout + forced `allocate`) |

Temporary compositor DBG (removed): `Helper-Actor.allocate` **did** run with
`constraints=yes`; `Helper-Constraint.update_allocation` **never** entered.

## Hypothesis (unproved — do not ship a fix on this alone)

`Clutter-Actor.allocate` over GI may hit `Class->allocate` and skip stock
`clutter_actor_allocate()`’s constraint pass. Confirm by reading Ffi/GI
dispatch / comparing with in-process allocate before any Helper patch.

Also pending (only after vfunc actually runs): Vala `ActorBox` by-value on the
client callback (`_tmp30_` copy) would drop GJS `init_rect` mutations.

## 🚫 Reverted / do not revive

- `gsr_clutter_actor_update_constraints` + Helper.Actor.allocate pre-apply
- Speculative client `invoke_update_allocation` before the path is proved

## Next

1. Prove how `Clutter-Actor.allocate` is invoked (public vs Class vfunc).
2. Only then fix so MonitorConstraint’s `update_allocation` runs.
3. Then re-check tray geom + menus / panel bold.
