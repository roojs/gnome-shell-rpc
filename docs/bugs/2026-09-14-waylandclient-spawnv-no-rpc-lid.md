# Meta-WaylandClient.spawnv aborts shell (no rpc_lid)

**Status:** ⏳ lease/`"o"` path landed; **argv still empty** — OPC  
[`file:///home/alan/gitlive/OLLMchat/docs/bugs/2026-09-14-ffi-s-string-array-pointers.md`](file:///home/alan/gitlive/OLLMchat/docs/bugs/2026-09-14-ffi-s-string-array-pointers.md)  
(gate `ffi-as-string-array-gate`). Do not keep hacking spawnv around that.  
**Hit:** 2026-09-14 nested Weston  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Logs:** `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log`  
**Prove:** `./scripts/weston-gsr-prove.sh`

**Roles:** **server** = `mutter-rpc` · **client** = `gnome-shell-rpc`

**🚫** No OLLMchat / libocrpc edits. **🚫** No inventing `Meta.Display.launch`.  
**🚫** No Response-object fallbacks for argv.

---

## Landed (code)

| Piece | State |
| ----- | ----- |
| `Helper-WaylandClient` create / spawnv / wait / signals | ✔️ |
| Client `WaylandClient.override` (new + spawnv) | ✔️ |
| `Meta.RpcSubprocess` peer (Gio.Subprocess not on wire) | ✔️ |
| Deny `temporary` → `GLib.error("… temporary — implement this")` | ✔️ |
| `MultiTexture.new` / `new_simple` use `temporary` | ✔️ |
| `lease_id_of` throws (not abort) | ✔️ |
| Nested prove after wire | ⏳ |

---

## Was

Shell aborted: `RPC Meta-WaylandClient.spawnv: no rpc_lid on MetaWaylandClient`
because `WaylandClient.new` was denied (no lease). Callers: DING / rooterm.

---

## Prove

```bash
./scripts/weston-gsr-prove.sh
# must not abort on WaylandClient.spawnv / no rpc_lid
```
