# Ffi add_class `o` does not resolve wire lease ids

**Status:** ✔️ PASS — OPC fixed; consumer Helpers on `"o"`  
**Hit:** 2026-09-14 `Helper-WaylandClient.create` (`ou` + `Meta.Context`)  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Gate:** `tests/call-sync-repro/ffi-o-lease-gate.vala` — **PASS** 2026-09-14  
**Upstream:** [`OLLMchat/docs/bugs/2026-09-14-ffi-o-does-not-resolve-lease.md`](file:///home/alan/gitlive/OLLMchat/docs/bugs/2026-09-14-ffi-o-does-not-resolve-lease.md)  
**Related:** [`2026-09-14-waylandclient-spawnv-no-rpc-lid.md`](2026-09-14-waylandclient-spawnv-no-rpc-lid.md)

**Roles:** **OPC / libocrpc** — do not edit OLLMchat **code** from this tree.

---

## Prove

```bash
meson compile -C build ffi-o-lease-gate
timeout 5 ./build/tests/call-sync-repro/ffi-o-lease-gate
# expect FAIL until Ffi.pack("o") resolves UINT64 → connection.leases
```

## Was

`GnomeShellRpc.call_value` rewrites GObject args to lease `uint64` (correct).
`OLLMrpc.Gi` unpacks OBJECT / INTERFACE args from that uint64 via
`connection.leases.get`. `OLLMrpc.Ffi.pack("o")` only calls
`val.get_object()`, so `add_class` Helper methods typed as `GObject`
receive null / hit `G_VALUE_HOLDS_OBJECT` CRITICAL.

Consumer workarounds (`"t"` + manual `leases.get`) are wrong — Helpers
should take real objects with signature `"o"`.

## Want

`Ffi.pack("o")` (with request/connection in scope): if Value is UINT64,
resolve `leases.get((int) id)` like Gi; if OBJECT, keep current path.
`HelperMock.arg_object` already shows the dual shape.
