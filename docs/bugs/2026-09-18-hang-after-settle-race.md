# Hang after settle — intermittent race (smoke + debug dissection)

> # ⚠️⚠️⚠️ AGENTS — READ THIS FIRST ⚠️⚠️⚠️
>
> ## DO NOT STOP for “status theatre”
>
> **Keep working.** Do not pause to narrate progress, summarize what you tried,
> or ask whether to continue after every prove / dead end / rebuild. Carry on
> until the bar moves or you hit one of the stop conditions below.
>
> ## When you MAY stop
>
> 1. **You actually need the user’s help** — a decision only they can make,
>    credentials, or a machine/session you cannot reach (here: the user runs
>    the nested prove + captures the paired backtraces, P1–P2). Say what you
>    need in one short ask, then wait.
> 2. **OPC / libocrpc is the problem** — and only then: keep a **FAIL** gate
>    under `tests/call-sync-repro/` that **FAIL**s, file the bug in **OLLMchat**
>    (`docs/bugs/`), **do not edit OLLMchat from this tree**, and **stop**.
>    That is the **only** OPC-related stop. PASS gates → chase the **consumer**
>    (our re-entrant emit / sync-call pattern); do not stop to “report” a theory.
>
> ## Everything else
>
> File/update **this** bug, pick the next allowed prove-first step
> (debug → smoke → gate → fix-outside → land minimal), rebuild, prove, repeat.
> **🚫** No git-bisect pass/fail scoring (rejected — race). **🚫** No speculative
> Helper / stub / deny / JS / layout hacks in `src/` before a FAIL smoke or gate
> **names** the fix. Revert prototypes; do not leave them “for later.”

**Status:** ⏳ open — **OPC fix landed + gate-verified; needs the live prove**.
Nested session **hangs** at/near the **IBus notification dismiss**. Intermittent
on old states, **~every time at HEAD** (`8765ee3`).

