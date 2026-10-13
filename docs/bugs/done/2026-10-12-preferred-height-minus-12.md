# Preferred height of -12 aborts ClutterBoxLayout

**Status:** ✅ closed 2026-10-13. The splash remains in `StartupFrameLock`. After rebuilding HEAD, Weston reached `READY=1`, `Meta-Context.notify_ready`, and `startup notice removed` at 08:34:12, then stayed alive until `stop (timeout) after 35s`. There was no minimum-height abort, segfault, or C++ exception in that run.

`PanelMenu.setMenu` does `Main.uiGroup.add_child(this.menu.actor)` and the next line is `hide()`. `quicksettings-add-hide-race-smoke` at 16:23:40 printed `exposed-before-hide wrapper-mapped=true min=-12 nat=-12` and `FAIL add_child dispatched layout before hide`. The empty Quick Settings grid is that child: `QuickSettingsLayout` returns `(rows.length - 1) * row_spacing`, and with zero rows and `spacing-rows` of 12 that is -12. `quicksettings-layout-neg-smoke` allocates that grid at 182×32 and mutter exits 133 on `ClutterBoxLayout child qs-smoke-grid … minimum height: -12`. The hand session did the same abort at 15:25:08 while the startup notice was still up (`startup notice painted` at 15:25:02, no `startup notice removed`). `before-update` was delivered during that allocate.

`begin()` inhibits the stage-view clocks from the startup RPC, and `release_internal()` uninhibits them before `schedule_update`. It does not inhibit from `after_update`. This keeps the startup frame from allocating Quick Settings in the `add_child`/`hide` RPC gap while retaining the splash. The explicit allocate smoke must still abort. The add-before-hide smoke does not call `begin_shell_startup`, so it stays a fail.

## Reproduction

Hand Weston, 15:25, `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log` line `ClutterBoxLayout child unnamed [GsrServerClutterActor] minimum height: -12.000000 < 0 for width 182.000000`.

```bash
GI_META_SMOKE=quicksettings-layout-neg-smoke \
  ./scripts/agent-nested-smoke-prove.sh
```

16:11: `mutter exited ec=133`.

```bash
GI_META_SMOKE=quicksettings-add-hide-race-smoke \
  ./scripts/agent-nested-smoke-prove.sh
```

16:23: `FAIL add_child dispatched layout before hide`. Prove line `stop (timeout) after 25s` because that smoke does not quit.

## Debug-code cleanup ledger

- The `preferred-height base` debug line in `ClutterActor.get_preferred_height` was already in the tree. No new diagnostics have been added for this report.

## LLM efforts

### 2026-10-12 15:57 report opened from the Weston abort

Read `mutter-rpc.debug.log` through the 15:25:08 abort and `org.gnome.ShellRpc.debug.log` for the 15:25:02 client. `coredumpctl` has `gsr-server` 1123982 SIGTRAP and `gsr-client` 1124015 SIGILL. Server stack: `oll_mrpc_live_hook_emit` → `emit_wait_poll` → `gsr_server_clutter_layout_hooks_measure_allocate` → `clutter_actor_allocate` → `g_log`. The `-12` preferred-height line is the `hook == null` branch, so it is `base.get_preferred_height`, not a JavaScript actor vfunc return.

### 2026-10-12 16:05 log read

Same files, the BoxPointer pass from recv id=4544 through the abort. `BoxPointer.vfunc_get_preferred_height` calls `this.bin.get_preferred_height`. The -12 is a child `StWidget` on the base path, measured at for-width 182 and then -1. BoxPointer’s own hook result after `adjust_preferred_height` is 32, not -12. `startup notice removed` does not appear after the 15:25:02 paint. No `clicked` string in the restarted client log. Installed clutter box layout compares the child minimum to 0 and `g_error`s; the spacing multiply in that function is the leftover allocation size, not the -12.

### 2026-10-12 16:06 shrink gate

```bash
GI_META_SMOKE=quicksettings-layout-neg-smoke ./scripts/agent-nested-smoke-prove.sh
```

`weston-autolaunch-prove.log`: `quicksettings-layout-neg-smoke: vfunc rows=0 row_spacing=12 spacing=-12 → min=-12 nat=-12`, then `preferred-height base type=StWidget for=0 min=-12 nat=-12`, then `FAIL negative-preferred want>=0 got min=-12 nat=-12`. Prove line `nested-weston-prove: mutter exited ec=1 after 17s`. Script exit 139 is weston SIGSEGV after that (`Connection reset by peer` on the Xwayland wayland socket). No `ClutterBoxLayout` minimum-height line in this run. The smoke calls `get_preferred_height` and does not allocate the grid under a `ClutterBoxLayout`.

### 2026-10-12 16:11 allocate under St.BoxLayout

Same command, after the smoke puts the grid in a vertical `St.BoxLayout` and calls `allocate` on a 182×32 box. Prove log:

```text
quicksettings-layout-neg-smoke: vfunc rows=0 row_spacing=12 spacing=-12 → min=-12 nat=-12
preferred-height base type=StWidget for=182 min=-12 nat=-12
ClutterBoxLayout child qs-smoke-grid [GsrServerClutterActor] minimum height: -12.000000 < 0 for width 182.000000
disconnect abort Clutter-Actor.allocate id=44
nested-weston-prove: mutter exited ec=133 after 1s
```

The installed `g_log` call uses level 4. The client then logs `uncaught error: Client: disconnected` and the following `allocate returned` line. That line is after the socket close.

### 2026-10-12 16:23 add-before-hide

```bash
GI_META_SMOKE=quicksettings-add-hide-race-smoke ./scripts/agent-nested-smoke-prove.sh
```

`exposed-before-hide wrapper-mapped=true min=-12 nat=-12`. `FAIL add_child dispatched layout before hide`. `nested-weston-prove: stop (timeout) after 25s`. Exit 137 is that timeout SIGKILL.

### 2026-10-12 16:31 shell boot after inhibit in begin()

```bash
./scripts/weston-gsr-prove.sh
```

`READY=1` at 16:31:40.852310, `Meta-Context.notify_ready`, `startup notice removed`. No `minimum height` line after 16:31. `nested-weston-prove: stop (prepare-started) after 6s`.

### 2026-10-13 08:33 rebuilt HEAD and proved the startup hold

The first local runs were invalid because `build/src/gsr-server` was timestamped 2026-10-12 09:27 and did not contain the `startup notice painted` or `startup notice removed` strings. Rebuilt the current source:

```bash
meson compile -C build gsr-server gsr-client
```

The normal proof reached `READY=1`, `Meta-Context.notify_ready`, and `StartupFrameLock.vala:147: startup notice removed` at 08:33:49. It stopped deliberately with `stop (prepare-started) after 5s`; no minimum-height abort occurred.

Held the rebuilt shell after ready:

```bash
GSR_NESTED_STAYUP=1 GSR_NESTED_TIMEOUT=35 \
  timeout --foreground -k 3 45 ./scripts/weston-gsr-prove.sh
```

At 08:34:12 it reached `READY=1`, `Meta-Context.notify_ready`, and `startup notice removed`. The server remained alive until `stop (timeout) after 35s`. There was no later `minimum height`, `segfault`, or `length_error` marker. Exit 137 is the scripted Weston SIGKILL after that stop.

### 2026-10-13 08:38 closed

User accepted the rebuilt Weston proof and closed the bug.
