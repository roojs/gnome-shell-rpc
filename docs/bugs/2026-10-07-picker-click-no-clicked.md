# Second app from the picker leaves the shell dead

**Status:** Open. VirtualBox, 2026-10-08 14:46. `gsr-server --debug` 39711, `gsr-client --debug` 40489.

**What:** A launch from the picker works. After that, typing still works, and the date menu and the power menu still open. Other clicks do nothing.

**Diagnosis:** Those clicks hit `overviewGroup`. It is the full-screen `St.Widget` in `layout.js` (`name: 'overviewGroup'`, `reactive: true`) and it has no click handler. From 14:47:06 the press and the release are that actor on both capture and bubble. The client has no `button-press-event` after `launch_desktop_file` id=13338.

**Held:** No failing gate. No fix. The `GLib.debug` in `ClutterActor.vala` is diagnostic only.

**Reproduce:** `alan@192.168.88.197`, log `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`. Weston `picker-second-launch` has not matched this. The 14:54 click was aimed at 270,520, landed at 232,461 on a window preview, and the client did get `clicked`.

## Do not stop

2026-10-08 11:57: the user can reproduce this on VirtualBox session 218. The morning Weston session is not the reproduction; clicks kept arriving there. The live log is the bar. Do not treat another Weston prove as the failure until it matches that session.

The next session carries this bug. Do not pause to narrate progress, summarize a ruled-out theory, or ask whether to continue. A status report that does not move the bar is a failure.

Keep going until one of these is true:

1. A gate under `tests/call-sync-repro/` **FAIL**s on this flow, then a candidate makes that same gate **PASS**. Propose the fix. Do not apply it until it is approved.
2. You actually need the user: a decision only they can make, credentials, or a machine you cannot reach. One short ask, then wait.
3. OPC / libocrpc is proven the problem: a **FAIL** gate plus this bug, do not edit OLLMchat from this tree, and stop. A **PASS** gate means chase the consumer. Do not stop to report that theory.

Anything else: update this file, take the next step, rebuild, prove, repeat. Do not patch `dnd.js`, the grab, `get_time`, or vendor JS from a guess. Do not put pick-logging into `src/` and call it a fix. Production `src/` stays untouched until the gate fails and a candidate makes it pass.

## Reproduce this

This is the bug. Do not get distracted by anything else in this file.

🔷 Start the session.

🔷 Launch an application from the picker. gedit, Help, or another app. That launch works.

🔷 Go back to the application picker.

🔷 Launch another application. gedit again, or another app.

🔷 The shell is then dead. Clicks do nothing. The exception is the menu at the top: that still opens, and logout from it still works.

🔷 Expected: the second launch works, and the shell still accepts clicks afterwards.

## What is not this bug

ℹ️ Earlier notes below are background from the same day. They are not the task. Do not stop after re-deriving them.

ℹ️ The `clutter_event_get_time` throw is [`done/2026-10-06-picker-click-get-time.md`](done/2026-10-06-picker-click-get-time.md). That throw is not this login.

ℹ️ 14:39:05 `client exited` is [`done/2026-10-07-blur-effect-alias.md`](done/2026-10-07-blur-effect-alias.md). It is not this click.

## Background

ℹ️ 2026-10-07 14:31 login on `alan@192.168.88.197` (`gsr-client` 11267). `journalctl -b _PID=11267` from 14:31:41 until the client died at 14:39:05. Six `button-press-event`. Zero `button-release-event`. Zero `clicked`. Zero `JS ERROR`. Zero `launch_desktop_file`.

ℹ️ Weston 15:11 (`gsr-client` 3017757, `gsr-server` 3017732, `wayland-gsr`). First click `(478, 551)` launched an app (`clicked`, then `launch_desktop_file`). A later click `(713, 389)` packed only stage `captured-event` for press and release. No `button-press-event`. No `clicked`. No `Clutter-Stage.grab` on that press.

ℹ️ `button-release-deliver-gate` and `button-release-chain-gate` both exit 0. Neither fails on the second launch. An unset boolean return does not stop `g_signal_accumulator_true_handled`. Do not edit `Subscription.emit` for this.

