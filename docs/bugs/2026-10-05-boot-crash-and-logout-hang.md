# Boot crash

**Status:** ⏳ open. User 2026-10-05. The crash-screen Log Out failure was split out 2026-10-06 to [`2026-10-06-crash-screen-logout.md`](2026-10-06-crash-screen-logout.md).

Earlier logins: [`2026-10-03-greeter-login-black-screen.md`](2026-10-03-greeter-login-black-screen.md), [`2026-10-04-greeter-crash-screen.md`](2026-10-04-greeter-crash-screen.md).

## Boot crash

The shell does not stay up. The user gets the crash screen at login.

2026-10-05 10:43. `alan2` from GDM. Installed 10:40: `/usr/bin/gsr-client`, `/usr/bin/gsr-server`. Desktop file has `X-GNOME-HiddenUnderSystemd=true`. Only `org.gnome.ShellRpc@wayland.service` started. No second server, no `Native backend mode needs to be session controller`.

`gsr-server` 383450 spawned `gsr-client --debug` 383844. The client journal runs through theme, `DateMenuButton`, then at 10:43:09 stops on `property 'mapped' of object class 'StEntry' is not writable` and the same for `StWidget`, mid `Clutter-Actor.is_mapped`. No `JS ERROR`. No `too much recursion`. No `Unexpected early end-of-stream`. No kernel `trap`. No new file under `/var/crash/` (the `gsr-client` crash there is still the 09:42 one).

By 10:44 both processes are gone. `gnome-session-binary --session=gsr` (383306) is still running.

The 10:08 login, before this install, died in a re-entered `WorkspaceTracker._checkWorkspaces` (`append_new_workspace` on every nested `before-update`). `Laters.run_before_redraw` in this install does not run the queue from inside a later. This boot still does not stay up.

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
`SIGSEGV`; it contains a core but no retraced stack. The dialog that came
with that file is [`done/2026-10-06-apport-crash-dialog.md`](done/2026-10-06-apport-crash-dialog.md).
The next two clients,
10550 and 10581, trapped in `GLib.error` at 15:31:12 and 15:31:18.

This is not an `St.Adjustment` implementation guess. libocrpc applies
the notify with `set_property`. That is the call the real adjustment
already receives. Stock `st_adjustment_set_value` returns when
`priv->value` already matches, so it does not notify again. The
generated client setter had no such field, so `set_property` sent
`set_value` again.
`OLLMchat/docs/bugs/2026-10-06-notify-proxy-setter-echo.md` concludes
this is not a libocrpc bug.

The client `St.Adjustment.value` setter, in `Adjustment.override.vala`,
keeps the last value and returns before `call_poll` when it already
matches. Stock `st_adjustment_set_value` is the setter that compares.
Other generated setters do not. A changed value still goes through
once. The gate's server notifies on every set, including the same
value:

```text
PASS notify-proxy-setter-echo-gate
```

Do not skip `set_property` in `Client.vala`. Do not patch
`workspace.js`. Stock `St.Adjustment` on the server already compares.

## Seen again — 2026-10-06 08:22

`alan2` from GDM, session 188, tty4, leader 411674. Installed that minute:
`/usr/bin/gsr-client` and `/usr/bin/gsr-server` (mtime 08:22:43). `gsr-server`
411960 spawned `gsr-client --debug` 412378. `gnome-session-binary --session=gsr`
entered the running state at 08:22:55, before either client died.

Two clients, then the crash screen. The Log Out that followed is in
[`2026-10-06-crash-screen-logout.md`](2026-10-06-crash-screen-logout.md).

| PID | What the journal still has | Trap |
| --- | --- | --- |
| 412378 | Startup through theme and layout. Last kept lines 08:22:59: `mapped` not writable on `StEntry`, `StWidget`, and `WorkspacesDisplay`, then `g_closure_unref`. | 08:23:09 `int3` in `libglib-2.0.so.0.8400.1` at `0x73e0f` |
| 413035 | Only the last fraction of a second. Request ids already past 14157. `captured-event`, `event`, `style-changed`, `captured-event`, `event`. | 08:23:25 same `int3` offset |

journald at 08:23:25: `Suppressed 77345 messages from user@1002.service`. The
first client's exit, the spawn of 413035, and whatever killed 412378 are in
that drop. A second polkit agent for `/usr/bin/gsr-client --debug` registered
at 08:23:16, so 413035 was already up then. No `JS ERROR`. No
`Unexpected early end-of-stream`. No new file under `/var/crash/` (the
`gsr-client` crash there is still the 2026-10-04 09:42 one). No
`/etc/apport/report-ignore` entry for `gsr-client`. `coredumpctl` is not
installed.

The death that is still in the journal is 413035. Five milliseconds before
`Connection reset by peer`:

```text
08:23:25.885  gsr-server[411960]: connection write error: unsupported bin value type 'MetaBarrierEvent'
08:23:25.890  gsr-client[413035]: Error receiving data: Connection reset by peer
08:23:25      kernel: gsr-client[413035] trap int3 … libglib-2.0.so.0.8400.1+0x73e0f
```

