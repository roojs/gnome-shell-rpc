# Chrome misplaced — GJS LayoutManager / NULL compositor allocate

**Status:** ✔️ fixed — stay-up **0×** `CLUTTER_IS_LAYOUT_MANAGER`  
**Hit:** 2026-09-15 nest — allocate CRITICAL + 0×0 viewports  
**Plan:** [`0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)

## Cause

1. GJS `layout_manager` assignment cleared the compositor manager, then
   `Actor.allocate` RPCd into NULL LM.
2. GJS construct often writes `layout_manager = null` while client `priv`
   is unset — RPC clear wiped stock defaults (`St.Bin` BinLayout). Nest
   CRITICAL correlated with `StBoxLayout` under `PanelMenuButton`.

## Fix

- Do not clear compositor LM when assigning a GJS (`rpc_lid == 0`) manager.
- `Actor.allocate` / measure: call `*_vfunc` for GJS managers.
- `LayoutManager.allocate` / `get_preferred_*`: `rpc_lid == 0` = chain-up
  no-op.
- `layout_manager = null` with `previous == null`: **no wire clear** (keep
  compositor default).

## Prove

- `GI_META_SMOKE=layout-allocate-smoke` — GJS `vfunc_allocate` runs.
- Stay-up: READY + **0×** allocate CRITICAL.