ℹ️ 17:46 `app-search-launch-smoke`: a result icon was mapped, reactive, and opacity 255, and `get_actor_at_pos` at its center was not that icon. Parent chain: unnamed `ClutterActor` < `overviewGroup` < `uiGroup` < `MetaStage`. The smoke's `L3 ok=true` is `AppIcon.activate()` from the previous step, not the pointer click. Two other boots that hour died in `main.start` (`global.stage.context is null`). Those runs never clicked.

🚫 Pick logging added to `ClutterEventOverride.pack` and `Plugin.clutter_stage`, and a pick line added to the smoke. Both reverted. `gsr-server` rebuilt without them.

## LLM efforts

### 2026-10-08 stage 2 — read the existing Weston logs

Read `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`, `mutter-rpc.debug.log`, and the tail of `nested-weston-prove.tee.log` / `weston-autolaunch-prove.log` before a new prove. `alan@192.168.88.197` was not contacted; this machine’s Weston log is the session on disk.

Session clock is 10:29:55 through 10:35:08, then the timestamps jump to 08:26:16 and the socket closes at 08:27:14. `READY=1` is line 11894 at 10:29:58.841.

Two launches: client `id=19581` at 10:30:08.346 (press, `Clutter-Stage.grab` `id=19492`, `clicked`, then launch) and `id=30691` at 10:30:19.856 (press, grab `id=30469`, `clicked`, then launch). Grabs dismissed at 10:30:09.009 (`id=20365`), 10:30:21.366 (`id=33201`), 10:30:30.143 (`id=47047`), 10:30:42.734 (`id=57205`).

Later presses at 10:30:23, 10:30:29, 10:30:37, and 10:30:41 still arrived. `clicked` at 10:30:41 is followed by `Meta-Window.set_demands_attention`, so that click still reached a window path. No third `launch_desktop_file`. No `button-release-event` anywhere in the file.

Prove-log tail is older `weston-gsr-autolaunch: mode=session` starts, not a `nested-weston-prove: stop` for this run. The tee’s last line is the Weston connection drop at 08:27:14.

### 2026-10-08 stage 3 — scripted picker clicks

Command: `GI_META_SMOKE=picker-second-launch ./scripts/agent-nested-smoke-prove.sh`

Harness is `tests/gjs-embed/picker-second-launch.js`. Prove stop pattern includes `picker-second-launch: ok`. `src/` was not edited.

- 08:53. `showApps()` while the overview is already shown does not open the grid. `grid=0 stopped=0`. `picker-second-launch: miss need two stopped icons`. Exit 137 is the prove SIGKILL on `smoke-fail`.
- 08:55. Show-apps `checked = true`. `ordered=147` but `get_transformed_position` / `get_transformed_size` are `NaN`. A click at `NaN,NaN` picked `MetaStage`. `press=1 release=1 clicked=false`. `miss launch1`.
- 08:59 first try was SIGTERM after 3s; the tee was then a different `drawing-area-smoke`. Not this bug.
- 08:59 second try. gedit allocation box `Infinity,Infinity -Infinityx-Infinity`. `miss need two stopped icons`.
- 09:03. State snapped to `APP_GRID` (`value=2 checked=true displayMapped=true`). gedit box still uninitialized after the wait. `miss need two stopped icons`.
- 09:04. Stage pick finds icons even when the allocation box is uninitialized. Samples at y=120 are `controls-manager:insensitive`. `pick-icons=3` (`org.gnome.Evolution.desktop`, Rhythmbox, snap-store). Click `org.gnome.Evolution.desktop @270,520 press=1 release=1 clicked=false pick=Evolution`. `launch1 took=false`. `miss launch1`. Client log 09:05:00, repeating `JS ERROR: Error: IconGridLayout.adaptToSize wasn't called before allocation` at `iconGrid.js:742`, called from `overviewControls.js:236` during `appDisplay.js` `_redisplay` / `_createIcon`.
- 09:07. Weston SIGTERM at 09:07:48. `picker-second-launch: FAIL start TypeError: global.stage.context is null`. The nest died during `main.start`. Same boot failure already noted in the background. No click.
- 09:16 and 09:19. `nested-weston-prove: mutter exited ec=133` after 3–4s. `Client.vala` `socket closed` during `Clutter-Actor.allocate`, then `get_context` is `not connected`, then `global.stage.context is null` in `keyboard.js:1063`. A `drawing-area-smoke` prove was using the same Weston socket in `weston-autolaunch-prove.log` (`timeout=18s`). Those boots never reached the picker.
- 09:24. Waited for `_orderedItems` to settle before opening the grid. `grid-fill items=0`. The `adaptToSize` throw still started at 09:24:56 (111 times) during that wait. After opening, the same Evolution click: `press=1 release=1 clicked=false`, `launch1 took=false`, `miss launch1`.
- 09:30. Smoke calls `layout.adaptToSize(800, 315)` before the pick (`prime page=800x315`). `pick-icons=20`.
  Calculator `@470,440 press=1 release=0 clicked=false box=418,226 91x65`, `launch1 state=0 windows=1 took=true`.
  Contacts `@170,280 press=1 release=0 clicked=true`, `launch2 state=2 windows=2 took=true`. `grid-after2 visible=true icons=21` at 09:31:56.
  The following `pointer_click` id=125601 was replied at 09:31:56.841. It delivered `button-press-event`, `clicked`, and `launch_desktop_file` id=125681 (replied; dbus activated `org.gnome.Weather`).
  Then a `gsignal.c:2699` “no handler” storm. `client exited` at 09:31:58.369. Prove log line 33412080: `nested-weston-prove: stop (timeout) after 90s`.
