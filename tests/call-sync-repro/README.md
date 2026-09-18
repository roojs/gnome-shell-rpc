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

## reentrant-emit-call-gate (real libocrpc, two processes)

Shape: server `Gate.provoke` → `hook.emit` (server blocked in emit); client
`invoke` handler issues a **nested synchronous** `call_poll("Gate.ping")`
**before** `RPC-Live-Callback.reply`. Server must dispatch `ping` while
`in_emit`. Models the live "hang after settle": a GJS signal/vfunc/notification
handler makes a blocking RPC (`get_current_event` / `set_builtin_struts` +
`workareas-changed` re-emit) while a server vfunc-relay `hook.emit` is in
flight. Bug: [`../../docs/bugs/2026-09-18-hang-after-settle-race.md`](../../docs/bugs/2026-09-18-hang-after-settle-race.md).

```bash
ninja -C build tests/call-sync-repro/reentrant-emit-call-gate
timeout 8 ./build/tests/call-sync-repro/reentrant-emit-call-gate
```

| Run | Result |
| --- | ------ |
| 2026-09-18 | **PASS** — `ping (in_emit=true)` dispatched; nested sync `call_poll → 42`; `hook.emit END replied=true` |

→ **PASS (observed):** transport dispatches a nested request during `hook.emit`
(re-entrant sync call safe) → the live hang is **NOT** a raw OPC sync-in-emit
deadlock → chase the **consumer** (our re-entrant emit / relayout pattern). **Do
not file OPC** on this shape.
(**FAIL** would have been: OPC cannot service a request while emit is in flight →
file in **OLLMchat**, keep the FAIL gate, do not edit OLLMchat from this tree.)

## poll-burst-strand-gate (real libocrpc, two processes)

Shape: server writes **8 Notifications** ahead of the Invoke, then blocks in
`hook.emit` and writes nothing more. The client is inside `call_poll` and must
drain past the burst to dispatch the Invoke and reply.

Tests starvation rather than coalescing: `Client.poll_drain_readable` parses one
message and recurses only on `read_channel.get_buffer_condition()`, but that
IOChannel is `set_buffered(false)` — reads go through the buffered
`DataInputStream`, whose `get_available()` is never consulted. If one readable
event drained only one message, everything behind it would strand once the
server went silent inside the emit.

```bash
ninja -C build tests/call-sync-repro/poll-burst-strand-gate
timeout 20 ./build/tests/call-sync-repro/poll-burst-strand-gate
```

| Run | Result |
| --- | ------ |
| 2026-09-18 | **PASS** — all 8 notifications drained, `INVOKE … after 8 notifications`, `hook.emit END replied=true` |

→ **PASS (observed):** no burst starvation at this size.

⚠️ **The reasoning above was right; this gate was too weak.** A single coalesced
write usually splits across two reads, so one message per wake is enough. It
takes **volume plus nesting** to land two messages in one read — see
`nested-relay-storm-gate`, which **FAIL**s and measures the stranded bytes. Read
this PASS as "not reproducible at this size", not "ruled out".

## nested-relay-storm-gate (real libocrpc, two processes) — **the repro**

Shape: the live combination, at volume — invoke nesting to depth 4, re-entrant
emits on one hook, sync `call_poll` issued **from inside** `Live.Invoke`
handlers, Notifications written mid-dispatch, 400 rounds. Uses our own
`src/rpc/{Listen,Connection,LiveCallback}.vala`; no Clutter, GJS or stubs.

At the stall it reads `client.bin.in_stream.get_available()` — the question no
other gate asked: *was the reply already inside the client?*

```bash
ninja -C build tests/call-sync-repro/nested-relay-storm-gate
./build/tests/call-sync-repro/nested-relay-storm-gate   # self-terminating, ~5 s
# GSR_STORM_HOLD=1  → 600 s call timeout, to hold the wedge open
# GSR_STORM_CAP=N   → cap the client's underlying reads at N bytes (the
#                     consumer-side fix candidate; PASSes at 8 and 16)
```

