# After READY: open `preferred_width` emit, no client Invoke, A4 stuck

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
>    credentials, a machine/session you cannot reach, or explicit approval the
>    plan forbids you from assuming. Say what you need in one short ask, then
>    wait.
> 2. **OPC / libocrpc is the problem** — and only then: write a **FAIL-backed**
>    bug (gate under `tests/call-sync-repro/` that **FAIL**s, plus the bug doc),
>    **do not edit OLLMchat from this tree**, and **stop**. That is the **only**
>    OPC-related stop. PASS gates → chase the **consumer**; do not stop to
>    “report” a theory.
>
> ## Everything else
>
> File/update the tracking bug, pick the next allowed step, rebuild, prove,
> repeat. No Idle/defer/helper thrash. No layout.js ship hacks.

**Status:** 🔍 open — tracking only; do not thrash fixes without a named next step  
**Hit:** 2026-09-12 nested Weston (`weston-gsr-prove.sh`)  
**Plan:** [`docs/plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md) A4  
**Logs:** `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log`  
**Prove:** `./scripts/weston-gsr-prove.sh` (default **5s** / settle **1s** — do not raise)

**🚫** No OLLMchat / libocrpc edits from this tree.  
**🚫** No OPC bug filing without a **FAIL** gate under `tests/call-sync-repro/`.  
**🚫** No `Idle.add` / emit-defer queues / `run_emit` helpers on `Connection`.  
**🚫** No layout.js `PRIORITY_*` override as ship path.

---

## Symptom (A4)

Stock nested session reaches **A2** (`READY=1` / `notify_ready`) and often
**A5** (ENTER == REPLY done at kill), but never:

- `Meta.is_restart`
- layout `startup-complete`

User-visible chrome stays in the same stuck-after-boot state.

---

## Smoking-gun timeline (2026-09-12 ~13:12 prove)

| Time | Side | Event |
|------|------|--------|
| 13:12:29.125 | client | `READY=1` |
| 13:12:29.125 | client | `Meta-Context.notify_ready` (id=8392) |
| 13:12:29.125 | client | invoke ENTER **583** (preferred_height) nested in that wait |
| 13:12:29.127 | client | `layout_relay preferred_height` panel **chain=true** min=0 nat=0 → reply **extra=null** |
| 13:12:29.128 | client | REPLY done 583 |
| 13:12:29.128 | server | preferred_width BEGIN **1253** (nested under path=base for 583) |
| 13:12:29.335 | server | END 1253 **path=base** replied=true (~207ms, **no** client ENTER for reply_id=1942) |
| 13:12:29.335 | server | END 583 path=base min=32 nat=32 |
| 13:12:29.335 | server | preferred_width BEGIN **581** |
| after | client | **silence** — no `DBG invoke ENTER` for 581 |
| settle | both | quiet until prove kill; `is_restart` / `startup-complete` = 0 |

A5 on that run: ENTER=251 REPLY=251 (balanced at kill; last server emit still open).

---

## Ruled out (do not re-open without new FAIL)

| Hypothesis | Gate / evidence | Result |
|------------|-----------------|--------|
| Idle-after-return drops Invoke | `after-reply-gate` (earlier) | **PASS** |
| Response then emit B same turn (after emit A) | `tests/call-sync-repro/after-reply-gate` | **PASS** |
| Response then emit, no prior emit A (buffer) | `tests/call-sync-repro/buffer-invoke-gate` | **PASS** (`invoke_n=0` at `call_poll` return, then INVOKE on MainContext) |
| Mid-emit defer of non-reply Requests | live prove | **DEADLOCK** — layout invoke needs nested `get_width` / `remove_child`; deferred forever |

→ **Not an OPC filing** on buffered-Invoke / `poll_drain` `get_available` until a gate **FAIL**s.

---

## Rejected approaches (do not revive)

| Approach | Why rejected |
|----------|----------------|
| `emit_guard` / per-helper emit locks | Hacky; user rejected |
| `LayoutHooks.suppress_emit` | Same as emit_guard — **reverted** |
| `Connection.run_emit` / `emit_section_*` / `emit_allow_method` helpers | Forbidden helpers; wrong layer |
| Defer all non-`RPC-Live-Callback.*` mid-`emit_wait_poll` | Deadlocks required nested RPCs |
| `GLib.Idle.add` to flush deferred | Explicitly forbidden (Idle mid-RPC) |
| Editing `OLLMchat/libocrpc` from this tree | Plan 🚫; need FAIL gate first |

---

## Consumer work already landed (hygiene / related — not A4 green)

| Change | Intent | A4 effect |
|--------|--------|-----------|
| `Helper.Actor` clear `reply_args` before emit | Avoid stale path=js | Hygiene only |
| `BackgroundImageCache.load` / Selection* — no nested `MainLoop`; reply when signal/async completes | Stop default-context re-entry mid-emit | Unproven for A4; load rarely seen on this prove path |
| `Connection` back to poll+drain only | After defer revert | Baseline |

---

## Hypothesis H1 (tried — wrong for A4)

**Empty JS reply → skip `base` → 0,0.** Cleared some open-emit hangs but
panel allocated at **height 0** (`box=(0,0)-(800,0)`); post-READY silence after
`BackgroundImageCache.load` / `is_loaded`; A4 still red. **Reverted** — empty
preferred again uses `path=base`.

---

## Hypothesis H2 (tried — not the empty-return cause)

Empty returns after READY show **`in_map=true`**, no `emit_wait_poll HUP/ERR`.
So not `Connection.stop` / `Hook.drop` for those; they are real
`Callback.reply` with `extra=null` (layout_relay `chain=true`).

---

## Hypothesis H3 / H5 (path=base + null self-hooks)

Empty preferred → `path=base` with this actor’s hooks cleared for the
`base.get_preferred_*` call. Panel can get **min=32**. Still open trailing
preferred when a **child** emit runs after the client left the outer invoke.

## Hypothesis H2′ (confirmed on prove)

`emit_wait_poll` saw **`HUP/ERR revents=25` (IN|ERR|HUP)** ~165ms after
client `REPLY done`, called **`stop()`**, empty return `in_map=false`, then
later `Hook.emit` **write no-op** + infinite wait (open BEGIN). Softened to
wake hooks without mid-base `stop()`.

## Hypothesis H7 (active)

layout_relay chain → wire **`dd(0,0)`** instead of `extra=null`. Server takes
JS path (no post-reply `base` / nested child emit). Prove: past READY to
`BackgroundImageCache.load` / `is_loaded`; panel allocate height **0**; still
no `Meta.is_restart`. Confirms hang was nested emit after empty reply; A4 wall
is now prepare-idle / `SystemBackground.loaded` (sizes still wrong).

## Allowed next steps

1. **Document-only / prove:** `./scripts/weston-gsr-prove.sh` — **forced 5s** nest
   (ignores stale `GSR_NESTED_*`); autolaunch kills Weston when prove exits;
   outer `timeout 15` wall. Do not raise timeouts for agents.
2. **Landed consumer:** `Helper.LayoutHooks` (pop whole set for `base` on empty
   chain reply); `emit_wait_poll` wakes hooks on HUP without mid-base `stop()`.
   Investigation `GLib.debug` breadcrumbs removed.
3. **New FAIL gate only** if a shape is isolated that `buffer-invoke-gate` /
   `after-reply-gate` do not cover — then file OPC.
4. **One consumer hypothesis at a time**, named in this bug, with before/after
   prove scores. No shotgun Connection changes.

**Done when:** A4 markers green on stock nested prove, or this bug closed as superseded by a more specific FAIL-backed bug.
