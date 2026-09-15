# Nest dies after READY (session/hold) — layout_changed / GJS LM

**Status:** ✔️ FIXED — deny `layout_changed` RPC + GJS LM allocate path  
**Hit:** 2026-09-14 session hold ~13:34  
**Plan:** [`0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)  
**Follow-on:** [`2026-09-15-gjs-layoutmanager-null-allocate.md`](2026-09-15-gjs-layoutmanager-null-allocate.md) ✔️  
**Prove:** nest READY; **0×** `layout_changed: no rpc_lid` / `CLUTTER_IS_LAYOUT_MANAGER`

**Roles:** **consumer** Gi stub · prove settle is separate (10s now)

---

## Was (13:34 session)

`nested-weston-hold` (no settle SIGKILL). `READY=1` @ 28.319 → socket closed @ 35.521 (~7s).

| Signal | Detail |
| ------ | ------ |
| `Clutter-LayoutManager.layout_changed: no rpc_lid` on `WorkspaceLayout` / `ControlsManagerLayout` | uncaught `call_value` → CRITICAL |
| mutter `CLUTTER_IS_LAYOUT_MANAGER` / cogl viewport 0×0 | GJS manager cleared stock manager on server |
| First `set_theme` | ok — not the killer this run |

Same gap as archived `child_set_property` / GJS LayoutManager: `set_container`
was local-safe; **`layout_changed` was not**.

---

## Landed

| Piece | State |
| ----- | ----- |
| Deny `LayoutManager.layout_changed` RPC method (keep GIR **signal**) | ✔️ PERMANENT |
| GJS `Actor.layout_manager` set → no clear of stock compositor LM | ✔️ |
| Prove settle 10s / `GSR_NESTED_STAYUP` | ✔️ |
| Re-prove session stay-up | ✔️ 2026-09-15 |