| Run | Result |
| --- | ------ |
| 2026-09-18 | **FAIL 5/5** — `ping at depth 1/1/2/4/4: call timed out`, `bin buffer at the stall: 25–32 bytes unparsed` (exactly one Response) |
| 2026-09-18 | `GSR_STORM_CAP=8` / `=16` → **PASS** — 400 rounds, 1600 invokes, depth 4, 4800 notifications, ~1.3 s |
| 2026-09-18 | `in_stream.set_buffer_size(1)` → **breaks** — `Unexpected early end-of-stream` (`Client.vala:701`); a 1-byte buffer cannot satisfy `read_uint64` |
| 2026-09-18 | **PASS 3/3** after OPC `0bd32a82` — ~1.1 s, no mitigation. Keep as the regression gate |

→ **FAIL (expected today):** the awaited reply **was already read into the
client**. `call_poll` waits with `GLib.poll` on the socket fd (now empty) and on
`read_channel.get_buffer_condition()`, which is `set_buffered(false)` and so
always 0 — neither can see the buffered message. With the server parked in
`hook.emit`, no further byte is ever written: both ends sit in `poll`, which is
the live P2 backtrace pair. **OPC** —
[`OLLMchat/docs/bugs/2026-09-18-buffered-reply-strand-and-reentrant-emit.md`](file:///home/alan/gitlive/OLLMchat/docs/bugs/2026-09-18-buffered-reply-strand-and-reentrant-emit.md)
(fix: point the two dead pending tests at `bin.in_stream.get_available()`).

→ **PASS with `GSR_STORM_CAP=8|16`:** capping the client's underlying reads below
the smallest wire message (25 bytes) makes every strand a *partial* message, so
the kernel still holds the rest and `poll()` wakes. Kept as a **stopgap only** —
it hard-codes an assumption about framing. Keep the gate FAILing unmitigated
until the OPC fix lands.

## same-hook-reentrant-emit-gate (real libocrpc, two processes)

Shape: nested `Live.Hook.emit` on **one** callback id (the live logs show 86
re-entrant invokes on the same id in a single session, nesting to depth 4). The
inner reply must not release the outer emit.

| Run | Result |
| --- | ------ |
| 2026-09-18 | **FAIL** — outer emit returns the **inner**'s value (`22`); the outer reply is then rejected `INVALID_PARAMS` |
| 2026-09-18 | **PASS** after consumer `src/rpc/Hook.vala` — `outer=11 inner=0`; storm rejected replies **1200 → 0** |
| 2026-09-18 | **PASS** against stock `Live.Hook.complete` (OPC per-emit frames landed); consumer override deleted |

→ **FAIL:** `Live.Hook.replied` / `reply_id` are per-**row**, not per-**emit**,
so a nested emit overwrites the outer's reply state. Real and reproducible —
but **both emits complete**, so this is a wrong-value / storm amplifier, **not**
the freeze (`nested-relay-storm-gate` counts 1200 rejected replies in 400 rounds
while still completing). Filed in the same OPC report as a separate defect; do
not conflate them. Proposed in the same OPC report: `Live.Hook.emit` →
`virtual`. Everything it touches is already public and `libocrpc` never emits
hooks itself, so with that one keyword we can keep per-emit frames in our own
`LiveCallback` (which already owns `register` / `reply`).

🔷 **Landed upstream (2026-09-18)** as stock `Live.Hook` per-emit frames +
`Hook.complete`; `Live.Callback.reply` routes through `complete`. Consumer
`src/rpc/Hook.vala` deleted; our `LiveCallback.reply` still owns the error-reply
path and now calls stock `complete`.

✔️ **Held here first (2026-09-18)** as an override on the `virtual` `emit`
(`0bd32a82`): each emit waited on its own frame, `LiveCallback.reply` routed
by waiting `reply_id`. `replied` stays the row-wide abandon flag (`Hook.drop`,
connection HUP/ERR), so disconnects still release every nested waiter.

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