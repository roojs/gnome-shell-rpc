# Meta-WaylandClient.spawnv aborts shell (no rpc_lid)

**Status:** ✔️ FIXED — lease + `"o"` + `"S"` argv; nest prove 2026-09-15  
**Hit:** 2026-09-14 nested Weston  
**Plan:** [`0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)  
**Prove:** `./scripts/weston-gsr-prove.sh` — `argv_len=4`, `stdout_fd>=0 buffer=yes`  
**Gate:** `ffi-as-string-array-gate` — **PASS**  
**OPC:** [`FIXED-ffi-o-does-not-resolve-lease`](file:///home/alan/gitlive/OLLMchat/docs/bugs/done/2026-09-14-FIXED-ffi-o-does-not-resolve-lease.md),
[`FIXED-ffi-s-string-array-length`](file:///home/alan/gitlive/OLLMchat/docs/bugs/done/2026-09-14-FIXED-ffi-s-string-array-length.md)

**Roles:** **server** = `mutter-rpc` · **client** = `gnome-shell-rpc`

---

## Landed

| Piece | State |
| ----- | ----- |
| `Helper-WaylandClient` create / spawnv / wait / signals | ✔️ |
| Client `WaylandClient.override` (new + spawnv) | ✔️ |
| `Meta.RpcSubprocess` peer | ✔️ |
| Ffi `"o"` lease resolve (OPC) | ✔️ |
| Ffi `"S"` string[] length (OPC) | ✔️ |
| Nest: no `no rpc_lid` abort; `argv_len=4` | ✔️ |

---

## Was

Shell aborted: `RPC Meta-WaylandClient.spawnv: no rpc_lid on MetaWaylandClient`
because `WaylandClient.new` was denied (no lease). After lease landed, argv
still empty until OPC `"S"` length fix. Callers: DING / rooterm.
