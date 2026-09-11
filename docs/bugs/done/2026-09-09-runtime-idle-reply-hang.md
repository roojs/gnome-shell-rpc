# Runtime Idle(default) reply hangs mid-`call_sync`

**Status:** ✔️ root cause fixed in consumer (dropped Idle queue; use `call_poll` in-flow)  
**Follow-on hang:** `docs/bugs/done/2026-09-10-nested-reply-mid-emit-hang.md`  
**Hit:** 2026-09-09 / 2026-09-10 nested Wayland  
**Repro harness:** `tests/call-sync-repro/` (Idle / queue modes)  
**Upstream related:** `OLLMchat/docs/bugs/2026-09-10-call-sync-nested-io-watch-reentrancy-hang.md`  

---

## What we are debugging (do not “fix” yet)

Live `gnome-shell-rpc` eventually stops making progress during shell startup.
Earlier sessions looked like a hang around `Clutter-Actor.remove_child` / nested
`RPC-Live-Callback.reply`. Do **not** treat wire replies alone as proof of health.

---

## Debug instrumentation added (only)

Temporary `GLib.debug("DBG …")` in:

- `src/gi-stub/Runtime.vala` — `do_call` enter/leave, invoke, enqueue, schedule_drain, drain Idle, run_and_reply
- `src/rpc/helper/ClutterActor.vala` — allocate `Hook.emit` begin/end

No behavioral fix in this pass.

---

## Smoking-gun log (2026-09-10 08:22)

From `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` around first layout
`remove_child`:

```text
LEAVE Clutter-Actor.add_child … pending=0
ENTER Clutter-Actor.remove_child depth=1
id=44 method=Clutter-Actor.remove_child
DBG invoke id=17 reply_id=22 sync_depth=1 pending=0
DBG enqueue Live.Invoke id=17 sync_depth=1 queue_len=1
replied id=44
LEAVE Clutter-Actor.remove_child depth=0 pending=1
DBG schedule_drain queue_len=1 sync_depth=0
ENTER Clutter-Actor.add_child depth=1          ← ~42µs later, still same JS turn
…
LEAVE … pending=1                              ← pending stays 1 for ~1500 RPCs
…
DBG enqueue Live.Invoke id=343 … queue_len=2   ← first invoke still never drained
```

Counts from that run:

| Event | Count |
|-------|------:|
| `DBG enqueue` | 2 |
| `DBG schedule_drain` | 1 |
| `DBG drain Idle fired` | **0** |
| `DBG run_and_reply` | **0** |

So: Live.Invoke is **queued** while `sync_depth > 0`, `schedule_drain` arms a
default-context Idle, then JS immediately issues another `call_sync`. Default
Idle **never runs**. Queued invokes are never handled / never replied.

Server side (`Hook.emit`) waits on `MainContext.default().iteration` for
`RPC-Live-Callback.reply`. That reply is sitting in the client queue. Classic
deadlock shape from the layout-relay design doc:

> client invoke queue + server sync `Hook.emit` = hang

---

## Why `remove_child` can still “reply” while an invoke is queued

Working hypothesis matching the timeline:

1. Prior `add_child` finished; server layout Idle (or similar) later `Hook.emit`s.
2. Client is already inside next `call_sync(remove_child)` private pump.
3. Invoke is read on that private context → **queued** (no reply).
4. Server emit loop still iterates default context → can still dispatch
   `remove_child` and send `Response(44)`.
5. Client leaves depth 0, schedules Idle drain, then **does not return to the
   default main loop** before the next stub `call_sync`.
6. Drain Idle never fires; server remains blocked in `Hook.emit`.

Later `get_width` (id≈1540) enqueues a second invoke (`queue_len=2`) and the
client sits in `do_poll` / private wait.

---

## GDB

- Direct `gdb -p` failed here: `yama/ptrace_scope=1` + Cursor shell is not an
  ancestor of the nested Wayland client (`Inappropriate ioctl for device`).
- Project already supports `GI_META_GDB=wait` (`-Drpc_gdb_spawn=true`):
  mutter spawns `gdbserver localhost:9234 --args gnome-shell-rpc …`.
  Attach with:
  ```bash
  gdb ./build/src/gnome-shell-rpc
  (gdb) target extended-remote localhost:9234
  (gdb) continue
  # after hang:
  (gdb) thread apply all bt
  ```
- Not required for the queue/Idle conclusion above; use when a C stack is needed.

---

## Working-tree note (important for interpretation)

Current tree is **not** clean HEAD:

- `Runtime.vala` has expedition `sync_depth` + invoke **queue** + Idle drain
  (plus in-flow reply inside `run_and_reply` — but run_and_reply never runs if
  queued forever).
- `ClutterActor.vala` was stripped toward sync `Hook.emit` (Constraint-shaped).

HEAD still Idle-defers allocate emit on the server and Idle-defers reply on the
client. Mixed WIP makes live behavior easy to misread — breadcrumbs above are
from the **current** WIP binary.

---

## Harness gap

`tests/call-sync-repro/` `stack` mode models **server** non-reenter deferral
(`server: DEFER`). Live hang shown here is **client** queue + Idle never
draining. Next debug step in the harness: add a mode that queues invoke while
`sync_depth > 0` and only drains on default Idle, while JS keeps calling
`call_sync` without yielding — expect FAIL matching `pending` stuck / no
`run_and_reply`.

---

## Next (still debug-only until agreed)

1. Optionally confirm server thread is in `Hook.emit` via `GI_META_GDB=wait` + bt.
2. Teach `repro.vala` the client-queue / no-yield Idle drain failure.
3. Only then design a fix (do not land more Idle hacks without a contract).
