# Warning: a callback is unref'd when it is already gone

**Status:** ⏳ deferred. Not the current fix. The nested-add SIGSEGV is
closed:
[`done/2026-09-25-meta-laters-callback-segv.md`](done/2026-09-25-meta-laters-callback-segv.md).

**Plan:** [`0.8 init and interaction`](../plans/0.8-init-complete-and-interaction.md)

## Seen

2026-09-26, after the hold on `Laters.add`. Four stay-up boots
(`GSR_NESTED_STAYUP=1`, `GSR_NESTED_NO_A4=1`) all ended
`nested-weston-prove: stop (timeout)`. The kernel log has no
`gnome-shell-rpc` SIGSEGV.

On the last boot, during a `before-update` callback at 17:20:10, the client
logged:

```text
g_closure_unref: assertion 'closure->ref_count > 0' failed
```

The client kept handling layout calls after that line until the timer closed
the socket. That assertion is the over-release that used to be followed by
the trampoline SIGSEGV. Nothing ran the dead callback in that window, so this
boot only showed the warning.
