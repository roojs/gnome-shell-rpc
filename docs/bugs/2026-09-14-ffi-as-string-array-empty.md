# Ffi `string[]` empty on Helper (`as` / `S`)

**Status:** ✔️ OPC fixed; consumer Helpers on `"S"` — gate PASS  
**Hit:** 2026-09-14 nested Weston `Helper-WaylandClient.spawnv`  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Gate:** `tests/call-sync-repro/ffi-as-string-array-gate.vala`  
**Upstream:** [`OLLMchat/docs/bugs/2026-09-14-ffi-s-string-array-length.md`](file:///home/alan/gitlive/OLLMchat/docs/bugs/2026-09-14-ffi-s-string-array-length.md)  
**Related:** [`2026-09-14-waylandclient-spawnv-no-rpc-lid.md`](2026-09-14-waylandclient-spawnv-no-rpc-lid.md)

**Roles:** OPC `Ffi` `"S"` length · consumer `add_class` `"S"` for Vala `string[]`

---

## Landed

| Piece | State |
| ----- | ----- |
| OPC `Ffi` `"S"` length from `GLib.Value` | ✔️ upstream |
| Gate: pack/wire OK; `echo_S` PASS; `echo_as` pointer-only | ✔️ |
| `Helper-WaylandClient.spawnv` `"osas"` → `"osS"` | ✔️ |
| `Helper-ThemeContext.set_theme` `"sssas"` → `"sssS"` | ✔️ |
| Client pack still `"osas"` / `"sssas"` (wire `as`) | ✔️ |
| Nested prove non-empty spawnv argv | ⏳ S3 |

---

## Was

```
client argv_len=4 → Helper argv_len=0 → meta_wayland_client_spawnv assert
```

Wire OK; Ffi `"S"` length via `get_boxed()` was 0. OPC fixed; Helpers
must use `"S"` not `"as"` for Vala length-bearing `string[]`.

---

## Prove

```bash
timeout 5 ./build/tests/call-sync-repro/ffi-as-string-array-gate
# PASS — echo_S ffi=4; echo_as may be 0 (expected)
```