- 09:33. `FAIL start TypeError: global.stage.context is null`. `mutter exited ec=133` after 3s.
- 09:34. `mutter exited ec=1` after 50s. Weston process segfaulted (exit 139). No smoke marker for that boot.
- 2026-10-08 09:37. User: cannot reproduce the original report. Hold the bug open. Stop proving.

### 2026-10-08 11:53 — VirtualBox session 218

User: the failure is back on VirtualBox. This morning’s Weston run never reproduced the dead shell. The session was already `--debug`.

`ssh alan@192.168.88.197`. Host `alan-VirtualBox`. logind session 218, wayland, active, started 11:48:27, leader 28849 (`gdm-session-worker`). `org.gnome.ShellRpc@wayland.service` active, main pid 28948 `gsr-server --debug --wayland`. Binaries mtime 11:48:21.

Clients this login, all `gsr-client --debug`:

- 29301 spawned 11:48:30, READY 11:48:35, `client exited manual-restart=false` 11:51:31. Server then logged `gsignal.c:2699` “no handler”. Journal: 4 `button-press-event` (11:51:11, 11:51:12, 11:51:20, 11:51:21), 8 `key-press-event`, 0 `clicked`, 0 `button-release-event`, 0 `launch_desktop_file`, 0 `JS ERROR`. Last client line 11:51:22 is a `captured-event` plus `value_lcopy_boolean` / `gsignal.c:3480` “value location for gboolean passed as NULL”.
- 29933 spawned 11:51:34, READY 11:51:39, `client exited manual-restart=false` 11:52:09, same “no handler” storm. Last client lines are `captured-event` and `Clutter-Stage.get_actor_at_pos`. No button-press in that journal slice.
- 30002 spawned 11:52:12, READY 11:52:17, still running at 11:57 (elapsed ~4m30s). File log `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` (35189 lines at 11:54, still only the clock at 11:57:00). 1 `button-press-event` 11:52:30.795, `long-press` 11:52:35.234, `clicked` 11:52:35.281, `Clutter-Stage.grab` 11:52:36.221 and 11:52:38.738, `Gjs_ui_boxpointer_BoxPointer` preferred size from 11:52:36.327, then `captured-event::button` at 11:52:36.823, 11:52:37.141, 11:52:37.227, 11:52:39.742, 11:52:39.918 with no matching `button-press-event`. One `key-press-event` 11:52:41.365. 0 `button-release-event`, 0 `launch_desktop_file`, 0 `JS ERROR`, 2 `value_lcopy_boolean`.

Help is the launched app: `/usr/bin/yelp` 29510, started 11:48:47, ppid systemd --user (2524), cgroup `org.gnome.ShellRpc@wayland.service` along with its two WebKit processes. Environ: `GIO_LAUNCHED_DESKTOP_FILE=/usr/share/applications/yelp.desktop`, `DESKTOP_STARTUP_ID=9c7226c8-6997-4891-8f59-01f029fa9476`, `DESKTOP_SESSION=gsr`. Journal has no `method=` lines for pid 29301 between 11:48:44 and 11:48:48, so the launch RPC is not in the journal. No `app-gnome-yelp` scope. No other user app (`gedit`, nautilus) was running. `coredumpctl list --since 11:48` empty.

