# Greeter login stays on a black screen

**Status:** ⏳ open. User 2026-10-03. Logged in as `alan2` from GDM, session **GNOME Shell RPC**. The VT stayed black.

**Plan:** [`../plans/1.2-teardown-and-restart.md`](../plans/1.2-teardown-and-restart.md) is the active plan. This is the installed greeter session from [`../plans/done/1.1-installable-bootable-session.md`](../plans/done/1.1-installable-bootable-session.md).

Separate from [`2026-10-03-frames-stop-after-shell-started.md`](2026-10-03-frames-stop-after-shell-started.md). That one is a nested debug boot that logs `GNOME Shell started` and then stops framing. This login never logged that line.

The 2026-10-04 `alan2` login is [`2026-10-04-greeter-crash-screen.md`](2026-10-04-greeter-crash-screen.md). That one paints the crash screen. The client dies on a missing `clutter_event_get_scroll_source`, not this end-of-stream abort.

## Seen

2026-10-03 09:54:45. GDM password login for `alan2` (uid 1002). `gdm-wayland-session` ran `gsr-session`, which ran `gnome-session --session=gsr` (`GDMSESSION` set). Session 140, type wayland, VT 4. As of 09:59 the session was still up and `Active=no` (another seat session in front).

Two `gsr-server --wayland` processes started in the same second:

| PID | Who started it | Result |
| --- | --- | --- |
| 226938 | `gnome-session-binary`, scope `app-gnome-org.gnome.ShellRpc-226938.scope` | Still running. Children: `Xwayland :3`, `mutter-x11-frames`. No journal lines of its own. |
| 226946 | `org.gnome.ShellRpc@wayland.service` | Exited 1. Journal: `Failed to setup: Native backend mode needs to be session controller`. Unit `Failed with result 'exit-code'`. |

`gsr-client` 227147 was the child of the surviving server (`PPid` 226938). It is gone. Kernel at 09:54:48: `trap int3` in `libglib-2.0.so.0.8400.1`. Signal 5, `SIGTRAP`.

`/var/crash/_usr_bin_gsr-client.1002.crash` unpacked to a core and no `Stacktrace` file. `gdb` on `/tmp/gsr-client-crash/CoreDump`:

```text
#0  g_logv
#1  g_log
#2  oll_mrpc_client_poll_drain_readable  ../libocrpc/Client.vala:702
      GLib.error("%s", e.message);
      e.message = "Unexpected early end-of-stream"
#3  oll_mrpc_client_on_read              ../libocrpc/Client.vala:735
#7  g_main_loop_run
#8  meta_context_run_main_loop
#12 Gjs::Function::invoke
#23 gsr_client_application_real_command_line  ShellApplication.vala:160
```

`Client.vala:702` is the `catch` around `bin.parse()` / `dispatch_message()`. `GLib.error` aborts. The string is GLib `DataInputStream` hitting EOF in the middle of a fixed-width read. The server process was still alive, so this is the client killing itself on a short read, not the compositor exiting.

Journal lines from that client, then nothing. No `JS ERROR`. No `GNOME Shell started`. No server `connection write error` line (the surviving `gsr-server` wrote nothing to the journal). `gnome-session-binary` logged `Entering running state` at 09:54:48.

```text
09:54:47.563  G_LOG_LEVEL_CRITICAL : GLib-GObject : g_value_get_object: assertion 'G_VALUE_HOLDS_OBJECT (value)' failed
09:54:47.577  G_LOG_LEVEL_CRITICAL : GLib : g_atomic_ref_count_dec: assertion 'old_value > 0' failed
… same refcount critical, repeated …
09:54:47      Unset XDG_SESSION_ID, getCurrentSessionProxy() called outside a user session. Asking logind directly.
09:54:48.035  G_LOG_LEVEL_CRITICAL : GLib-GObject : g_object_set_is_valid_property: property 'mapped' of object class 'Gjs_ui_dateMenu_DateMenuButton' is not writable
09:54:48.388  G_LOG_LEVEL_CRITICAL : GLib-GObject : g_object_set_is_valid_property: property 'mapped' of object class 'Gjs_ui_panel_QuickSettings' is not writable
09:54:48.591  last journal line (another refcount critical)
```

`XDG_SESSION_ID` unset is the stock logind fallback. It is not the abort by itself.

## What is wrong

The screen is black because the compositor that owns the session has no client. `gsr-client` aborted in `poll_drain_readable` (`Unexpected early end-of-stream`) while building chrome (`DateMenuButton`, `QuickSettings`).

The systemd unit lost because a server was already the session controller. Stock `org.gnome.Shell.desktop` has `X-GNOME-HiddenUnderSystemd=true`, so `gnome-session` does not launch it and `org.gnome.Shell@wayland.service` is the one compositor. `data/applications/org.gnome.ShellRpc.desktop` has no such key, and `gsr.session.conf` still `Requires=org.gnome.ShellRpc.target`, whose service is also `gsr-server --wayland`. Both start. The desktop-file process wins the session. The unit exits 1.
