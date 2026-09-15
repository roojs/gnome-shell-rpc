# Ffi add_class `o` does not resolve wire lease ids

**Status:** ✔️ PASS — OPC fixed; consumer Helpers on `"o"`  
**Hit:** 2026-09-14 `Helper-WaylandClient.create` (`ou` + `Meta.Context`)  
**Plan:** [`0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)  
**Gate:** `tests/call-sync-repro/ffi-o-lease-gate.vala` — **PASS** 2026-09-14  
**Upstream:** [`OLLMchat/docs/bugs/done/2026-09-14-FIXED-ffi-o-does-not-resolve-lease.md`](file:///home/alan/gitlive/OLLMchat/docs/bugs/done/2026-09-14-FIXED-ffi-o-does-not-resolve-lease.md)  
**Related:** [`2026-09-14-waylandclient-spawnv-no-rpc-lid.md`](2026-09-14-waylandclient-spawnv-no-rpc-lid.md)

**Roles:** **OPC / libocrpc** — do not edit OLLMchat **code** from this tree.

---

## Was

`GnomeShellRpc.call_value` rewrites GObject args to lease `uint64` (correct).
`OLLMrpc.Ffi.pack("o")` only called `val.get_object()`, so Helpers typed as
`GObject` received null. Fixed upstream: UINT64 → `leases.get`.
