# call_sync × Live.Invoke

```bash
meson compile -C build
BIN=./build/tests/call-sync-repro/call-sync-repro
GATE=./build/tests/call-sync-repro/after-reply-gate
BUF=./build/tests/call-sync-repro/buffer-invoke-gate
GVAL=./build/tests/call-sync-repro/gvalue-omit-gate
GVAL_IN=./build/tests/call-sync-repro/gvalue-in-gate

timeout 3 $BIN idle        # FAIL — Idle(default) reply
timeout 3 $BIN opc-head    # FAIL — OPC head-only send (fixed upstream)
timeout 3 $BIN stack       # FAIL — live: emit inside on_input, reply deferred
timeout 3 $BIN reenter     # PASS — nested dispatch during emit
timeout 3 $BIN child       # PASS — child GI + reenter

timeout 5 $GATE            # Response then Hook.emit B same turn (after emit A)
timeout 5 $BUF             # Response then Hook.emit, no prior emit A
timeout 5 $GVAL            # Gi get_property omit — PASS after OPC FIXED
timeout 5 $GVAL_IN         # Gi set_property GValue IN — shape for set_to
GATE_PROXY=./build/tests/call-sync-repro/proxy-reuse-gate
timeout 5 $GATE_PROXY      # live decode identity — PASS after OPC FIXED
GATE_FFI_O=./build/tests/call-sync-repro/ffi-o-lease-gate
timeout 5 $GATE_FFI_O     # Ffi "o" lease resolve — FAIL until OPC
GATE_HOOK_O=./build/tests/call-sync-repro/hook-o-gate
timeout 5 $GATE_HOOK_O    # Live.Hook.emit "od" GObject — FAIL until OPC
```

`stack` matches live after OPC send fix: reply is recv’d at depth=1, not
dispatched, emit times out, parent never responds.

## after-reply-gate (real libocrpc, two processes)

Shape: emit A → in-flow reply → `request.reply` → **emit B same turn** →
client `call_poll` returns → only `MainContext.iteration`.

| Run | Result |
| --- | ------ |
| Idle-scheduled B (earlier) | **PASS** |
| Same-turn B after Response | **PASS** |

## buffer-invoke-gate

Shape: `request.reply` then `Hook.emit` with **no** prior emit A (tighter
buffering). Client `call_poll` returns → only `MainContext.iteration`.

| Run | Result |
| --- | ------ |
| 2026-09-12 | **PASS** (`invoke_n=0` at return, then INVOKE #1 on MainContext) |

→ **Do not file OPC** on buffered-Invoke / `get_available` until a gate
**FAIL**s. Weston hang after READY remains a **consumer** chase.

## gvalue-omit-gate

Shape: lease `Gio.SimpleAction` → `Gio-SimpleAction.get_property` with
GValue wire row **omitted** (Meta property override pattern). Count
server `type id '0'` CRITICAL.

| Run | Result |
| --- | ------ |
| 2026-09-13 | **FAIL** (3 CRITICAL — bad out GValue init) |
| 2026-09-13 | **PASS** after OPC [`FIXED`](file:///home/alan/gitlive/OLLMchat/docs/bugs/done/2026-09-13-FIXED-gi-get-property-gvalue-init-critical.md) |

→ Archived: [`docs/bugs/done/2026-09-13-gi-gvalue-omit-invalid-critical.md`](../../docs/bugs/done/2026-09-13-gi-gvalue-omit-invalid-critical.md).
PASS → chase consumer (post-READY SIGSEGV).

## gvalue-in-gate

Shape: lease `Gio.SimpleAction` → `set_property("enabled", Value(bool))`
via `OLLMrpc.args("sb",…)` **and** explicit `ArrayList.add(Value)` →
`get_property` round-trip. No Clutter / stubs / generator.

| Run | Result |
| --- | ------ |
| 2026-09-16 | **PASS** — OPC GValue IN shape OK |

PASS → undeny `Transition.set_to*` + generator: not `ay` memcpy; pack
Value into `call_value` args. FAIL → OPC only.

## proxy-reuse-gate

Shape: `Gate.make` exports peer → `Gate.get_peer` returns same lid → client
decode twice. Pointers must match.

| Run | Result |
| --- | ------ |
| 2026-09-13 | **FAIL** then **PASS** after OPC [`FIXED`](file:///home/alan/gitlive/OLLMchat/docs/bugs/done/2026-09-13-FIXED-live-parse-object-remints-proxy.md) |

→ Archived: [`docs/bugs/done/2026-09-13-messagelist-cover-header-stack-critical.md`](../../docs/bugs/done/2026-09-13-messagelist-cover-header-stack-critical.md).
Consumer keeps `Runtime.register_handle` on mint (create-time → `proxies`).

## ffi-o-lease-gate

Shape: `Gate.make` exports Peer → client calls `Gate.echo` with wire arg
`uint64` lease id and `add_class` signature `"o"` (same as
`call_value` object→lease). Helper must receive a non-null Peer.

| Run | Result |
| --- | ------ |
| 2026-09-14 | **FAIL** — Ffi `pack("o")` does `get_object` on UINT64 |
| 2026-09-14 | **PASS** after OPC Ffi lease resolve |

→ [`docs/bugs/done/2026-09-14-ffi-o-lease-resolve.md`](../../docs/bugs/done/2026-09-14-ffi-o-lease-resolve.md).
Helpers (`Helper-WaylandClient`, Background, pad/grab) use GObject `"o"`.

## hook-o-gate

Shape: `Gate.make` returns lease `"t"` only (Helper-Actor.create; no
Response.retval object). `Gate.emit_od` does
`hook.emit(args("od", peer, 1.5))`. Client Invoke `get_object()` must
be the minted Peer.

Helper.LayoutManager remaining C args after self are the container
GObject — not `export()` `"t"` + `proxies.get`.

| Run | Result |
| --- | ------ |
| 2026-09-16 | **FAIL** — `Client.vala:659: unsupported bin array type 0x7F` on emit |
| 2026-09-16 | **PASS** after OPC `StreamValue.read` skip `0xFF` |

OPC: [`OLLMchat/docs/bugs/2026-09-16-any-args-token-reg-type.md`](file:///home/alan/gitlive/OLLMchat/docs/bugs/2026-09-16-any-args-token-reg-type.md).
Helper.LayoutManager `"od"` / `"odddd"` + `get_object()`.

## request-buffer-gate

Shape: `live_handles` client `call_poll` to `Gate.eat_fd`. Server must see
an inbound `Live.Buffer` on the **Request** (pixmap path for
`ImageContent.set_data`). No `"ay"` on bin.

| Run | Result |
| --- | ------ |
| 2026-09-17 | **FAIL** — `Request` has no `buffer`; `call_poll` `bin.write` only |
| 2026-09-17 | **PASS** after OPC FIXED + consumer `Request.buffer` |

OPC: [`FIXED`](file:///home/alan/gitlive/OLLMchat/docs/bugs/done/2026-09-17-FIXED-request-live-buffer-outbound.md).
Consumer: [`2026-09-17-request-live-buffer-opc.md`](../../docs/bugs/done/2026-09-17-request-live-buffer-opc.md).