`mutter-rpc.debug.log` on that host matches the same 11:52:30 press (`Gsr-Clutter.get_current_event`) and 11:52:35 `Clutter-ClickAction.get_button`, then the BoxPointer layout. No further button traffic on the server journal through 11:56.

### 2026-10-08 12:22 — user killed the dead shell

User: they killed it because it was non-responsive. They were clicking everywhere and nothing happened.

Fetched again at 12:22. Session 218 still active, `IdleHint=yes`. `gsr-client` gone. `gsr-server` 28948 and `yelp` 29510 still running. Client log grew to 40732 lines and stops at 11:57:50.644 (`St-BoxLayout.new` id=15682) while constructing a background actor (`Gsr-Mutter-BackgroundActor.create`, `set_content`, `Meta-BackgroundContent.set_vignette`). After 11:52:42 the only notifications are 5179 `before-update`, 3 `style-changed`, 1 `notify::key-focus`, 1 `stopped`. No button event of any kind. Mutter RPC log in 11:52:42–11:58:00 has 0 lines matching `button`, `get_current_event`, `ClickAction`, or `pointer`.

Kernel: `gsr-client[30002]: segfault at 733cb01 ip 00007e0ce4b66e60` in `libmutter-clutter-rpc-16.so`. `coredumpctl info 30002`: signal 11, 11:57:50, core present (8.5M). `#0 clutter_actor_set_pivot_point`, `#1–#3` libffi, then gjs/mozjs. Further down, `g_object_notify` → `g_signal_emit` → JS. Server logged `client exited manual-restart=false` at 11:57:52 and did not spawn a replacement. The five `set_pivot_point` RPCs in the file log are earlier, at 11:52:41, the same second as the last `key-press-event`.

### 2026-10-08 12:29 — picker search launches Terminal, then stuck

User restarted in debug, opened the app picker, typed `term`, Terminal started, and the shell stuck.

`gsr-client --debug` 31111 spawned 12:28:54. `READY=1` 12:29:00.306. `gsr-server` still 28948. `yelp` 29510 still up from the 11:48 run. The new client replaced the debug log.

Sequence in `org.gnome.ShellRpc.debug.log`:

- 12:29:08.781 `Clutter-Stage.grab` id=11367, then `Clutter-Grab.get_seat_state` id=11374. No `dismiss` anywhere in this file.
- 12:29:19.992 `button-press-event`, `key-focus-in`.
- 12:29:20.658, .738, .848, .900 `key-press-event`. Each is followed by `value_lcopy_boolean` / `gsignal.c:3480` gboolean NULL. One `g_closure_unref` assertion at 12:29:20.795.
- 12:29:22.042 and 12:29:22.254 `button-press-event`.
- 12:29:23.755, .907, 12:29:24.346, .519 `key-press-event`, same gboolean NULL after each. 12:29:24.663 `allocation` of `Gjs_ui_search_GridSearchResults` is not writable.
- 12:29:27.546 `button-press-event` and `Clutter-Stage.grab` id=16453. `key-focus-out`. `clicked` 12:29:27.753. `launch_desktop_file` id=16581 at 12:29:28.327. `leave-event` 12:29:28.362.
- `gnome-terminal-server` 31365 started 12:29:27. `window-added` / `Window.created` 12:29:30.105–.115. `notify::focus-window` 12:29:30.201, then critical: property `focus-window` of `MetaDisplay` is not writable. `title` of `MetaWindow` is not writable. `St-Widget.set_label_actor` id=17746 and id=17752: warning plus `St_generated.vala:3038` error `-32602`.
- 12:29:30 to 12:29:34.715: `captured-event` paired with `event`, then `before-update`. Counts after 12:29:28: 177 `captured-event`, 179 `event`, 0 `captured-event::button`, 0 `button-press-event`, 0 `button-release-event`.
- 12:30:00 and 12:31:00 are only the clock (`St-Label.set_text` replied). At 12:31:40 the client was still `Sl` in `do_poll`, 8 threads, not a spin. Whole file at that read: 4 `button-press-event`, 1 `clicked`, 1 `launch_desktop_file`, 0 `button-release-event`, 0 `dismiss`, 0 `JS ERROR`.

### 2026-10-08 12:34 — typing and panel menus work, top-left does not

User: they can type whatever they like. Clicking did nothing. Then: the date menu and the power menu open. The top-left control that switches between the desktop and the overview does not.

