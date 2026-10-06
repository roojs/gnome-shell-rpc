# Crash-screen Log Out does not end the session

**Status:** ⏳ open. Split from [`2026-10-05-boot-crash-and-logout-hang.md`](2026-10-05-boot-crash-and-logout-hang.md) 2026-10-06. The boot crash stays there.

The crash screen in `src/server/rpc/SpawnClient.vala` has two Log Out
controls (top-right text and the last choice box). Both call
`on_crash_logout`. Neither returns the user to a logged-out GDM.

## 2026-10-05 — first reports

The 10:40 `gsr-server` calls `context.terminate()` from the button handler. That runs mutter shutdown on the click, so the button sits there. When the compositor does exit, `gnome-session-binary --session=gsr` is still the logind session, and the greeter does not come back. `SessionManager.Logout` is rejected before the running phase.

`on_crash_logout` no longer calls `terminate()`. On a real backend it `SIGKILL`s every other process of this user, which includes `gnome-session`, then `SIGKILL`s itself. Installed 10:54:08 together with `gsr-client`. User: neither fix worked.

The `SIGKILL` version was removed again; it is not an acceptable answer.

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

## Seen again — 2026-10-06 08:22

`alan2`, session 188, tty4. `gnome-session-binary --session=gsr` entered the
running state at 08:22:55, before either client died. Two clients, then the
crash screen, then Log Out. The greeter came back. The user session did not.

`on_crash_logout` only called `context.terminate()`. The comment there said
`SessionManager.Logout` is rejected before the running phase and that waiting
on it made the button sluggish. This session was already running.

```text
08:23:26  gsr-server[411960]: client exited manual-restart=false
08:23:29  gsr-server[411960]: exit 0
08:23:32  logind: new greeter sessions c25 and 190
```

There is no `Session 188 logged out`. Session 188 stayed `online` on VT 4,
`Active=no`. Still present after the greeter returned: `gnome-session-binary
--session=gsr` (411836 under `gdm-wayland-session`, and 411915), the user
`systemd` (411680), and the session daemons (pipewire, gsd-*, gvfs,
evolution factories, zeitgeist). About 63 processes of uid 1002. Log Out
released the VT and left the session up.

## Earlier Logout attempt (3baabbe → a42018c)

`3baabbe` already called `SessionManager.Logout(1)`, awaited it with no
timeout, and `GLib.error`ed on failure. `ba5b6aa` added a 2 s timeout, a
warning, and an unconditional `context.terminate()` after the call. `a42018c`
replaced all of it with `terminate()` alone. None of those runs recorded
whether Logout was rejected, timed out, or succeeded and was then cut off
by the immediate `terminate()`.

## Fix — 2026-10-06

`on_crash_logout`:

1. `on_crash_logout` is `async`; the click handlers call `.begin()` and
   return at once, so the button is not held by the D-Bus round trip.
   The clicked Log Out sets itself `reactive = false`, so later clicks do
   nothing. Only one is reachable at a time: the top-right text is under
   the notice until Emergency mode removes it.
2. `org.gnome.SessionManager.Logout(1)` on the session bus. On success do
   nothing more: gnome-session stops `org.gnome.ShellRpc@wayland.service`
   itself, the same path as the 15:37 validation.
3. If Logout fails (pre-RUNNING), `org.freedesktop.login1.Session.Terminate`
   on `/org/freedesktop/login1/session/auto` on the system bus. This is
   `loginctl terminate-session` for our own graphical session; logind lets
   the session owner do it without polkit. `XDG_SESSION_ID` is empty inside
   a user service, but `session/auto` still resolves to the user's display
   session (checked under `systemd-run --user` on systemd 257).
4. If both fail, warn and `context.terminate()` as before.

Each failure is logged as a warning with the D-Bus error, so the next
installed run says which path ran.

## To verify

Installed GDM login, force the crash screen, press Log Out:

- after RUNNING: journal shows no `SessionManager.Logout` warning, logind
  logs `Session N logged out`, no uid processes left except lingering ones.
- before RUNNING (crash during startup): `SessionManager.Logout` warning, no
  `Session.Terminate` warning, session removed.
