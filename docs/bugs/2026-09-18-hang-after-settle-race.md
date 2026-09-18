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

**Status:** ⏳ open — **active**. Nested session **hangs** at/near the **IBus
notification dismiss**. Intermittent on old states, **~every time at HEAD**
(`8765ee3`).

**Supersedes (git approach rejected):**
[`done/2026-09-18-hang-after-settle-git-bisect-rejected.md`](done/2026-09-18-hang-after-settle-git-bisect-rejected.md)
— reuse its **file-level audit** and **sync-RPC / re-entrant-emit call-site
table**.

**Method:** dissect by **prove-first**, not git. Prove the hang
programmatically (debug) → reproduce in a **smoke** → isolate in a **two-process
gate** → propose + test the fix **outside the product tree** → only then land a
**minimal** change. **🚫 No churning hacks into `src/` to “try” a fix.**

**Working tree:** currently `8765ee3` content (the deterministic-hang tip),
built. HEAD stays `e9010e8` (diff-only).

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

**Fix candidate to prove (consumer, minimal):** break the re-entrant
workareas-changed emit so it does not fire a sync `get_work_area_for_monitor`
inside a `Live.Invoke` handler — e.g. drop the manual re-emit in
`set_builtin_struts` and/or defer the `workareas-changed` client emit to an
idle (out of the relay/emit stack), and narrow `Runtime.vala`'s `default`
re-emit. Prove-first: needs a **P3 FAIL smoke** (overview + workareas-changed
during an LM preferred-height relay) before touching `src/`.

---

## Plan (walk top → bottom; tick per step)

| # | Step | Area | Status |
| - | ---- | ---- | ------ |
| P1 | **Classify the stop** — confirm it is a real freeze, not a prove SIGKILL (`weston-autolaunch-prove.log` tail; see [`../nested-debug.md`](../nested-debug.md) §1) | debug | ☐ |
| P2 | **Prove the hang programmatically** — stay-up run to the freeze; capture **paired backtraces** of **both** `gnome-shell-rpc` (client) and `mutter-rpc` (server) at the hang (coredump or `gdb -p` with `ptrace_scope=0`). Identify the two blocked ends (sync send ↔ blocked recv/emit) and the **last in-flight RPC id/method** on each side | debug | ☐ |
| P3 | **Reproduce in a smoke** — `src/gjs-embed/workarea-reentrant-emit-smoke.js` (drafted): asserts `set_builtin_struts` does **not** emit `workareas-changed` **on-stack** (the re-entrant corridor). Registered `workarea-reentrant-emit-smoke: done` in `SMOKE_OK_PAT`. **Needs user to run** (agent does not run the prove) | test area | ◑ drafted — needs prove |
| P4 | **Isolate outside the product** — `tests/call-sync-repro/reentrant-emit-call-gate.vala`: nested **sync** `call_poll` from inside a `Live.Invoke` handler while server blocked in `hook.emit`. **PASS (2026-09-18)** → transport is safe; **not** a raw OPC deadlock | test area | ✔️ PASS |
| P5 | **Decide OPC vs consumer** — **CONSUMER** (P4 PASS rules out transport sync-in-emit deadlock) | — | ✔️ consumer |
| P6 | **Propose + test the fix outside** — prototype in the gate/smoke; prove it flips **FAIL → PASS** *there* before touching `src/` | test area | ☐ |
| P7 | **Land minimal** — only the stock-shaped change the gate/smoke named; re-run smoke + stay-up | product | ☐ |

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

# Two-process gate (P4 — built)
ninja -C build tests/call-sync-repro/reentrant-emit-call-gate
timeout 8 ./build/tests/call-sync-repro/reentrant-emit-call-gate
# PASS → transport handles nested-sync-in-emit → chase consumer
# FAIL (timeout/err) → OPC re-entrant sync-RPC deadlock → OLLMchat bug, keep FAIL gate, stop
```

Logs: `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log`
(last `method=` per side = in-flight at freeze).
Backtrace prep (`ptrace_scope`, coredumps, GJS symbols):
[`../nested-debug.md`](../nested-debug.md) §3–3b.

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
