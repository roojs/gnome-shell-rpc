# Nested `call_poll` reply never reaches server mid-`Hook.emit`

**Status:** ✔️ fixed — archived 2026-09-11 (`Rpc.Connection.emit_wait_poll` override)  
**Hit:** 2026-09-10 ~09:22 / ~09:43 nested Wayland (`call_poll` + in-flow Runtime)  
**Logs:** `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log`  
**OPC hook:** `OLLMchat/docs/bugs/2026-09-10-hook-emit-mid-dispatch-reply-unread.md` (`emit_wait_poll` virtual)  
**Fix:** `src/rpc/Connection.vala` + `Listen` accept path  
**Supersedes:** `docs/bugs/done/2026-09-09-runtime-idle-reply-hang.md` (Idle queue — fixed by dropping drain)  
**Related:** `docs/bugs/done/2026-09-09-layout-relay-call-sync-reentrancy.md`  
**Upstream OPC (already landed, not this bug):** `call_poll`, PollFD `revents`, `poll_drain_readable` buffer-condition  
**Follow-on (not this bug):** boot still dies later on `Clutter-DesaturateEffect.set_factor` mid-`new` — `unexpected byte 0xFD after 0xFF` (wire / nested construct).  

---

## Symptom

Nested chrome still stops mid-startup after many successful preferred/allocate
relays. No 120s `call timed out` in the short window; both sides sit quiet
after a partial nest.

Counts on the smoking-gun run:

| Side | Signal | Count |
|------|--------|------:|
| server | `emit BEGIN` | 16 |
| server | `emit END` | **15** (one emit left open) |
| client | `replied id=199` | **0** |
| server | `recv id=199` | **0** |

---

## Prove (2026-09-10 ~09:43, after Runtime invoke DBG)

Same hang, later in boot (keybindings / buttons), clearer counters:

| Counter | Value |
|---------|------:|
| server `emit BEGIN` / `END` | 53 / **52** |
| client invoke ENTER / REPLY start / REPLY done | 53 / 53 / **52** |

```text
server: preferred_width emit BEGIN hook_id=61
client: id=1563 Clutter-Actor.remove_all_transitions
client: DBG invoke ENTER id=61 reply_id=528
client: DBG invoke REPLY start → id=1564 RPC-Live-Callback.reply
server: recv id=1563 …
client: replied id=1563
server: never recv id=1564
client: never REPLY done id=61
```

**Stop:** needs OPC `Hook.emit` / connection read reentrancy — filed upstream.
Do not patch libocrpc from this tree.

## Fix (2026-09-10 ~10:09) — verified

OPC added virtual `Connection.emit_wait_poll()` (default =
`MainContext.iteration`). Consumer:

1. `src/rpc/Connection.vala` subclasses and overrides with `GLib.poll` +
   parse/dispatch (watch removed while depth &gt; 0).
2. Pending check includes `bin.in_stream.get_available()` and socket
   `get_available_bytes()` — otherwise a second Request already in the
   `DataInputStream` buffer leaves `poll(-1)` hung (seen: recv `set_style`
   then never recv nested `RPC-Live-Callback.reply`).
3. `Listen` accept path constructs `GnomeShellRpc.Rpc.Connection`.

Prove (`timeout 30 … --wayland --nested`):

| Counter | Before | After |
|---------|-------:|------:|
| emit BEGIN / END | 219 / 218 | **226 / 226** |
| invoke ENTER / REPLY done | 219 / 218 | **226 / 226** |
| open emits at stop | 1 | **0** |

Panel allocate boxes include `(0,0)-(800,32)`. Hang shape gone.

Later boot still stops around `Clutter-DesaturateEffect.new` + nested
`set_factor` with client `unexpected byte 0xFD after 0xFF` — separate issue.

---

## Smoking gun (09:22:41, first capture)

Paired work just before the hang (same millisecond):

```text
server: preferred_width  BEGIN/END hook 34  ↔  client: get_monitor_manager + reply 195
server: preferred_height BEGIN/END hook 35  ↔  client: Helper-Background.create + reply 197
server: preferred_width  BEGIN hook 27        ← never END
        recv set_color 198
client: set_color 198
        RPC-Live-Callback.reply 199           ← nested; never recv / never replied
        replied 198
```