`Meta.Barrier` `hit` and `left` both carry a `MetaBarrierEvent`. Shell
`PressureBarrier` connects to those two signals (`vendor/gnome-shell/js/ui/layout.js`)
and reads `event.dx`, `event.dy`, and `event.time`. The value is a boxed
record. `OLLMrpc.Bin.StreamValue` throws `unsupported bin value type` when a
boxed type has no alias and no `TypeOverride`. `ClutterEvent` already has an
override. `MetaBarrierEvent` does not. The write drops the socket. The client
aborts on the short read. That is this crash screen.

A window close is not in the lines that survived. The recovered sequence is
a pointer `captured-event` / `event` and then the barrier write.

## Unsupported boxed types — audit 2026-10-06

`unsupported bin value type` is one failure. `OLLMrpc.Gi.register` aliases
object and interface GTypes only. A boxed record is written by
`StreamValue` when it is in `gtype_to_alias` (payload is four zero bytes)
or expanded first by a `TypeOverride`. Anything else throws, the socket
drops, and the client traps.

Stock GIR for Meta, Clutter, Cogl, Mtk, St, Shell, and Graphene. Already
covered, so these do not throw:

| Record | How |
| --- | --- |
| `Clutter.Event` | `TypeOverride` |
| `Clutter.ActorBox` | `TypeOverride` |
| `Clutter.PickContext` | `TypeOverride` |
| `Graphene.Point` | `TypeOverride` |
| `Clutter.Frame` | `Bin.register("Clutter-Frame")`. `before-update` stays up because the payload is empty. |
| `Meta.BarrierEvent` | `TypeOverride`. `hit` / `left` fields: event id, dt, time, x, y, dx, dy, released, grabbed. This is the 08:23:25 death. |
| `Mtk.Rectangle` | `TypeOverride`. x, y, width, height. `show-tile-preview`, `show-window-menu`, `size-change` (two rectangles), `show-resize-popup`, `screenshot-taken`. |
| `Meta.KeyBinding` | `TypeOverride`. name, modifiers, mask, is-builtin, is-reversed. The client stub is one byte; `meta_key_binding_get_name` and the other four getters live in `libmutter-rpc-16.so` for the handler. |
| `Graphene.Rect` | `TypeOverride`. origin x/y, size width/height. `cursor-location-changed`. |
| `Mtk.Region` | `TypeOverride`. rectangle count, then each x, y, width, height. `paint-view`. Shell JS does not connect it. |

`size-change` is the window size-change animation, connected before any
window is closed. A later resize, tile, or menu is the same write failure
as the barrier hit. The 08:23:09 death of client 412378 is still inside
the dropped journal, so this audit does not name its type.

Nineteen further boxed records appear only as a method return or an out
parameter. The same throw happens when that result is written. They do
not fire on their own.

`Clutter.Colorimetry`, `Clutter.EOTF`, `Clutter.EventSequence`,
`Clutter.Luminance`, `Clutter.Margin`, `Clutter.PaintVolume`,
`Clutter.Perspective`, `Cogl.Color` (17 methods, including
`Clutter.Actor.get_background_color` and `Clutter.Text.get_color`),
`Cogl.DepthState`, `Cogl.DmaBufHandle`, `Cogl.FrameClosure`,
`Cogl.MatrixEntry`, `Cogl.TimestampQuery`, `Graphene.Matrix`,
`Graphene.Point3D`, `Meta.Group`, `Meta.Settings`, `St.IconColors`,
`St.Shadow` (five `St.ThemeNode` getters).

`Colorimetry`, `EOTF`, `Luminance`, and `DepthState` have no GType in the
GIR. `DmaBufHandle`, `TimestampQuery`, `Meta.Group`, and `Meta.Settings`
are disguised. The ones with a GType are the ones `StreamValue` can be
handed: `ClutterEventSequence`, `ClutterMargin`, `ClutterPaintVolume`,
`ClutterPerspective`, `CoglColor`, `CoglFrameClosure`, `CoglMatrixEntry`,
`GrapheneMatrix`, `GraphenePoint3D`, `StIconColors`, `StShadow`.

## Seen again — 2026-10-06 09:29

Installed 09:29:18, including the five signal `TypeOverride`s.
`gsr-server` 593932, session 203, user `alan2`. systemd-coredump kept
three cores. `coredumpctl` marks them inaccessible from this account:
the ACL is `user:alan2:r--`. `/home/alan2/.cache/gnome-shell-rpc/` is
also permission denied. The stacks below are the ones journald stored.

First client 594319. Journald dropped the lines (`Suppressed 89657
messages` at 09:30:04). The copied core and
`mutter-rpc.debug.log` name it. At 09:29:45.081 the server logged
`connection write error: Unregistered class type schema:
MetaInputDeviceNative`. Seven milliseconds later the client core has
`Client.vala:723: Unexpected early end-of-stream`, and the kernel
`trap int3` is that `GLib.error`. Installed `libocrpc.so` (2026-10-05
10:34) still aborts on every parse error except it logs this one as
fatal. `InputDeviceOverride` packs `MetaInputDeviceX11` as a device
type and writes every other device unchanged, so the Wayland subclass
has no schema. That is the only unregistered-schema line in this log.
The five signal records did not throw.

