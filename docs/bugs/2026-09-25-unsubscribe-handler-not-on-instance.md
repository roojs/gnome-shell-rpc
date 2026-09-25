# `unsubscribe` disconnects a handler id that is not on the instance

**Status:** deferred — removed from the active 0.8 path on 2026-09-25.
The warning was observed, but it was not reached in the follow-up prove and
has not been established as the cause of the random interactive crashes.
Resume only with a reproduction that ties an unsubscribe to a failure.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

## Result

2026-09-25 11:38 prove, after `libocrpc` subscribe/unsubscribe debug (`lease`, `name`, `hid`, `obj`).

479 `subscribe lease=` lines, for example:

```text
subscribe lease=16 name=notify::high-contrast hid=321 obj=0x5c5e6d3bae30
subscribe lease=18 name=notify::upper hid=324 obj=0x5c5e6d863a40
```

`unsubscribe` count: 0. `has no handler` count: 0. No `READY=1`.

Mutter exited `ec=133` after 4s. Journal: `mutter-rpc` SIGTRAP (`int3` in `libglib`) during layout. Last mutter line is `ClutterBoxLayout` child minimum height `-12`. The client then loses the socket and also SIGTRAPs. Same stop as the 11:30 prove. The handler-id mismatch was not reached, so the new logs do not show whether a stored `hid` matches the id passed to `g_signal_handler_disconnect`.

## Seen

11:10 prove (before the subscribe debug), `READY=1`, then `prepare-started` (script SIGKILL). `mutter-rpc.debug.log`, same instance, immediately after `Clutter-Actor.destroy`:

```text
method=Clutter-Actor.destroy
method=RPC-Live-Subscribe.unsubscribe
instance '0x5f20aa59a0d0' has no handler with id '8017'
method=RPC-Live-Subscribe.unsubscribe
instance '0x5f20aa59a0d0' has no handler with id '8018'
method=RPC-Live-Subscribe.unsubscribe
instance '0x5f20aa59a0d0' has no handler with id '8019'
```

108 of these between 11:10:14 and the prove kill. Boot continues.

## Issue

`recv` logs the method name only. It does not log the lease, the signal name, or `signal_subs[lease][name].hid`.

So the log cannot show that 8017 was the handler stored for that subscription.

`g_signal_handler_disconnect` is what prints `has no handler with id`. The id it used is not on that instance.

## Not this bug

`Clutter.Text.get_layout` — [`2026-09-25-text-get-layout-pango-layout.md`](2026-09-25-text-get-layout-pango-layout.md).
