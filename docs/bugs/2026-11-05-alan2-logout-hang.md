# alan2 logout does not return to a greeter that stays up

**Status:** Seen on this machine (`fastboy`), user `alan2` (uid 1002), mutter API 16, GNOME Shell 48.0, mutter 48.1. Two logins on 2026-11-05. `src/` has not been changed. No gate. No cores.

Log out starts a GDM greeter. That greeter dies with `Xwayland terminated, exiting since it was mandatory`, and the `alan2` session stays up for about a minute. The debug-session shell client exit is handled as a crash, and a new client is spawned, so that session comes back instead of ending.

Copied logs, session 415 only: `/tmp/gsr-crash-2019/mutter-rpc.debug.log` and `org.gnome.ShellRpc.debug.log`. Session 424 did not use `--debug`. Journal is `journalctl -b` for 2026-11-05 20:04–20:14.

## Session 415 — debug

`gsr-server` 1297546 started 20:04:52 as a Wayland display server on `/dev/dri/card1`, display `:4`, `wayland-0`. It spawned `/usr/bin/gsr-client --debug` pid 1298036. `gnome-session-binary` 1297504 entered running at 20:04:53. logind session 415. Installed `/usr/bin/gsr-server` and `gsr-client` are stamped 20:06, after this process started.

20:08:00 GDM session c4 starts. 20:08:27 greeter `gnome-shell` 1301223:

```text
Connection to xwayland lost
Xwayland terminated, exiting since it was mandatory
JS ERROR: Gio.IOErrorEnum: Xwayland exited unexpectedly
```

The same second, `SpawnClient.vala:161`: `client exited manual-restart=false`. 20:08:33 the same server spawned `/usr/bin/gsr-client --debug` pid 1301948. After a non-manual exit the wait callback calls `on_crash()` and does not spawn. The later spawn is `spawn_client()` from a crash-screen Restart choice.

20:08:52 `gnome-session-binary`: `Client '/org/gnome/SessionManager/Client18' failed to reply before timeout`. The server log lays out `Gjs_ui_endSessionDialog_EndSessionDialog` at 20:08:52.908. 20:09:26 the second client exits `manual-restart=false`. The server then logs `__lambda31_: assertion 'event_actor != NULL' failed` through 20:09:40. Session 415 and `gnome-session-wayland@gsr.target` stop at 20:10:12.

## Session 424 — quiet

20:10:36 logind session 424. 20:10:37 `org.gnome.ShellRpc@wayland.service`, `gsr-server` 1306006 `started`, `gsr-client` 1306425 with no `--debug`. `GNOME Shell started` at 20:10:48. These binaries are the 20:06 install.

20:12:46 GDM session c9 starts. 20:13:15 greeter `gnome-shell` 1307856 dies with the same `Xwayland terminated, exiting since it was mandatory`. 20:13:49 the client logs `Client: disconnected` and `org.gnome.ShellRpc.target` stops. No second client was spawned. No `failed to reply before timeout` from `gnome-session-binary` 1305960.

## Greeter after the session is already gone

Session c7, 20:10:13–20:10:29, starts after session 415 has stopped. Greeter `gnome-shell` 1304307 dies with the same Xwayland line. Session c10, 20:13:50–20:14:07, starts after session 424 has stopped. `gnome-shell` 1309427 reaches `Running GNOME Shell`, and at 20:14:07 gdm logs `Child process -1309384 was already dead`. The greeter that was on screen before the first login (session c2, 20:04:25) was replaced by the login at 20:05:05. It did not log that Xwayland line.

## LLM efforts

- 2026-11-05 20:25. User copied `/home/alan2/.cache/gnome-shell-rpc/` to `/tmp/gsr-crash-2019/`. Two files, no cores. Client log is the 20:08:33 client (pid 1301948) through 20:09:20. Server log is 20:04:52 through 20:09:40 and contains both `client exited manual-restart=false` lines and the 20:08:33 spawn.
- 2026-11-05 20:30. Journal for uid 1002 and pid 1. Session 415 is the debug login. Session 424 is the quiet login. Greeter Xwayland deaths are pids 1301223 (20:08:27), 1304307 (20:10:29), and 1307856 (20:13:15). `src/` not edited.