Second client 595001. SIGSEGV at 09:29:57. The stack repeats:

`oll_mrpc_client_dispatch_message` → `g_object_set_property` →
`st_adjustment_set_value` → `gsr_client_rpc_call_value` →
`oll_mrpc_client_call_poll` → `oll_mrpc_bin_stream_value_write` →
back into `dispatch_message`.

That is the 15:30 notify echo. A `notify::value` calls the proxy
setter, the setter sends `St-Adjustment.set_value`, and the reply
notify does it again until the stack overflows. libocrpc stays on
`set_property`. The `St.Adjustment.value` setter returns before
`call_poll` when the bits already match. Do not patch `workspace.js`.

Server 593932 trapped in the same second, `GLib.error` in
`Connection.drain_readable` while parsing. The second client died
inside `StreamValue.write`, so the server read a broken message and
aborted on it.

Copied to `/tmp/gsr-crash-0929` and read. The client debug log is only
the second process: it is opened with truncate, so 594319's lines are
gone from the file and live in the core.

## Seen again — 2026-10-06 10:09

App grid came up, an app started, then the session died with no crash
screen. Installed binaries from the `MetaInputDeviceNative` pack.
`gsr-client` 690523, `gsr-server` 690113. Logs and cores copied to
`/tmp/gsr-crash-1009`.

The client log at 10:08:59 is the same notify echo, now also in JS.
`notify::value` is followed by `St-Adjustment.set_value`, and
`workspace.js` `_updateBorderRadius` (connected at line 955 to that
notify) logs `JS ERROR: too much recursion`. The client SIGSEGV is
10:09:01. The OPC writeup concludes it is the consumer's setter. The
`St.Adjustment.value` setter holds the value and returns before
`call_poll` when the bits already match.
`notify-proxy-setter-echo-gate` passes. Do not patch `workspace.js`.

The crash screen did not appear because the server died with the
client. At 10:09:01.924 `mutter-rpc.debug.log` has
`Connection.vala:172: Error receiving data: Connection reset by peer`,
and the kernel `trap int3` is that `GLib.error`. `on_crash()` runs
from the client wait callback. An abort in `drain_readable` ends the
compositor first, so the backdrop is never painted. A parse error now
warns and stops the connection, the same way HUP already does.

## Seen again — 2026-10-06 12:58 (VM)

`alan@192.168.88.197`, host `alan-VirtualBox`. Session 3 from GDM at
12:58:16. Installed that hour: `/usr/bin/gsr-client` and `/usr/bin/gsr-server`
(mtime 12:44:34). `libocrpc1` `1.4.0-1`, `/usr/lib/x86_64-linux-gnu/libocrpc.so`
510264 bytes, mtime 2026-10-02 08:00. The dev machine's `libocrpc.so` is the
2026-10-05 build (2119776 bytes). `gsr-server` 2526 is still the compositor.
No new file under `/var/crash/`. `coredumpctl` is not installed.

`/usr/bin/yelp` 3229 started at 12:58:35. Its parent is now
`systemd --user` because the client that launched it has exited.

| PID | What the log still has | Death |
| --- | --- | --- |
| 2838 | Spawned 12:58:18. Last server recv 12:58:38.023: `Clutter-Actor.get_children` id 13141. | 12:58:38.336 `connection write error: live object MetaWindowWayland not in connection.lease_ids`. `window_created title=(null) frame=0,0 0x0` at 12:58:38.381. Kernel `trap int3` in `libglib-2.0.so.0.8400.1` at `0x73e0f`. |
| 3362 | Crash-screen restart. Spawned 12:58:41 (`manual-restart=false` on 2838, so this was the Restart click). Last client line 12:58:50.893: `before-update` after `Clutter-Stage.schedule_update`. | 12:58:50.894 `malloc_consolidate(): unaligned fastbin chunk detected`. Server 12:58:52.102 `Broken pipe`. No second kernel trap. `client exited manual-restart=false` at 12:58:52.163, so the crash screen is up again and nothing respawned. |

The first death is [`done/2026-10-03-new-window-kills-client.md`](done/2026-10-03-new-window-kills-client.md).
A subscribed signal carries the new `Meta.Window` before
`Meta.Display::window-created` exports it. This VM's `libocrpc` 1.4.0-1
does not contain that export. The 1.4.0 changelog has no such entry.
Do not patch the shell for this write. The library on this machine is
the old package.

The second death is a heap abort in the restarted client, one millisecond
after `before-update`. The server did not throw `lease_ids` again; it
wrote into a socket the client had already closed. Both clients logged
`g_atomic_ref_count_dec: assertion 'old_value > 0' failed` through
startup, and `mapped` not writable on `StEntry`, `StWidget`, and
`WorkspacesDisplay`. Those criticals are still in the journal. They are
not the line that names either death.