**2026-09-18 — OPC fixed it** (OLLMchat `0bd32a82` "hopefully fix deadlock on
gsr"): both pending tests now read `bin.in_stream.get_available()`. Against the
rebuilt library `nested-relay-storm-gate` goes **FAIL → PASS 3/3** (~1.1 s, 400
rounds, 1600 invokes, depth 4, 4800 notifications) with no mitigation, and the
other 16 transport gates still pass. ⏳ **The live nested session is still the
real test — user runs it.**

**Cause (P6, 2026-09-18):** `OLLMrpc.Client.call_poll` blocks forever on a reply
that is **already in its own `bin.in_stream` buffer**. Measured, not inferred —
`nested-relay-storm-gate` **FAIL**s 5/5 in ~5 s with *“bin buffer = 32 bytes
unparsed”* at the timeout. Filed as one OPC report with verbatim edit fences:
OLLMchat
[`docs/bugs/2026-09-18-buffered-reply-strand-and-reentrant-emit.md`](file:///home/alan/gitlive/OLLMchat/docs/bugs/2026-09-18-buffered-reply-strand-and-reentrant-emit.md).

**Fix is in OPC, and it is small.** The two "is more input pending?" tests ask
the unbuffered `read_channel`, so they are dead code; the proposal points them
at `bin.in_stream.get_available()` — the same correction our own
`src/rpc/Connection.vala` already makes on the server path. Nothing to override
downstream. P6b (capping the client's reads) also flips the gate to **PASS**
with no OPC change, but it hard-codes an assumption about framing and is kept
only as a stopgap if we need the session unwedged before the fix lands.

**Supersedes (git approach rejected):**
[`done/2026-09-18-hang-after-settle-git-bisect-rejected.md`](done/2026-09-18-hang-after-settle-git-bisect-rejected.md)
— reuse its **file-level audit** and **sync-RPC / re-entrant-emit call-site
table**.

**Method:** dissect by **prove-first**, not git. Prove the hang
programmatically (debug) → reproduce in a **smoke** → isolate in a **two-process
gate** → propose + test the fix **outside the product tree** → only then land a
**minimal** change. **🚫 No churning hacks into `src/` to “try” a fix.**

**Working tree:** clean at `7d9daac` ("worknig through hang deadlock"), which
carries the `8765ee3` deterministic-hang content plus the gates and this doc.

---

## Hypothesis

**Cross-process re-entrant synchronous-RPC deadlock.** A GJS signal / vfunc /
notification handler makes a **blocking** RPC while the peer is blocked mid-emit
awaiting the client’s reply (or the client main loop is not pumping because it
is inside a handler). Each of `ce4939e` and the R2 changes **adds more such
call sites**, so the race odds climb: rare → frequent → ~100 %. This matches the
intermittency and the “both halves hang” bisect results.

Call sites (from the rejected doc’s table): init `Helper-Actor.add_hook`
(`Global.vala`); key `measure_event` → `hook.emit` (`LayoutHooks.vala`);
`set_builtin_struts` RPC + re-entrant `emit "workareas-changed"`
(`Workspace.override.vala`); generic `default` re-emit (`Runtime.vala`);
`get_current_event` sync round-trip (`Clutter.override.vala` / `Clutter.vala`);
`relay_event` emits (`Actor.override.vala`).

The IBus-dismiss anchor fits: a banner hide runs a Clutter transition
(`stopped` re-emit) **and** can recompute regions/struts (`workareas-changed`
re-emit) — two re-emit paths firing together at that moment.

**Compare:** `tests/call-sync-repro/` `stack` already documents the exact shape
— *“reply recv’d at depth=1, not dispatched, emit times out, parent never
responds.”* This bug is likely the live instance of that (OPC) or a consumer
re-entrancy that provokes it.

### P4 result (2026-09-18) — OPC transport RULED OUT → consumer

`reentrant-emit-call-gate` **PASS**: a nested **sync** `call_poll` from inside a
`Live.Invoke` handler, while the server is blocked in `hook.emit`, dispatches
and completes (`ping in_emit=true → 42`, `emit END replied=true`). So the raw
“sync RPC inside an emit” is **not** a transport deadlock. The hang is a
**consumer** pattern. Refined suspects (need P2 to pick):

1. **Re-entrant relayout loop** — `Workspace.override.set_builtin_struts` emits
   `Display::workareas-changed`; the GJS handler (`ControlsManagerLayout` /
   `LayoutManager._updateRegions`) recomputes struts and can re-emit →
   unbounded recursion / CPU spin (a *spin* hang, not a blocked-recv deadlock).
   Note `workarea-panel-inset/chrome-smoke` call `set_builtin_struts` in
   isolation and did **not** hang — so the trigger is the **combination** at
   IBus-dismiss (transition `stopped` + `workareas-changed` + key/event
   re-emits firing together).
2. **Generic `default` re-emit** (`Runtime.vala`) delivering a signal whose GJS
   handler synchronously drives another notification/emit → nested re-entry the
   GJS main loop is not prepared for.
3. **Double/interleaved emit** — transition `stopped` re-emit *and*
   `workareas-changed` re-emit landing in the same turn (the IBus-dismiss
   anchor).

### P2 result (2026-09-18) — paired backtraces: **BLOCKED cross-process deadlock**

Captured at the live freeze (`/tmp/gsr-hang-20260918-094042/`, overview settle):
both main threads are **blocked in `poll`** (not spinning — the client debug
log goes silent ~9 s before capture). The two ends:

- **server `mutter-rpc`** (main): clutter `allocate` →
  `RpcHelperActor.get_preferred_height` (`ClutterActor.vala:116`) →
  `RpcHelperLayoutManager.get_preferred_height` (`ClutterLayoutManager.vala:79`)
  → `Live.Hook.emit` → `Connection.vala:48 emit_wait_poll` → `__poll`
  (waiting the client's reply to the **LM preferred-height** Invoke).
- **client `gnome-shell-rpc`** (main): outer sync
  `call_poll(Meta-Workspace.get_work_area_for_monitor)` → drains → dispatches
  that Invoke → **inside the invoke handler** calls
  `clutter_actor_get_name` → nested sync
  `call_poll(Clutter-Actor.get_name)` → `__poll` (waiting the server's reply,
  id=21533 — server log shows it `recv`’d get_name then went silent).

So the client makes **synchronous RPCs from inside a `Live.Invoke` handler**
while the server is blocked mid-`hook.emit` inside `allocate` — a re-entrant
sync round-trip cross-wait.

**Transport ruled out (again).** New gate
`poll-coalesced-reply-gate` (server writes `[Notification][Response]` in one
flush → client `call_poll` must still return) **PASS**es on the installed
`libocrpc.so`. With `reentrant-emit-call-gate`, `buffer-invoke-gate`,
`after-reply-gate` also PASS, no transport reduction reproduces the hang.
**User (2026-09-18): OLLMchat/libocrpc has no significant recent changes that
would affect this** — installed `libocrpc.so` = OLLMchat HEAD `f76558a8`; the
only working-copy edit is the HTTPS `HttpClient` transport, off this path. →
**Not an OPC bug; chase the consumer change `e1a7c46..HEAD`** — where
`e1a7c46` is *not* a good commit, only one that failed **intermittently**
rather than **every time** (HEAD). We are chasing what turned an occasional
race into a deterministic freeze.

### P2 → named consumer corridor (the regression)

The `get_work_area_for_monitor` storm is the **workarea re-emit corridor**
added since `e1a7c46` (the intermittent-failure baseline, not a good commit) —
i.e. changes that plausibly pushed the race from intermittent to ~100 %:

1. `overrides/Meta.override.vala` — `get_display()` now
   `ensure_signal_subscribe(display, "workareas-changed")` (client Display
   proxy re-emits on the server Notification).
2. `overrides/Workspace.override.vala` (**new**) — `set_builtin_struts()`
   RPCs the server **and then** `emit_by_name(display, "workareas-changed")`
   on the client.
3. `gi-stub/Runtime.vala` — generic `default` case re-emits **any** subscribed
   signal notification on the client proxy (broadened from `stopped` only).

The overview `ControlsManagerLayout` / `LayoutManager._updateRegions` refreshes
`_workAreaBox` on `workareas-changed` and queries `get_work_area_for_monitor`.
That query now runs **re-entrantly inside the preferred-height relay** (the
Invoke handler) while the server is blocked in `hook.emit` → the deadlock
above. `workarea-panel-{inset,chrome}-smoke` exercise `set_builtin_struts` in
**isolation** and do **not** hang; the deadlock needs the **overview relayout
+ workareas re-emit** landing inside the LM relay Invoke.

### P4b result (2026-09-18) — burst stranding RULED OUT too

The one transport shape P2 left open was **starvation**, not coalescing: the
client reads through a buffered `DataInputStream` but *waits* on a bare
`poll()` of the socket fd plus `read_channel.get_buffer_condition()` — and that
IOChannel is `set_buffered(false)`, so its buffer condition is always empty.
`poll_drain_readable` parses **one** message and recurses only on that same
always-false condition. On paper one readable event drains one message however
many were coalesced into the read, so once the server stops writing (blocked in
`hook.emit`) everything behind the first message — including the Invoke that
would release the emit — is stranded with nothing left to wake the poll.

New gate `poll-burst-strand-gate` (8 Notifications written ahead of the Invoke,
server then blocks in `hook.emit` and writes nothing more) **PASS**es:

```
client: NOTIFICATION #1..#8 burst-0..burst-7
client: INVOKE id=3 reply_id=5 after 8 notifications
server: hook.emit END replied=true
PASS poll-burst-strand-gate: invoke dispatched behind 8/8 notifications
```

So the client does drain past a burst. With `reentrant-emit-call-gate`,
`poll-coalesced-reply-gate`, `buffer-invoke-gate` and `after-reply-gate` also
PASS, **every transport reduction of the P2 shape passes** — five now. The
remaining difference between the gates and the live freeze is the **consumer**:
volume (hundreds of sync round-trips per allocate), nesting depth, and the
re-entrant emit corridor below.

**Fix candidate to prove (consumer, minimal):** break the re-entrant
workareas-changed emit so it does not fire a sync `get_work_area_for_monitor`
inside a `Live.Invoke` handler — e.g. drop the manual re-emit in
`set_builtin_struts` and/or defer the `workareas-changed` client emit to an
idle (out of the relay/emit stack), and narrow `Runtime.vala`'s `default`
re-emit. Prove-first: needs a **P3 FAIL smoke** (overview + workareas-changed
during an LM preferred-height relay) before touching `src/`.

> **Superseded by P6.** The mechanism described above ("stranded with nothing
> left to wake the poll") was **correct**; `poll-burst-strand-gate` was simply
> too weak to trigger it — one coalesced write usually splits across two reads.
> It takes volume + nesting. Keep the consumer corridor as an **amplifier**
> (fewer re-entrant sync round-trips = smaller window), not as the cause.

### P6 result (2026-09-18) — stranded reply **MEASURED**: it is OPC after all

`tests/call-sync-repro/nested-relay-storm-gate.vala` runs the live shape at
volume — invoke nesting to depth 4, re-entrant emits on one hook, sync
`call_poll` from **inside** `Live.Invoke` handlers, Notifications written
mid-dispatch, 400 rounds — against our own `src/rpc/{Listen,Connection,
LiveCallback}.vala`, no Clutter, no GJS, no stubs. At the stall it reads
`client.bin.in_stream.get_available()`:

```
FAIL nested-relay-storm-gate: stalled — ping at depth 1: call timed out
  client bin buffer at the stall: 32 bytes unparsed
```

5 runs, 5 stalls (depths 1, 1, 2, 4, 4; 25–32 bytes each — exactly one
Response). **The awaited reply is already inside the client process.** Nothing
was lost or unflushed; `call_poll` cannot see it:

- `Client.vala:420–423` — the wakeup IOChannel is `set_buffered(false)`, so
  `get_buffer_condition()` is **always 0** and both pending checks that use it
  (`:705`, `:1054`) are dead code.
- messages are parsed from `bin.in_stream`, a `DataInputStream` whose one
  `read_byte()` pulls **everything the socket has** — often several messages.
- `poll_drain_readable` parses **one**, consults the dead condition, returns;
  `call_poll` then blocks in `GLib.poll()` on an fd with nothing left.

With the server parked in `hook.emit` waiting on us, no further byte is ever
written → both ends in `poll` — **exactly the P2 backtrace pair**.

Confirmation from the same run: after the client times out and sends its next
request, the server answers, that wake finally drains the buffer, and the
5-second-old reply surfaces as `ERROR Client.vala:1170: unexpected response
id 197` — a process abort. That abort is why the live evidence kept vanishing.

**Precedent we already own:** `src/rpc/Connection.vala` (header, lines 8–11)
diagnosed this same defect on the **server** path and works around it in
`input_pending()` via `bin.in_stream.get_available()`. That was possible only
because `emit_wait_poll` is virtual.

### P6 fix shape — fix it in OPC; nothing to override here

`call_poll` is `public` but **not** `virtual` (`Client.vala:993`) and
`poll_drain_readable` is `private`, so a subclass cannot reach the drain
anyway. The proposal (filed with verbatim fences) adds one private helper and
points both dead tests at it:

```vala
/* libocrpc/Client.vala — used at :705 and :1054 */
private bool poll_input_pending()
{
	return this.bin != null && this.bin.in_stream != null
		&& this.bin.in_stream.get_available() > 0;
}
```

✔️ **Landed upstream as `0bd32a82`** — inlined at both sites, without the helper
and without null guards (`bin` is already proven non-null at `:705` by the
method's own early return, and a null there should crash, not silently report
"nothing pending" and re-create this hang). Verified here:

```
PASS nested-relay-storm-gate: 400 rounds, 1600 invokes, depth 4, 4800 notifications, 1200 rejected replies, 1249 ms
PASS … 1049 ms
PASS … 1097 ms
```

🚫 **Rejected (2026-09-18): a `protected virtual` seam + downstream override.**
The default it would preserve (`read_channel.get_buffer_condition()`) is dead
code — `set_buffered(false)` means it is always `0` — so the seam protects
nothing and is the same edit with extra indirection. Fixing the base is
strictly more correct and fixes every other libocrpc client at the same time.

`nested-relay-storm-gate` is the regression check: it must flip FAIL → PASS.

### P6b result (2026-09-18) — consumer-side fix **PASSes** with no OPC change

`Bin.Stream.in_stream` is a public settable property, so the client's
`DataInputStream` can be swapped for one whose base stream caps every read.
`Bin.Stream.parse` opens each message with `read_byte`, which fills the whole
4096-byte buffer — that is the over-read. Cap each underlying read **below the
smallest message on the wire** (25 bytes observed) and a strand can only ever be
a *partial* message, whose remainder is still in the kernel: the socket stays
readable, `poll()` always wakes, no deadlock.

```
GSR_STORM_CAP=8   → PASS  400 rounds, 1600 invokes, depth 4, 4800 notifications, 1267 ms
GSR_STORM_CAP=16  → PASS  400 rounds, 1600 invokes, depth 4, 4800 notifications, 1266 ms
(unset)           → FAIL  wedged within ~13 rounds
```

Rejected alternative: `in_stream.set_buffer_size(1)` **breaks the stream** —
multi-byte reads die with `Unexpected early end-of-stream` (`Client.vala:701`),
because a 1-byte buffer can never satisfy `read_uint64`.

💩 The cap encodes an assumption about framing (no message smaller than the cap)
and spends extra `read()` syscalls. Good enough to unblock the session and to
prove the diagnosis; the seam is still the fix to land.

---

## Plan (walk top → bottom; tick per step)

| # | Step | Area | Status |
| - | ---- | ---- | ------ |
| P1 | **Classify the stop** — confirm it is a real freeze, not a prove SIGKILL (`weston-autolaunch-prove.log` tail; see [`../nested-debug.md`](../nested-debug.md) §1) | debug | ✔️ real freeze — both mains blocked in `poll`, client debug log silent ~9 s before capture (not a SIGKILL) |
| P2 | **Prove the hang programmatically** — stay-up run to the freeze; capture **paired backtraces** of **both** `gnome-shell-rpc` (client) and `mutter-rpc` (server) at the hang (coredump or `gdb -p` with `ptrace_scope=0`). Identify the two blocked ends (sync send ↔ blocked recv/emit) and the **last in-flight RPC id/method** on each side | debug | ✔️ captured 09:40 — both ends + in-flight ids in the P2 result above (**raw capture since lost to tmp cleanup**, see P2b) |
| P2b | **Re-capture, durably** — the 09:40 folder under `/tmp` is gone, so every later question has to be re-asked of a live freeze. `scripts/hang-backtrace.sh` now writes to `~/.cache/gnome-shell-rpc/hang-*` (tmp fallback), keeps **whole** gzipped logs, adds `socket-queues.txt` (unread bytes in a receive queue = written-but-not-drained) and `in-flight.txt` (last send / last recv, plus which `Connection.vala` line read it → inside `hook.emit` or from the main loop). **Needs user to run at the next freeze** | debug | ☐ needs prove |
| P3 | **Reproduce in a smoke** — `src/gjs-embed/workarea-reentrant-emit-smoke.js` (drafted): asserts `set_builtin_struts` does **not** emit `workareas-changed` **on-stack** (the re-entrant corridor). Registered `workarea-reentrant-emit-smoke: done` in `SMOKE_OK_PAT`. **Needs user to run** (agent does not run the prove) | test area | ◑ drafted — needs prove (source read says it will FAIL: `Workspace.override.vala:15` emits inline, `syncHits>0`) |
| P4 | **Isolate outside the product** — `tests/call-sync-repro/reentrant-emit-call-gate.vala`: nested **sync** `call_poll` from inside a `Live.Invoke` handler while server blocked in `hook.emit`. **PASS (2026-09-18)** → transport is safe; **not** a raw OPC deadlock | test area | ✔️ PASS |
| P4b | **Isolate the remaining transport shape** — `tests/call-sync-repro/poll-burst-strand-gate.vala`: burst of Notifications coalesced ahead of the Invoke, server then silent inside `hook.emit`; client must drain past them. **PASS (2026-09-18)** → no starvation; fifth transport reduction to pass | test area | ✔️ PASS |
| P4c | **Isolate the live shape at volume** — `tests/call-sync-repro/nested-relay-storm-gate.vala`: depth-4 invoke nesting + re-entrant same-hook emits + sync `call_poll` inside invoke handlers + mid-dispatch Notifications, 400 rounds, measuring `bin.in_stream.get_available()` at the stall. **FAIL 5/5 (2026-09-18)**, 25–32 bytes unparsed | test area | ✔️ FAIL (wanted) |
| P4d | **Same-hook re-entrant emit** — `tests/call-sync-repro/same-hook-reentrant-emit-gate.vala`: nested `Hook.emit` on **one** callback id; inner reply released the outer (`Live.Hook.replied`/`reply_id` were per-row). **FAIL then**, **PASS now** — stock `Live.Hook.complete` (OPC per-emit frames) | test area | ✔️ PASS (fixed upstream) |
| P5 | **Decide OPC vs consumer** — **OPC**, client side. P4/P4b/P4c supersede the earlier "consumer" call: the single-shape gates passed only because one coalesced write usually splits across two reads. P4c measures the stranded reply | — | ✔️ OPC |
| P6 | **Propose + test the fix outside** — both pending tests to read `bin.in_stream.get_available()`; filed with verbatim fences, **applied upstream as `0bd32a82`** | test area | ✔️ fixed upstream |
| P6b | **Stopgap if we need the session before then** — cap the client's underlying reads below the smallest wire message; `GSR_STORM_CAP=8\|16` → **PASS** | test area | 🚫 not needed — P6 landed |
| P7 | **Verify against the fixed library** — `nested-relay-storm-gate` **FAIL → PASS 3/3**; full gate sweep 17 PASS; `clutter-interval-gvalue-gate` FAIL is a separate open FFI bug | test area | ✔️ PASS |
| P8 | **Live prove** — nested stay-up run to the IBus dismiss: does the freeze go away? **Needs user to run** (agent does not run the prove) | debug | ☐ needs prove |
| P9 | **P4d landed in OPC** — per-emit frames are stock `Live.Hook` + `Hook.complete`; `src/rpc/Hook.vala` deleted. `LiveCallback.reply` still owns the error-reply path, now routes through stock `complete`. | product | ✔️ |

### P5 fork (the rule)

- **Gate FAILs (OPC / libocrpc is the problem):** keep the **FAIL** gate under
  `tests/call-sync-repro/`, file the bug in **OLLMchat** `docs/bugs/`, **do not
  edit OLLMchat from this tree**, and **stop**. Do not file the OPC bug here.
- **Gate PASSes (consumer):** the fault is our **re-entrant emit / sync-call
  pattern**. Fix minimally in our tree (e.g. defer the offending emit/round-trip
  out of the handler, or make it async) — prove-first, no speculative churn.

---

## Prove commands

Stop-reason + stay-up + smoke (per [`../nested-debug.md`](../nested-debug.md)):

```bash
# Does it stay up / where does it freeze? (no A4/READY SIGKILL)
GSR_NESTED_STAYUP=1 GSR_NESTED_TIMEOUT=60 GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# classify: tail ~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log

# P3 repro smoke — expect FAIL (on-stack re-emit) on the current tree
GI_META_SMOKE=workarea-reentrant-emit-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# look for: workarea-reentrant-emit-smoke: FAIL reentrant-onstack-emit … (syncHits>0)
#   PASS would mean the emit is already off-stack (fixed)

# Two-process gates (P4 / P4b — built; agent runs these, they need no session)
ninja -C build tests/call-sync-repro/reentrant-emit-call-gate
timeout 8 ./build/tests/call-sync-repro/reentrant-emit-call-gate
ninja -C build tests/call-sync-repro/poll-burst-strand-gate
timeout 20 ./build/tests/call-sync-repro/poll-burst-strand-gate
# PASS → transport handles nested-sync-in-emit / burst stranding → chase consumer
# FAIL (timeout/err) → OPC re-entrant sync-RPC deadlock → OLLMchat bug, keep FAIL gate, stop

# P4c — THE repro (FAIL is the expected result today; ~5 s, self-terminating)
ninja -C build tests/call-sync-repro/nested-relay-storm-gate
./build/tests/call-sync-repro/nested-relay-storm-gate
# FAIL … "bin buffer at the stall: N bytes unparsed" → the reply was already
#   inside the client; call_poll cannot see it (OPC seam fix, P6)
# PASS → the OPC fix is in; this is now the regression gate
# GSR_STORM_HOLD=1 raises the call timeout to 600 s to hold the wedge open

# P2b capture — run in a second terminal the MOMENT it freezes
./scripts/hang-backtrace.sh   # prints the folder to paste back
```

Logs: `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log`
(last `method=` per side = in-flight at freeze).
Backtrace prep (`ptrace_scope`, coredumps, GJS symbols):
[`../nested-debug.md`](../nested-debug.md) §3–3b.

---

## What the next capture (P2b) must answer

Five transport reductions pass, so the next freeze has to say **which side
stopped moving**, not just that both are in `poll`. The capture now collects
exactly that:

1. **`socket-queues.txt`** — `Recv-Q` on either end of `mutter-rpc.sock`.
   Non-zero on the client side means the server's reply **was written** and the
   client is not draining it (consumer / client-side wait bug). Zero both ways
   means nobody wrote — a genuine cross-wait, and then the question is why the
   server's `emit_wait_poll` did not dispatch the pending request.
2. **`in-flight.txt`** — the last `recv id=… method=…` on the server and which
   `Connection.vala` line logged it. `src/rpc/Connection.vala` line numbers mean
   `drain_readable` read it **inside** `hook.emit`; OPC `Connection.vala:313`
   means it came from the main loop. That distinguishes "the server never got
   back to the socket" from "the server read it and the reply went missing".
3. **Whether the server dispatched the last request it read.** P2 recorded
   `recv get_name` then silence, while the backtrace showed no dispatch frame —
   those two cannot both hold unless the dispatch had already returned. The
   whole gzipped server log (now kept) settles it.

---

## Not this / guardrails

- **🚫** No git-bisect scoring by pass/fail (rejected — race).
- **🚫** No speculative Helper / stub / deny / JS / layout hacks in `src/` before
  a FAIL smoke or gate **names** the fix. Revert prototypes; do not leave them.
- **🚫** No invented GI methods on stock stubs.
- **🚫** No editing OLLMchat / libocrpc from this tree — OPC bugs go to OLLMchat
  with a FAIL gate here, then stop.
- **ℹ️** Agent does **not** run the nested prove; the **user** runs P1–P2 debug
  and each prove. Agent writes the smoke/gate, builds, and analyses captured
  backtraces/logs.
