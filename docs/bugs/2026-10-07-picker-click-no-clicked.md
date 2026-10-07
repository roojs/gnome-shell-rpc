# Second app from the picker leaves the shell dead

**Status:** ⏳ Primary bug. No failing gate. No fix. Reproduce the flow below. Do not stop to narrate.

## Do not stop

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