So:

1. Server opens sync `Hook.emit` (preferred_width hook 27) and waits on
   `MainContext.default().iteration`.
2. Client preferred handler (still inside invoke #1) issues
   `Meta-Background.set_color` (198).
3. While client waits for 198, a **second** `Live.Invoke` is demuxed →
   nested `call_poll(RPC-Live-Callback.reply)` (199).  
   (Runtime only sends the reply *after* the handler returns, so 199 cannot
   be invoke #1’s reply — that reply has not been sent yet.)
4. Response for 198 arrives; outer `call_poll` completes.
5. **199 never shows as `recv` on the server and never as `replied` on the client.**
6. Emit hook 27 never ends → layout stuck. BEGIN=16 END=15.

`call_poll` logs `id=N method=…` *before* `bin.write` + flush. Seeing
`id=199` means the nested frame entered; absence of server `recv id=199`
means the Request did not land in `Connection.on_input_ready` (not written,
not read, or not dispatched).

Important constraint: client got `replied id=198`, so the server **finished**
`Meta-Background.set_color` and wrote its Response even though nested reply
199 never arrived. So either invoke #2’s `Hook.emit` is not on the set_color
call stack, or set_color returned without waiting for that nested emit.

---

## What this is *not*

- Not the old **Idle drain** hang (`schedule_drain` / queue never emptied).
  Runtime now replies in-flow via `call_poll`.
- Not the OPC **head-only pending send** bug (that blocked nested write until
  outer timeout; here outer 198 completes and nested still never arrives).
- Not proven as “JS preferred is wrong” yet — first open emit after a long
  stretch of paired BEGIN/END is transport / emit-reenter shaped.

---

## Working hypotheses (ordered)

### H1 — Server IO watch cannot re-enter while `Hook.emit` iterates (favored)

`Hook.emit` waits with `MainContext.default().iteration(true)`. The same
default context owns `Connection`’s read watch. If we are already inside
`on_input_ready` → request dispatch → layout → `emit`, a nested
`iteration` may not re-dispatch that watch (`G_HOOK_FLAG_IN_CALL`).

Then:

- Outer emit waits for reply.
- Client can still make progress on *responses already in flight* (198).
- Nested reply Request (199) sits unread → both sides block.

Matches `tests/call-sync-repro/` `stack` mode (server defer mid-dispatch).

### H2 — Client nested `call_poll` write/flush lost or stalled

Less likely if flush ran, but possible if write blocked on a full socket
while the server was not reading (same root as H1 from the other side).

### H3 — Nested emit / wrong reply_id routing

`set_color` (or work it triggers) causes a *second* `Hook.emit` while the
first is open. Client replies to one invoke; the open emit is the other.
Needs reply_id / hook_id breadcrumbs to confirm.

---

## Current tree (relevant)

- `src/gi-stub/Runtime.vala` — `do_call` → `call_poll`; Live.Invoke replies
  in-flow (no Idle queue).
- `src/rpc/helper/ClutterActor.vala` — Constraint-shaped sync `Hook.emit`
  (+ DBG BEGIN/END).
- Linked `libocrpc` from `~/gitlive/OLLMchat/build/libocrpc/`.

---

## Next diagnose steps (debug only)

1. **Breadcrumbs:** log `Live.Invoke` `id` / `reply_id` on client enter, and
   whether `call_poll` finished `write`+`flush` for nested reply (after-write
   DBG). On server, log when `Callback.reply` marks `replied`.
2. **Confirm H1:** under hang, server bt should show
   `Hook.emit` → `g_main_context_iteration` → (optional nested dispatch) with
   unread socket data; or prove socket has 199 still in client send buffer.
3. **Harness:** extend `tests/call-sync-repro/` so client does child GI
   *then* nested reply while server emit cannot reenter `on_input` — expect
   FAIL matching “outer Response yes, nested reply never recv”.
4. Do **not** reintroduce Idle drain; do **not** patch OPC from this tree
   until H1/H2 is pinned.

---

## Done when

- Preferred/allocate BEGIN/END stay paired through `notify_ready`, **or**
- Harness FAIL + one agreed fix (server emit pump that can read mid-dispatch,
  or consumer contract that forbids GI-inside-preferred that re-enters emit).
