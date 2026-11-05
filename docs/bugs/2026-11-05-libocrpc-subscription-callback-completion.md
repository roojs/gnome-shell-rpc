# Stock libocrpc callback reply cannot complete a blocking subscription

**Status:** Open in libocrpc; FAIL-backed. Do not remove the consumer
completion fallback until the library owns this operation.

## Problem

`OLLMrpc.Live.Subscription.emit` creates a `Hook` waiter in
`Transport.Connection.callbacks`, sets its row-wide `reply_id`, and waits for
`waiter.replied`.

Stock `OLLMrpc.Live.Callback.reply` searches the same callback map but only
calls `Hook.complete(correlation, values)`. That method searches nested emit
frames. The subscription waiter has no frame, so the reply is rejected as
invalid and the signal emission waits until its caller times out.

`gnome-shell-rpc` currently replaces the callback service and duplicates the
missing completion operation in `Gsr.Server.LiveCallback.complete`. This
allows both framed hook emits and the subscription's row-wide waiter to
complete, but the operation contains no consumer-specific behavior.

## Reproduction

`tests/call-sync-repro/subscription-stock-callback-reply-gate.vala` uses:

- stock `OLLMrpc.Live.Callback`;
- a real blocking `OLLMrpc.Live.Subscription`;
- a remote uint reply of `7`; and
- the GSR connection subclass only for nested socket dispatch.

Run:

```bash
meson setup --reconfigure build
meson compile -C build subscription-stock-callback-reply-gate
timeout 5 ./build/tests/call-sync-repro/subscription-stock-callback-reply-gate
```

Current result:

```text
WARNING: RPC-Live-Callback.reply id=4:
WARNING: call timed out Gate.fire id=3 after 2 s
FAIL subscription-stock-callback-reply-gate: returned=0 callback-error= outer-error=call timed out
```

The same typed subscription return passes when the consumer replacement
callback service is linked.

## Ownership

Completion should be a libocrpc operation on the connection that owns the
callback registry, for example:

```vala
request.connection.complete_callback(correlation, values)
```

It must complete:

1. a correlation frame owned by `Hook.emit`; or
2. the row-wide waiter currently created by `Subscription.emit`.

Both stock `Live.Callback.reply` and a consumer's specialized typed/boxed
reply handler then use that operation. Error-reply policy can remain in the
protocol handler.

Longer term, `Subscription.emit` can use the framed waiter mechanism and the
row-wide compatibility branch can be removed. Moving the operation into the
library first prevents consumers from depending on either internal
representation.

## LLM efforts

- 2026-11-05 17:33 HKT. Added
  `subscription-stock-callback-reply-gate` without the GSR callback
  replacement. Reconfigured and compiled successfully. The stock reply was
  rejected, `Gate.fire` timed out after two seconds, and the gate printed
  `FAIL` with `returned=0`. No OLLMchat/libocrpc source was edited.
