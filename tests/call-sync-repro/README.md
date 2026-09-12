# call_sync × Live.Invoke

> # ⚠️⚠️⚠️ AGENTS — READ THIS FIRST ⚠️⚠️⚠️
>
> ## DO NOT STOP for “status theatre”
>
> **Keep working.** Gate PASS → chase the **consumer**, do not stop to report a
> theory. Gate **FAIL** → file OPC bug and **stop** (only OPC stop). See
> `.cursor/rules/no-status-theatre.mdc`.

```bash
meson compile -C build
BIN=./build/tests/call-sync-repro/call-sync-repro
GATE=./build/tests/call-sync-repro/after-reply-gate
BUF=./build/tests/call-sync-repro/buffer-invoke-gate

timeout 3 $BIN idle        # FAIL — Idle(default) reply
timeout 3 $BIN opc-head    # FAIL — OPC head-only send (fixed upstream)
timeout 3 $BIN stack       # FAIL — live: emit inside on_input, reply deferred
timeout 3 $BIN reenter     # PASS — nested dispatch during emit
timeout 3 $BIN child       # PASS — child GI + reenter

timeout 5 $GATE            # Response then Hook.emit B same turn (after emit A)
timeout 5 $BUF             # Response then Hook.emit, no prior emit A
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
