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
