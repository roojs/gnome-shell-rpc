# `Meta.Laters` callback intermittently SIGSEGVs in GJS

**Status:** ⏳ open. Reproduced every run by `tests/call-sync-repro/later-callback-nested-add.js` (exit 139, `g_closure_ref` on refcount 0). Full-shell boot is still intermittent because the nested `Laters.add` is intermittent.

**Plan:** [`0.8 init and interaction`](../plans/0.8-init-complete-and-interaction.md)

## Seen

Two full-shell probe runs reached `READY=1`, then `gnome-shell-rpc` died with SIGSEGV before the delayed overview snapshot:

```text
16:09:55 READY=1
16:09:58 gnome-shell-rpc SIGSEGV

16:17:00 READY=1
16:17:01 gnome-shell-rpc SIGSEGV
```

Both deaths are inside a stored `GLib.SourceFunc` that `run_before_redraw()` invoked from `ClutterStage::before-update`. The second stack was:

```text
g_type_is_a
libgjs
libffi
meta_laters_run_before_redraw
ClutterStage::before-update
shell_signals_emit
oll_mrpc_client_dispatch_message
```

The first core took the same path, but the `before-update` notification arrived nested, while `Clutter.Actor.is_mapped` was still in a sync poll. The second core was the ordinary main-loop dispatch.

`entry.func()` is a `GLib.SourceFunc`. GJS implements that as a C trampoline whose data pointer is the closure: the JavaScript function, plus the GObject that function was bound to (`this` on a `BEFORE_REDRAW` callback from `layout.js`, `workspaceThumbnail.js`, `dash.js`, or `Main.initializeDeferredWork`). `g_type_is_a` is the trampoline checking that GObject. The pointer is still non-null and the closure’s refcount was 2, but the GObject has already been destroyed, so the type check crashes.

GDB on the second core showed pending later id 6 still in our map. `LaterEntry` is only `func` and `when`. The function, data pointer, and destroy-notify GDB printed are the GJS closure, not fields we store, and not stock mutter’s `MetaLater`.

Nothing in the shell path watches a GJS object for destruction. `Shell.Signals` unsubscribes only on `disconnect` / `disconnect_id`, and the first `connect` does `proxies.set`, which keeps the client object. There is no “this lease is dead, drop anything further” mark. A later notification for that lease is still dispatched, and a `Laters` callback is still invoked. Stock GJS invalidates closures when the bound GObject is disposed. We never tell our layer that happened, so it keeps handing the dead object to GJS.

The flood of `instance ... has no handler with id ...` starts after the shell client dies, during teardown. It is not the initiating failure.

## Re-prove 2026-09-26

`gnome-shell-rpc` rebuilt 08:10, `mutter-rpc` rebuilt 07:59. Six stay-up probes with `src/shell-js-probe`, `GSR_NESTED_STAYUP=1`, `GSR_NESTED_NO_A4=1`, 40s cap. The last run loaded the overlay (`js override overlay 3 files`).

| Start | Client |
| ----- | ------ |
| 08:18 | `READY=1`, then 08:18:58 SIGTRAP (`int3` in `libglib`). Last log line `unsupported wire type 0x00`. Mutter also SIGTRAP, `ec=133`. |
| 08:28 | No kernel signal. Prove timeout, then the harness SIGKILL. |
| 08:29 | 08:29:50 SIGILL (`invalid opcode`). The kernel line names no module. |
| 08:30 | 08:30:32 SIGSEGV at address 9. No core. |
| 08:31:00 | No kernel signal. Prove timeout, then the harness SIGKILL. |
| 08:31:41 | `READY=1` at 08:31:48. No kernel signal. No `delayed15s` line in the client log. |

One SIGSEGV in six. The other two deaths are the glib `int3` and a SIGILL. Three runs produced no client signal. No core, so this pass does not add a stack.

`workarea-panel-chrome-smoke` registers one `BEFORE_REDRAW` callback and still passes. The full shell had four pending callbacks in the crashing dispatch. The nested `is_mapped` poll only explains how the first core re-entered `run_before_redraw`. The second core died without that nest.

## Rejected

Two table tweaks were tried and the full shell still SIGSEGVed. Neither remains in the source.

- A reentrancy guard around `run_before_redraw()`.
- Holding finished entries until the whole callback snapshot returned.

Those assume the crash is the queue freeing or re-entering a closure. The closure for id 6 was still alive. Patching the queue again, or writing a gate that replays “several closures plus a deferred-work drain”, models a queue bug we have not seen.

## 2026-09-26 hang is this call

Live boot looked hung. 08:47 gdb, no product edits:

```text
SIGSEGV at 0x7ffff0003f10 (unmapped, no module)
meta_laters_run_before_redraw   later_id=4
  entry.func(entry.func_target)     Meta_window_generated.vala:2030
before-update
shell_signals_emit
oll_mrpc_client_call_poll
```

The entry was still in the map. `LaterEntry.finalize` nulls `func` after the destroy notify, so finalize had not run. The function pointer was already an unmapped page.

