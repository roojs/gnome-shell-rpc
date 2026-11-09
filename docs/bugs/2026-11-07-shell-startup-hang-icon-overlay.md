# Shell startup hangs, then icons stack

Do not stop and report back until this is actually fixed.

**Status:** Fixed on the guest session that started 10:00
on 9 Nov. Desktop Icons claimed its window once and did not
relaunch. That boot has no `window-type` reject, no
`skip-taskbar` reject, no `map_completed` line, and no
`nan`. Mutter 16 still has no `set_type`, so Weston
`icon-overlay` still logs `type=0`.

Weston `map-completed-lid: ok`, no `Meta-Plugin.map_completed`
line. Weston `icon-overlay/ui/init` with the shell left up:
`before fovy=60 mon=800x600 depth=171.57`, same figures with the
overview open, no `nan` before `done`. One window,
`type=0 title=Desktop Icons 1`. Map scale stayed `1x1`.

Weston, the property reject, then the setter:

```text
GSR_NESTED_TIMEOUT=30 GI_META_SMOKE=window-type-set ./scripts/agent-nested-smoke-prove.sh
```

Before the setter: `window-type-set: miss Property MetaWindow.window-type is not writable`.
After `Window.window_type` gained a setter in both client
overrides: `window-type-set: type=1 notified=true`,
`window-type-set: ok`, `stop (smoke-ok) after 1s`.

`Meta.Window.set_type` on the guest client is
`Meta-Window.set_type` (RPC). `gsr-server` has no `set_type`
string. Mutter 16 has no `meta_window_set_type`, so this Weston
cannot run that call. Desktop Icons uses `set_type?.()`, which
does not run here, so `icon-overlay` still sees `type=0`.

Guest (`ubuntu2604`, `alan@192.168.122.115`). Current session
is `gsr-server` pid 158137 and `gsr-client` pid 158165,
started 10:00:46 on 9 Nov. `libmutter-rpc-18.so` has the
`window-type` and `skip-taskbar` setters.
`libshell-18.so` has the empty `completed_map`. Desktop
Icons launched twice, then
`Received notification for window. 0 notifications remaining.`
No further launch. The 17:07 session logged `window-type`
not writable at that moment. This boot does not.

Journal line that the map signal introduced:

```text
RPC Meta-Plugin.map_completed: no rpc_lid on MetaPlugin
```

`WindowManager._mapWindow` calls `completed_map` on
`new Meta.Plugin()` from `Global.vala`. That object has no lease.
The server plugin had already called `map_completed`.

Same guest session, while the shell stayed up: 40 rejected `nan`
sets of `translation-x`, `translation-z`, and `rotation-angle-y`
from 17:07:37 to 17:07:41. That burst is not in the live Weston
log. The desktop window staying `type=0` is.

Weston, the critical, before the no-op:

```text
GI_META_SMOKE=map-completed-lid ./scripts/agent-nested-smoke-prove.sh
```

`Meta_window_generated.vala:2720` logged
`RPC Meta-Plugin.map_completed: no rpc_lid on MetaPlugin`. The
same call does not throw into JavaScript.

Weston, after `completed_map` was emptied (same command):
`map-completed-lid: ok`, `stop (smoke-ok) after 1s`, no
`Meta-Plugin.map_completed` line.

Weston, cube and Desktop Icons, shell left running through the
map (`GSR_NESTED_TIMEOUT=80 GI_META_SMOKE=icon-overlay/ui/init`):
`map scale=1x1 type=0` (NORMAL) then `type=9`, `Launching DING
process`, `icon-overlay/ui/init: done`. No `nan` and no
`map_completed` before `done`. An earlier run that exited as the
window mapped logged `translation-z` `-nan` during teardown only.

## LLM efforts

- 2026-11-07. User: the shell hangs at startup on the Ubuntu VM,
  then it hangs for a while, stays laggy, 3D works, and icons
  overlay. Opened this file before reading logs.
- 2026-11-07. Read `journalctl -b` for pids 149319 and 149564.
  One `no rpc_lid on MetaPlugin` at 17:07:49. Forty `nan`
  translation/rotation rejects 17:07:37–17:07:41, none earlier
  this boot. One `window-type` not writable at 17:07:49.
- 2026-11-07 17:18. `GI_META_SMOKE=map-completed-lid`.
  `map-completed-lid: miss map-not-emitted` at 8s. `plugin map
  title=GTK Demo` landed after the script returned.
- 2026-11-07 17:30. Same smoke, `GI_META_SMOKE_WAIT_MS=15000`,
  still `miss map-not-emitted`. The wait only slept, so the
  notification was not read.
- 2026-11-07 17:31. Wait now calls `list_all_windows` and
  iterates the main context. Log:
  `uncaught error: RPC Meta-Plugin.map_completed: no rpc_lid on
  MetaPlugin` at `Meta_window_generated.vala:2720`, then
  `map-completed-lid: ok` because the error does not surface in
  JavaScript. Prove `stop (timeout) after 40s` (`ok` was not in
  the stop pattern yet).
