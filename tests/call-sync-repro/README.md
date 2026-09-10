# call_sync × Live.Invoke

```bash
meson compile -C build
BIN=./build/tests/call-sync-repro/call-sync-repro

timeout 3 $BIN idle        # FAIL — Idle(default) reply
timeout 3 $BIN opc-head    # FAIL — OPC head-only send (fixed upstream)
timeout 3 $BIN stack       # FAIL — live: emit inside on_input, reply deferred
timeout 3 $BIN reenter     # PASS — nested dispatch during emit
timeout 3 $BIN child       # PASS — child GI + reenter
```

`stack` matches live after OPC send fix: reply is recv’d at depth=1, not
dispatched, emit times out, parent never responds.