`key-press-event` 12:33:17.626 → `text-changed` → `St-Entry.get_text` id=18816 → `Clutter-Text.set_markup` id=18822. Further `key-press-event` through 12:33:21.803.

`button-press-event` 12:33:15.055 and 12:33:16.312. Both are followed by `Clutter-Text.get_text` (`id=18702`, `id=18782`). Then `captured-event` / `event` / `get_actor_at_pos`. No `button-release-event`. No `clicked`.

`button-press-event` 12:33:56.013 (`Clutter-Text.get_text` id=20979) and 12:33:56.766 (`Clutter-Text.get_text` id=20988). At 12:33:58.130 `Clutter-Actor.show` twice. 12:33:58.180 `notify::mapped`, then critical: `mapped` of `Gjs_status_system_ShutdownItem` is not writable. 12:33:58.332 `Clutter-Stage.grab` id=21100, `key-focus-out`, `set_key_focus`, `Clutter-Text.set_cursor_visible`. That is the power menu opening on the press. Still no `button-release-event` and no second `clicked` in the file.

### 2026-10-08 12:38 — bottom panel click

User: clicked the bottom panel and nothing happened. Asked whether anything went from the server to the client for that click.

Checked 12:38:21. Client last UI notification is `button-press-event` 12:33:56.766. Before that, `captured-event::button` at 12:33:54.041, .830, and .195. Server `mutter-rpc.debug.log` last non-clock line is `Clutter-Seat.get_touch_mode` id=22269 at 12:34:29. From 12:35 through 12:38 the only RPC either way is `St-Label.set_text` on the minute. No `button-press-event`, no `button-release-event`, no `clicked`, no `get_current_event` for that click.

`notification method=button-press-event` is the server pushing a signal the client subscribed to. `Actor.captured_event` / `event` call `LayoutHooks.measure_event` only when `vfuncs` has that hook, and they logged nothing on the miss. The dash click is in that gap.

2026-10-08 12:45. User asked for that debug, then they will compile and install the server. Added `GLib.debug("type=%d actor=%s hook=%d", ...)` at the start of `Actor.event` and `Actor.captured_event` in `src/server/libmutter-clutter-16/ClutterActor.vala`, before the `hook == null` return. `src/` client code was not changed. Not installed.

### 2026-10-08 13:03 — debug server is running

User rebuilt and ran it. `/usr/bin/gsr-server` and `gsr-client` mtime 12:59:46. Session processes: server 36349 from 13:02:19, client 36642 from 13:02:20.

`mutter-rpc.debug.log` has 1512 hook lines. `hook=1` is only `ActivitiesButton` on `ClutterActor.vala:358` (`event`): enter, motion, press 13:02:40.350849, release 13:02:40.462333, leave. Capture (`:376`) of that same button is `hook=0`.

Client at the press: `captured-event`, `get_actor_at_pos`, `event`, `button-press-event` 13:02:40.353176. Client at the release: `captured-event`, `event`, `Meta-Display.is_grabbed` id=13185, `Clutter-Stage.grab` id=13187, `set_key_focus`, `Clutter-Actor.show`, `mapped` not writable on `StEntry` and `StWidget`. No `button-release-event` anywhere in the client log.

One `clicked`, at 13:02:35.477, with `launch_desktop_file` id=12223. That press was `StWidget` capture `hook=0` at 13:02:35.349882.

Press/release pairs after that, 13:02:43 through 13:03:04, are `StWidget` `hook=0` on both capture and bubble. The client log in that stretch is `key-press-event` only. No `Gjs_ui_dash_Dash` or app-icon actor name in the server log.

### 2026-10-08 13:10 — why hook=0

`create_with_overrides` in `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` compares `Clutter.Actor` vfunc slots to `StWidget`. No difference means `add_hooks` is not called. Client log: 290 `Gsr-Clutter-Actor.create`, 41 `add_hooks`, 131 `add_signals`.

`dash.js` `_box` (line 347) and `_background` (line 364) are `new St.Widget()` with no button or event connect. `Dash` extends `St.Widget` and does not override `vfunc_event`. Icons are `AppIcon` → `AppViewItem` → `St.Button` (`appDisplay.js` 1875, 2935), reactive, and they fire `clicked` from `St.Button`, not an event vfunc. They are absent from the event log, so the picked actor was the plain `StWidget`.

