# Boot crash, and Log Out hangs

**Status:** ⏳ open. User 2026-10-05. Two failures on the installed greeter session, tracked here together.

Earlier logins: [`2026-10-03-greeter-login-black-screen.md`](2026-10-03-greeter-login-black-screen.md), [`2026-10-04-greeter-crash-screen.md`](2026-10-04-greeter-crash-screen.md).

## Boot crash

The shell does not stay up. The user gets the crash screen at login.

2026-10-05 10:43. `alan2` from GDM. Installed 10:40: `/usr/bin/gsr-client`, `/usr/bin/gsr-server`. Desktop file has `X-GNOME-HiddenUnderSystemd=true`. Only `org.gnome.ShellRpc@wayland.service` started. No second server, no `Native backend mode needs to be session controller`.

`gsr-server` 383450 spawned `gsr-client --debug` 383844. The client journal runs through theme, `DateMenuButton`, then at 10:43:09 stops on `property 'mapped' of object class 'StEntry' is not writable` and the same for `StWidget`, mid `Clutter-Actor.is_mapped`. No `JS ERROR`. No `too much recursion`. No `Unexpected early end-of-stream`. No kernel `trap`. No new file under `/var/crash/` (the `gsr-client` crash there is still the 09:42 one).

By 10:44 both processes are gone. `gnome-session-binary --session=gsr` (383306) is still running.

The 10:08 login, before this install, died in a re-entered `WorkspaceTracker._checkWorkspaces` (`append_new_workspace` on every nested `before-update`). `Laters.run_before_redraw` in this install does not run the queue from inside a later. This boot still does not stay up.

## Log Out hangs

Log Out on the crash screen does not return to GDM.

The 10:40 `gsr-server` calls `context.terminate()` from the button handler. That runs mutter shutdown on the click, so the button sits there. When the compositor does exit, `gnome-session-binary --session=gsr` is still the logind session, and the greeter does not come back. `SessionManager.Logout` is rejected before the running phase.

`on_crash_logout` no longer calls `terminate()`. On a real backend it `SIGKILL`s every other process of this user, which includes `gnome-session`, then `SIGKILL`s itself. Nested (`MetaBackendX11Nested`) only kills this process, so a nested run does not take the host desktop with it. Installed 10:54:08 together with `gsr-client`. User: neither fix worked.

10:54:28 `gsr-server` 394103, `gsr-client` 394514. `READY=1` at 10:54:31. Last client criticals are `mapped` not writable on `QuickSettings`, `StEntry`, and `StWidget`. No abort string. Kernel at 10:54:38: `gsr-client` `trap int3` in `libglib-2.0.so.0.8400.1` at offset `0x73e0f`. No new core. One second earlier the greeter `gnome-shell` 393297 logged `Xwayland terminated, exiting since it was mandatory` and `Xwayland exited unexpectedly` from `init.js`. That process is not `gsr-client`.

## Seen again — 2026-10-05 15:30

Machine `192.168.88.197`, user `alan`. Installed `gsr-server` and `gsr-client`
were timestamped 15:29:43. The server was PID 9952 and the first client was
PID 10211.

This death is identified. At 15:30:56 the first `notify::value` on an
`St.Adjustment` is immediately followed by `St-Adjustment.set_value`. Every
server notify is applied by libocrpc `Client.vala` with
`proxy.set_property(prop_name, value)`. A generated RPC proxy's public setter
is not local storage: it sends `St-Adjustment.set_value` back to the server.
The returned notify repeats the write.

The loop grew from request 10728 at 15:30:56.617 to request 16654 at
15:31:01.981. The Apport report is for PID 10211 at 15:31:02 and says
`SIGSEGV`; it contains a core but no retraced stack. The next two clients,
10550 and 10581, trapped in `GLib.error` at 15:31:12 and 15:31:18.

This is not an `St.Adjustment` implementation guess. The reduced
`tests/call-sync-repro/notify-proxy-setter-echo-gate.vala` uses an ordinary
Live proxy whose setter only counts calls. One server `notify::visible`
produces:

```text
FAIL notify-proxy-setter-echo-gate: notify called outbound setter 1 time(s)
```

The gate compiles and fails against installed libocrpc. The libocrpc
notification mirror needs a side-effect-free update contract; it must not
invoke a Live proxy's public/outbound setter. Do not work around this in
GNOME Shell JavaScript, `St.Adjustment`, or its bidirectional workspace
binding. Fix libocrpc, make this gate pass, then repeat the installed login.

## Apport dialog

Apport 2.32 is enabled and active on the machine. It wrote
`/var/crash/_usr_bin_gsr-client.1000.crash` and the GTK crash dialog interrupted
the restart/logout flow.

Apport already has an executable-specific denylist. Its installed
`Report.check_ignored()` reads every non-comment line under
`/etc/apport/report-ignore/`. A package-owned file such as
`/etc/apport/report-ignore/gnome-shell-rpc` containing:

```text
/usr/bin/gsr-client
```

suppresses presentation for this executable without disabling Apport for the
rest of the machine. The per-user `Report.mark_ignore()` alternative writes
`~/.apport-ignore.xml`, but its entry is tied to the executable mtime; every
development install makes the dialog eligible again. Use the system denylist
for this development package.

## Logout validation — 2026-10-05 15:37

The crash-screen Log Out only called `Meta.Context.terminate()`. That cleanly
stopped `org.gnome.ShellRpc@wayland.service` at 15:31:21, but it did not log
out the GNOME session:

- `gnome-session-manager@gsr.service` stayed active, PID 9924.
- Its status was `GNOME Session Manager phase is RUNNING`.
- logind session 18 stayed active on VT 2.
- `gnome-session@gsr.target` and `gnome-session.target` stayed active.

From SSH, the supported call:

```text
org.gnome.SessionManager.Logout(1)
```

returned successfully. In the same second logind recorded `Session 18 logged
out` and removed it; the manager and both session targets became inactive.
Only GDM's greeter session remained.

For a session that has reached RUNNING, the crash-screen control must request
`SessionManager.Logout(1)` instead of merely terminating Mutter. This exact
solution is validated on the hung session. The earlier pre-RUNNING rejection
is a separate fallback case and must not be answered by killing every process
owned by the user.
