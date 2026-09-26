# Client dies just after `READY=1`; the window looks hung

**Status:** same crash as [`2026-09-25-meta-laters-callback-segv.md`](2026-09-25-meta-laters-callback-segv.md). The 08:47 gdb stack is `meta_laters_run_before_redraw`. A later trace names the GJS instruction: the ffi lambda loads `GjsCallbackTrampoline::m_info` after `g_closure_ref`. Fix work stays on that bug.

**Plan:** [`0.8 init and interaction`](../plans/0.8-init-complete-and-interaction.md)

## Seen

The user was booting the standard nested session and the window stayed hung. Mutter was still logging pointer motion after the client had already died. Nothing was waiting on an unanswered RPC.

Two client deaths, then Weston:

| Time | What died |
| ---- | --------- |
| 08:39:31 | `gnome-shell-rpc` general protection fault in `g_type_check_instance_is_fundamentally_a` (`libgobject` offset `0x42b42`, symbol at `0x42b10`). That boot's log was overwritten by the next client. |
| 08:40:20 | `READY=1`. |
| 08:40:21 | `gnome-shell-rpc` SIGSEGV. Kernel line names no module: `segfault at 6066f7d311c5 ip 0000755bf00a2f10 error 6`. No core (`systemd-coredump` is not installed). |
| 08:41:00 | Weston SIGSEGV in `desktop-shell.so` (`segfault at 24c`). The session is gone. |

Last client lines before the 08:40 SIGSEGV, all replied until the final notification:

```text
id=8381 method=Meta-Barrier.new                         replied
notification method=before-update
id=8382 method=Meta.prefs_get_dynamic_workspaces        replied
id=8383 method=Meta-Compositor.get_laters               replied
id=8384 method=Clutter-Actor.get_children               replied
id=8385 method=Clutter-Actor.get_transformed_position   replied
id=8386 method=Clutter-Actor.get_transformed_size       replied
id=8387 method=Clutter-Actor.get_transformed_position   replied
id=8388 method=Clutter-Actor.get_transformed_size       replied
id=8389 method=Meta-Display.get_monitor_index_for_rect  replied
id=8390 method=Meta-Workspace.set_builtin_struts        replied
id=8391 method=Meta-Workspace.get_work_area_for_monitor
notification method=workareas-changed
id=8392 method=Meta-Workspace.get_work_area_for_monitor
notification method=before-update
```

`8391` and `8392` have no `replied` line. The log ends on the second `before-update`.

`g_object_set_is_valid_property` for `allocation` on `StBoxLayout` and `StWidget` was logged about 160ms earlier. Replies continued after those criticals.

## Stack

08:47, `GI_META_GDB=batch` on a stay-up boot (no product edits). Thread 1 SIGSEGV at `0x7ffff0003f10`, which is not in a mapped module. `later_id` was 4. The call is `entry.func(entry.func_target)` and that function pointer is the faulting address.

```text
meta_laters_run_before_redraw   Meta_window_generated.vala:2030
before-update lambda            Meta_window_generated.vala:2013
shell_signals_emit              before-update
oll_mrpc_client_dispatch_message
oll_mrpc_client_call_poll
```

`call_poll` is on the stack, so this `before-update` arrived while a sync RPC was still in progress. That matches the 08:40 log ending on nested `workareas-changed` / `before-update` during `get_work_area_for_monitor`.

## Outside the shell

`tests/call-sync-repro/later-callback-hold` stores one `owned` `GLib.SourceFunc` and calls it after `run_dispose()` and `System.gc()`. It passes: the callback still runs. `Meta.Laters.add` is already `scope="notified"` in the typelib. Disposing the bound object does not free the trampoline.

`LaterEntry.finalize` is what calls the destroy notify and then nulls `func`. This entry was still in the map, and `func` was not null, so finalize had not run. The code page was already gone anyway.

## Fix

Not a queue guard. Not "skip the callback because the object was disposed" — the outside holder shows that call is still valid.

The later id has to leave the table in the same step that releases the trampoline. That step is not `LaterEntry.finalize` on this crash. Do not patch `src/` until that release is named.