`ActivitiesButton.vfunc_event` (`panel.js` 452) handles `BUTTON_RELEASE` by `Main.overview.toggle()`. That is the only `hook=1`. `Panel` (`panel.js` 644) does not override `vfunc_event`; line 666 connects `button-press-event` to `_onButtonPress`, which only starts a window drag. That matches `Panel` `hook=0`.

### 2026-10-08 13:40 — name the dead widget

Client log at the 13:02:40.462 release: `Meta-Display.is_grabbed`, `Clutter-Stage.grab` id=13187, `Clutter-Actor.show`, then `mapped` on `StEntry`, `StWidget`, and `Gjs_ui_workspacesView_WorkspacesDisplay`, and `realized` on `Gjs_ui_windowPreview_WindowPreview`. `overview.toggle()` ran.

Press/release lines from 13:02:43 are only `actor=StWidget hook=0` on both `ClutterActor.vala:376` and `:358`. No `Gjs_ui_layout_UiActor`, `Panel`, or `Dash` on those events, so the widget is not a child of `uiGroup`. `overviewGroup` is a child of `uiGroup` and would have logged `UiActor` on the way down. It is not that widget.

`event` and `captured_event` now log `name=%s style=%s` beside the type and actor. Not a fix. Not installed.

### 2026-10-08 14:47 — overviewGroup

User: the first launch crashed, then a debug restart replicated the dead clicks.

`/usr/bin/gsr-server` and `gsr-client` mtime 14:45:34. Server 39711 from 14:45:54. Client 40048 spawned 14:45:56, `client exited manual-restart=false` 14:46:43. No coredump. Client 40489 spawned 14:46:45. Logs: `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log` and `org.gnome.ShellRpc.debug.log` on `alan@192.168.88.197`.

Press/release lines name the actor. Dead clicks are `name=overviewGroup style=` `hook=0` on capture and bubble (14:47:06 through 14:47:12). Client `button-press-event` lines: 14:46:53.551 (Activities), 14:46:58.232, 14:47:02.456. `clicked` 14:47:02.575. `launch_desktop_file` id=13338 at 14:47:03.127. No `button-press-event`, `button-release-event`, or `clicked` after that launch. The 14:47:02 press logged only capture on `overviewGroup`. The later presses log capture and bubble on `overviewGroup`.

### 2026-10-08 14:54 — stage 3

Command: `GI_META_SMOKE=picker-second-launch ./scripts/agent-nested-smoke-prove.sh`

The smoke now logs `overviewGroup` visibility after a launch and misses with `overviewGroup-still-up` when the overview is hidden but the group is still mapped. This run never got there.

`picker-second-launch: click id=org.gnome.Nautilus.desktop @270,520 press=1 release=1 clicked=false pick=Files`

`picker-second-launch: launch1 id=org.gnome.Nautilus.desktop state=0 windows=1 took=false`

`picker-second-launch: miss launch1`

Server, same second: press `type=6 actor=StWidget name=overviewGroup style= hook=0` (capture only), release `type=7` on `overviewGroup` capture and bubble. `nested-weston-prove: stop (smoke-fail) after 74s`. `src/` was not edited for this run.

Mutter’s own line for that click is `button press : ... x:232.00, y:461.00`, not 270,520. The press capture goes `overviewGroup` → `WorkspacesDisplay` → `WindowPreview` and does not bubble. The release does. `notification method=clicked` is at 14:54:04.508. That is not the VirtualBox failure. The VirtualBox presses from 14:47:06 bubble on `overviewGroup` alone and produce no `clicked`.

### 2026-10-08 15:04

`GSR_NESTED_TIMEOUT=120 GI_META_SMOKE=picker-second-launch ./scripts/agent-nested-smoke-prove.sh`

The smoke retries a click when `get_coords()` is not the requested point. This run never clicked. `prime page=800x315` at 15:04:32, then `nested-weston-prove: mutter exited ec=1 after 119s`. Weston logged `An output named 'screen0' already exists` and segfaulted (exit 139).

Same command again at 15:05. `grid-state value=2` at 15:06:14. At 15:07:21 the socket is already gone (`St-Icon.new id=171645: not connected`). `pick-icons=0`. `picker-second-launch: miss need two stopped icons`. `nested-weston-prove: stop (timeout) after 120s`. No click.
