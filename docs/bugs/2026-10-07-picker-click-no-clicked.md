# Second app from the picker leaves the shell dead

**Status:** ⏸ Held open. 2026-10-08: the user cannot reproduce this. Do not keep proving it until they say it is back.

**Held:** No failing gate. No fix. `src/` was not changed. The scripted smoke is `tests/gjs-embed/picker-second-launch.js`. It is not a confirmed reproduction of this report.

**What:** First picker launch works. The second picker launch also starts the app. After that, clicks do nothing, except the top menu, which still opens, and logout from it still works.

**Diagnosis:** The morning Weston session launched two apps from the picker (`launch_desktop_file` id=19581 at 10:30:08 and id=30691 at 10:30:19) and then kept taking some clicks. That log had 8 `button-press-event`, 6 `clicked`, and 0 `button-release-event`. No `JS ERROR`. The client exited on Weston shutdown (`socket closed` 08:27:14, `pending=0`).

09:30 prove, after `IconGridLayout.adaptToSize(800, 315)` from the smoke: Calculator click `press=1 release=0 clicked=false` and `launch1 took=true` (`state=0`, one normal window). Contacts click `press=1 release=0 clicked=true`, `state=2` (RUNNING), `launch2 took=true`. The grid opened again (`grid-after2 visible=true icons=21`). The next click never logged. `nested-weston-prove: stop (timeout) after 90s`. No `after3` line. `src/` unchanged.

**Reproduce:** `GI_META_SMOKE=picker-second-launch ./scripts/agent-nested-smoke-prove.sh`

## Do not stop

Paused 2026-10-08. The user cannot reproduce the report and asked to hold this file open. Do not resume the prove loop until they say the failure is back.

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

Session clock is 10:29:55 through 10:35:08, then the timestamps jump to 08:26:16 and the socket closes at 08:27:14. `READY=1` is line 11894 at 10:29:58.841. Two launches: client `id=19581` at 10:30:08.346 (press, `Clutter-Stage.grab` `id=19492`, `clicked`, then launch) and `id=30691` at 10:30:19.856 (press, grab `id=30469`, `clicked`, then launch). Grabs dismissed at 10:30:09.009 (`id=20365`), 10:30:21.366 (`id=33201`), 10:30:30.143 (`id=47047`), 10:30:42.734 (`id=57205`). Later presses at 10:30:23, 10:30:29, 10:30:37, and 10:30:41 still arrived. `clicked` at 10:30:41 is followed by `Meta-Window.set_demands_attention`, so that click still reached a window path. No third `launch_desktop_file`. No `button-release-event` anywhere in the file. Prove-log tail is older `weston-gsr-autolaunch: mode=session` starts, not a `nested-weston-prove: stop` for this run. The tee’s last line is the Weston connection drop at 08:27:14.

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
- 09:30. Smoke calls `layout.adaptToSize(800, 315)` before the pick (`prime page=800x315`). `pick-icons=20`. Calculator `@470,440 press=1 release=0 clicked=false box=418,226 91x65`, `launch1 state=0 windows=1 took=true`. Contacts `@170,280 press=1 release=0 clicked=true`, `launch2 state=2 windows=2 took=true`. `grid-after2 visible=true icons=21` at 09:31:56. The following `pointer_click` id=125601 was replied at 09:31:56.841. It delivered `button-press-event`, `clicked`, and `launch_desktop_file` id=125681 (replied; dbus activated `org.gnome.Weather`). Then a `gsignal.c:2699` “no handler” storm. `client exited` at 09:31:58.369. Prove log line 33412080: `nested-weston-prove: stop (timeout) after 90s`.
- 09:33. `FAIL start TypeError: global.stage.context is null`. `mutter exited ec=133` after 3s.
- 09:34. `mutter exited ec=1` after 50s. Weston process segfaulted (exit 139). No smoke marker for that boot.
- 2026-10-08 09:37. User: cannot reproduce the original report. Hold the bug open. Stop proving.