- 2026-11-08 08:52. Smoke called a local empty completion instead
  of `wm.completed_map`. `map-completed-lid: ok`,
  `stop (smoke-ok) after 1s`, no `map_completed` critical.
- 2026-11-08 08:58. Emptied `Shell.WM.completed_map`, smoke calls
  the product method again. `ninja -C build src/gsr-smoke`.
  `map-completed-lid: ok`, `stop (smoke-ok) after 1s`, no
  `Meta-Plugin.map_completed` line.
- 2026-11-08 09:08. `icon-overlay/ui/init` enabled cube before
  its state was set. `state=undefined`, `miss enable`.
- 2026-11-08 09:18. Waited for a state, then enabled cube and
  Desktop Icons. Both `state=1`. `Launching DING process`,
  `Shell.WM map lid=4634`, then `done`, then `translation-z`
  `-nan` (teardown).
- 2026-11-08 09:21. Same smoke, map handler logs scale, wait
  12s so the shell is still up. `map scale=1x1 type=0` and
  `type=9`. No `nan` before `done`.
- 2026-11-08 09:33. Same smoke logs the cube depth formula and
  opens the overview. `fovy=60 mon=800x600 depth=171.57` before
  and during overview. `window type=0 title=Desktop Icons 1`,
  `windows=1` then `windows=1` after overview (the type 9 window
  was gone). No `nan`. `done`.
- 2026-11-08 09:35. Guest `libmutter-rpc-18.so` is the 17:07:07
  file. `meta_window_set_type` calls `gsr_client_rpc_call_value`
  with `Meta-Window.set_type`. A bare `gjs` `set_type` logs
  `RPC Meta-Window.set_type: no rpc_lid`. Assigning
  `window_type` throws `Property MetaWindow.window-type is not
  writable`. `strings /usr/bin/gsr-server` has no `set_type`.
  The 17:07:49 journal has the property critical and no
  `Meta-Window.set_type` line.
- 2026-11-08 09:47. `GI_META_SMOKE=window-type-set`.
  `window-type-set: miss Property MetaWindow.window-type is not
  writable`. `stop (smoke-fail) after 1s`.
- 2026-11-08 09:49. Setter on `Window.window_type` in the 16 and
  18 overrides, `Window.window_type` denied in both `Meta.deny`
  files. `ninja -C build src/gsr-smoke`. Same smoke:
  `window-type-set: type=1 notified=true`,
  `window-type-set: ok`, `stop (smoke-ok) after 1s`.
- 2026-11-08 09:52. `icon-overlay/ui/init` now switches to
  workspace 1. `switch scale=1 mon=800x600 rows=1 n=12`,
  `switched n=12 active=1`, `done`. No `nan` from 09:52:20
  through 09:52:24. Desktop window still `type=0`.
- 2026-11-08 09:53. Copied the 18 override and `Meta.deny` onto
  the guest checkout and built
  `libmutter-rpc-18.so` there (`cached_window_type` is in the
  generated vala). Regenerated `Meta-18.typelib`.
- 2026-11-08 09:54. Installed that `.so` and typelib under
  `/usr/lib/x86_64-linux-gnu`. Pids 149319 and 149564 were
  left running. The client segfaulted at 09:55 in the
  library it had mapped since 17:07
  (`shell_signals_emit` → `libmutter-rpc-18.so + 0x45321`).
- 2026-11-08 11:27. Restarted `org.gnome.ShellRpc@wayland.service`.
  New pids 154960 / 154982. Desktop Icons claimed once.
  No `window-type` reject and no `nan`. `skip-taskbar` was
  not writable at 11:27:58, just after the claim.
- 2026-11-09 08:54. `GI_META_SMOKE=skip-taskbar-set`.
  `skip-taskbar-set: miss Property MetaWindow.skip-taskbar is
  not writable`. `stop (smoke-fail) after 1s`.
- 2026-11-09 09:29. Setter on `Window.skip_taskbar` in both
  overrides, denied in both `Meta.deny` files.
  `skip-taskbar-set: skip=true notified=true`,
  `skip-taskbar-set: ok`, `stop (smoke-ok) after 1s`.
- 2026-11-09 09:36. Installed that guest `.so` and typelib and
  restarted the service. Pids 156929 / 156964. Desktop Icons
  claimed once and did not relaunch. No `window-type`
  reject, no `skip-taskbar` reject, no `nan`.
  `map_completed` still has no `rpc_lid`.
- 2026-11-09 10:00. Installed `libshell-18.so` with the empty
  `completed_map` and restarted. Pids 158137 / 158165.
  Desktop Icons claimed once. No `window-type` reject, no
  `skip-taskbar` reject, no `map_completed` line, no `nan`.
  `column_spacing` / `layout_manager is null` still logs
  four times.
