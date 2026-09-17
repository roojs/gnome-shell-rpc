# Request outbound `Live.Buffer` — OPC gap (D2.2)

**Status:** ✅ closed 2026-09-17 — OPC installed; consumer Helper + gate **PASS**  
**Hit:** 2026-09-17 `St.ImageContent.set_data`  
**Plan:** [`1.0-run-to-end.md`](../../plans/1.0-run-to-end.md) **D2.2**  
**Gate:** `tests/call-sync-repro/request-buffer-gate.vala` — **PASS** 2026-09-17  
**Upstream:** [`OLLMchat/docs/bugs/done/2026-09-17-FIXED-request-live-buffer-outbound.md`](file:///home/alan/gitlive/OLLMchat/docs/bugs/done/2026-09-17-FIXED-request-live-buffer-outbound.md)

**Roles:** **OPC / libocrpc** — do not edit OLLMchat **code** from this tree.

---

## Was

`ImageContent.set_data` needs pixmap bytes on the compositor. Reply-side `Live.Buffer` already worked. Client `call_poll` was bin-only; `Request` had no `buffer`.

```
server eat_fd nbytes=5 saw_buffer=false
FAIL request-buffer-gate
```

## After

OPC `Request.buffer` + `write_with` + server `read_fd` / `take_pending`.

```
server eat_fd got_fd=11 ok=true
PASS request-buffer-gate
```

Consumer: `call_value(..., buffer)`, `drain_readable` attach, `Helper-ImageContent` mint + `set_data` memfd, PERMANENT deny + override.
