# Gi null object IN as lease id 0 → `-32602`

**Status:** ✔️ fixed upstream

**Upstream:** [`OLLMchat/docs/bugs/done/2026-09-06-FIXED-gi-null-lease-id-zero-invalid-params.md`](../../../../../gitlive/OLLMchat/docs/bugs/done/2026-09-06-FIXED-gi-null-lease-id-zero-invalid-params.md)

**Hit:** 2026-09-06 — Wayland nested T-030  
`Clutter-Actor.set_child_below_sibling(..., null)` after `Meta.BackgroundGroup` add.

**Fix:** `Gi.convert_interface` treats lease id `0` / null object Value as null when `may_be_null`.