`tests/call-sync-repro/later-callback-hold` stores an `owned` `GLib.SourceFunc` the same way and calls it after `run_dispose()` and `System.gc()`. The callback runs. `Meta.Laters.add` is already `scope="notified"`. Dispose of the bound object does not free the trampoline.

`tests/call-sync-repro/later-callback-reenter` runs the shell order outside the shell, then the variants that could drop the trampoline before the call: the same callback re-entered and removed while the outer call is still on the stack; the JS wrapper dropped while C holds the object; dispose from inside the callback with `poke()` from `vfunc_dispose`. All of those callbacks run. Process exit is 0. At shutdown GJS logs a critical that it blocked a `dispose()` vfunc during GC because that call would crash. That guard is inside the trampoline, after `g_closure_ref`. The shell SIGSEGV is that ref already failing, and this sample does not reach it.

## Named frame

Four dprintf-only stay-up boots. Run 4 SIGSEGV (`/tmp/gsr-laters-trace-4.txt`). `libgjs0g-dbgsym` 1.82.1-1 names it. Load bias `0x7ffff7be7000` (the destroy-notify pointer `0x7ffff7c1e310` lands on the first instruction of that function).

`later_id` was 6. `func` `0x7ffff0001830`, `func_target` `0x555556f87230`. That pair is the last `ADD` (`when=4`). Nothing `REMOVE`d or `FINALIZE`d it. The snapshot had 2 ids; index 1 is the crash. The in-flight call is `Clutter.Actor.get_children`.

```text
#0  GjsCallbackTrampoline::create_closure ffi lambda
      mov 0x38(%rbx), %rdi          # after g_closure_ref
#1  libffi
#2  libffi
#3  meta_laters_run_before_redraw   later_id=6
#27 Gjs::Function::invoke           gi/function.cpp:1056
#28 Gjs::Function::call             gi/function.cpp:1233
```

Offset `0x38` of `GjsCallbackTrampoline` is `m_info` (`GICallableInfo*`). `rbx` is what `g_closure_ref` returned for the ffi user_data. That user_data was not null: a null check in the lambda jumps elsewhere. `g_closure_ref` returns NULL when the closure refcount is already 0, and this instruction then faults at address `0x38`. This log has no fault address (gdb caught the signal; the kernel line is absent), so that is the path that reaches this instruction. A live trampoline is readable at `m_info`.

The ffi page itself was still mapped. The 08:47 hit is the other stage: `entry.func` was already the unmapped address, which is what `~GjsCallbackTrampoline` does with `g_callable_info_destroy_closure`.

Every `ADD` in the trace used destroy notify `0x7ffff7c1e310`, the start of the lambda in `Gjs::Arg::CallbackIn::in` at `gi/arg-cache.cpp:1068`. That lambda is `g_closure_unref` on the trampoline. Id 6 never reached it.

## Order in this code

`add()` stores the function and the `g_closure_unref` notify on `LaterEntry`. It does not call the function. `run_before_redraw()` calls `entry.func(entry.func_target)` while that entry is still in the map. The notify runs in `LaterEntry.finalize`, after the callback returns false and the map drops the entry, or from `remove()`.

The GJS ffi lambda refs the trampoline on the way in and unrefs it on the way out (`g_closure_ref` at the top, `jmp g_closure_unref` on the return). That pair is balanced once the ref succeeds. It is a separate unref from the notify stored on the entry.

Id 6 died on the way in. Finalize of that entry was still ahead, so the stored notify had not run, and the lambda's exit unref had not run either. `g_closure_ref` already saw refcount 0. The before-redraw call is in the right step. The trampoline's refcount hit 0 before that step, while the entry still held the notify.

## Reproduction

`tests/call-sync-repro/later-callback-nested-add.js`. Three runs, all exit 139:

```text
poke id=1
outer
poke id=2
g_closure_ref: assertion 'closure->ref_count > 0' failed
SIGSEGV
```

The inner callback is queued by `Later.add` while the outer `Later.add` has not returned. GJS 1.82 `CallbackIn::in` (`gi/arg-cache.cpp`) stores the ffi closure on the arg-cache field `m_ffi_closure`, then `CallbackIn::release` always `g_closure_unref`s that field when the C call returns. The nested `add` overwrites the field with the inner trampoline. The inner return unrefs it once (the extra ref from `in()`). The outer return unrefs it again, to 0. `LaterEntry` still holds the function pointer and the destroy notify at `arg-cache.cpp:1068`. That notify has not run. The next call is `g_closure_ref` on refcount 0, then the ffi lambda faults. Same pair as the shell: entry never finalized, refcount already 0.

`later-callback-hold` and `later-callback-reenter` still exit 0. They never call `add` from inside `add`.

Do not patch the `Laters` queue. Do not skip disposed callbacks.

This crash blocks the 15-second actor snapshot for [`overview picker`](2026-09-24-overview-picker-preview-gone.md). It does not replace that bug as the current UI target.
