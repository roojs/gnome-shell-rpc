# libocrpc blocking void signals do not wait

**Status:** ✔️ fixed in the 2026-10-15 OLLMchat build. The real-libocrpc gate
now passes: a `Live.Subscription` with `blocking = true` gives a void signal a
reply id and keeps the server inside the emission until the client replies.
gnome-shell-rpc is configured against
`/home/alan/gitlive/OLLMchat/build/libocrpc`.

This is the missing boundary behind the drag scale gap. Clutter
`before-update` is void. Marking it blocking cannot make the frame wait with
the current `Subscription.emit`, because its early return is:

```vala
if (!subscription.blocking || return_value == null) {
	subscription.connection.write(note);
	return;
}
```

GClosure supplies `return_value == null` for a void signal. The blocking path
that allocates a reply id and runs `emit_wait_poll()` is therefore unreachable
for `before-update`.

The FAIL gate is
`tests/call-sync-repro/blocking-void-signal-gate.vala`. It uses the installed
libocrpc, not a copied scheduling model. The server connects a blocking
subscription to a void signal. While handling its notification, the client
calls back into the server before replying. A correct blocking emission keeps
the server inside the signal during that nested call.

```bash
meson compile -C build tests/call-sync-repro/blocking-void-signal-gate
timeout 5 ./build/tests/call-sync-repro/blocking-void-signal-gate
```

Old result, exit 1:

```text
FAIL blocking-void-signal-gate: blocking void signal was one-way tick=true reply-id=false observed-during-emit=false error=
```

Current result, exit 0:

```text
PASS blocking-void-signal-gate: void signal waited for reply
```

The check is now a normal Meson pass, not an expected failure.

Do not edit OLLMchat from this tree. The transport/library fix must make a
blocking void subscription allocate a reply id and wait, while avoiding a
write through the null `return_value`. The boolean return assignment remains
specific to non-void signals.

The reverted transition hold is not that boundary. Its
`scale-gap-gate.vala` mode only simulated pause/resume; it did not run
`Shell.Signals.emit_depth`, `Actor.set_scale`, or the C trampoline. In the
product it added two `get_transition` RPCs to every changed scale across
login, overview, window animations, message list, dash, magnifier, and DND.
The guest regression is correlated with that broad integration, but the
available log does not prove whether the cause was the extra RPC load, a
paused unrelated transition, or an existing startup failure exposed by the
timing change.

Related consumer bug:
[`2026-10-14-drag-scale-gone.md`](2026-10-14-drag-scale-gone.md).

## LLM efforts

### 2026-10-15 real-libocrpc gate

Read the existing drag record and the reverted `pause-on-ease` integration.
The abstract scale gate passed without linking product code and therefore
could not validate the global `set_scale` hook.

Added `blocking-void-signal-gate.vala` and ran it against the configured
libocrpc. The notification arrived, but had no reply id; the nested server
observation ran only after the void emission had returned. Direct run exited
1 with the FAIL line above. The Meson expected-failure check completed in
0.04 seconds with no timeout.

### 2026-10-15 library fix applied

Configured this build with:

```bash
meson configure build -Docrpc_libdir=/home/alan/gitlive/OLLMchat/build/libocrpc
```

The direct gate printed `PASS blocking-void-signal-gate: void signal waited
for reply`. After adding `before-update` to the consumer blocking list, the
35-check signal-reentrancy suite reported 25 passes and 10 expected failures,
with no unexpected failures or timeouts.
