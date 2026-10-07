# Picker click never becomes clicked

**Status:** ⏳ Stage grab does not drop the release. The click that does nothing is not reaching an `St.Button`. No fix proposed.

ℹ️ The `clutter_event_get_time` throw is [`done/2026-10-06-picker-click-get-time.md`](done/2026-10-06-picker-click-get-time.md). That throw is not this login.

## Problem

🔷 Type in the application picker. Search results appear. Clicks on them do nothing.

🔷 Expected: a result click launches the application.

🔷 Actual, 2026-10-07 14:31 login on `alan@192.168.88.197` (`gsr-client` 11267, binaries mtime 14:31:32): the pointer still delivers presses, and nothing launches.

## Evidence

ℹ️ `journalctl -b _PID=11267` from 14:31:41 until the client died at 14:39:05.

✔️ Six `notification method=button-press-event`. Zero `button-release-event`. Zero `clicked`. Zero `JS ERROR`. Zero `Could not locate clutter_event_get_time`. Zero `launch_desktop_file`.

✔️ One press, 14:33:38.204, is followed by `Clutter-Actor.has_key_focus`, `Clutter-Seat.get_touch_mode`, and `Clutter-Text.get_text`. No stage grab. No `get_time` call.

🚫 The previous diagnosis (throw inside `dnd.js` `_onButtonPress` after `_grabActor`, later clicks swallowed by that grab). This login does not throw, and the first press also produces no `clicked`.

## Debug

✔️ Button press and button release log `type`, `button`, and `time` when an event is packed. Motion is not logged. `--debug` is already how this session runs.

- `src/server/libmutter-clutter-16/Clutter.vala` — stage event filter (`captured-event`, `event`)
- `src/server/libmutter-clutter-16/ClutterEventOverride.vala` — signal argument (`button-press-event`, `button-release-event`)
- `src/client/libshell-16/ClutterEventOverride.vala` — the event the client rebuilt

## Weston 2026-10-07 15:11

ℹ️ `gsr-client` 3017757, `gsr-server` 3017732, Weston `wayland-gsr`. Pointer coords are the mutter log (`button press` / `button release`).

✔️ First click, 15:11:34, `(478, 551)`. Press, `Clutter-Stage.grab` id 15610, release, `clicked`, then `Gsr-Mutter-AppLaunch.launch_desktop_file` id 15724. Overview then `Clutter-Grab.dismiss` id 16068, `set_key_focus`, `enable_unredirect` at 15:11:36. That is `Main.popModal`.

✔️ Second click, 15:11:39, `(59, 22)`. Top-left of the stage, the Activities button. Release calls `Meta-Display.is_grabbed` id 16601, then `Clutter-Stage.grab` id 16603, `disable_unredirect`, `set_key_focus`, `Clutter-Grab.get_seat_state`, then `Clutter-Actor.show`. That is `ActivitiesButton.vfunc_event` on button-release → `Main.overview.toggle()` → `show()` → `_syncGrab()` → `Main.pushModal(global.stage)`. No `clicked`, because toggle runs from the release vfunc.

✔️ Third click, 15:11:45, `(341, 60)`. Server packs the press twice (`captured-event`, then `button-press-event`). The release is packed once, `captured-event` only. The following `key-focus-in` is `Clutter.Text` taking focus. `shellEntry.js` connects `button-press-event` on the entry text and does not connect `button-release-event`. A missing release pack here is an absent subscription, not a dropped signal.

✔️ Fourth click, 15:12:22, `(713, 389)`. Press and release are each packed once. Both are `captured-event`. The client handler then calls `get_actor_at_pos`, `has_key_focus`, and `get_text`, so the pick is not the entry text and the text still has focus. No `button-press-event`. No `clicked`. A search result is an `St.Button` whose `vfunc_clicked` is subscribed as `clicked`. That signal did not fire, so `st_button_button_release` did not run.

## Off the shell

✔️ `button-release-deliver-gate` starts headless mutter, puts a reactive child on the stage, and clicks it. The child gets `button-press-event` and `button-release-event`. The same click after `clutter_stage_grab(stage)` still does. A stage grab does not drop the release.

✔️ A reactive sibling the size of the stage, added above that child, is the pick target. The stage still emits `captured-event`. The child gets neither press nor release.

## Candidate: unset signal return

ℹ️ `Subscription.emit` does not write the boolean return. Clutter stops the chain when `captured-event` returns true, which would skip `button-release-event`.

✔️ `button-release-chain-gate` uses `g_signal_accumulator_true_handled`. A handler that returns true stops the next handler. A handler that leaves the return unset does not. Exit 0: `PASS button-release-chain-gate: unset return did not stop the next handler`.

🚫 Writing false into that return would not change this gate, and it is not a fix for the Weston release.

## Root cause

⏳ The result click's stage `captured-event` runs and the `St.Button` `clicked` signal does not. A stage grab still delivers the release (`button-release-deliver-gate`). The same gate's reactive sibling above the child matches the log: stage `captured-event`, nothing on the child. The actor mutter picked at `(713, 389)` is not the result button. Do not patch `dnd.js`, the grab, or `get_time` from this note.

## Crash in the same session

ℹ️ 14:39:05 `client exited`. That death is [`2026-10-07-blur-effect-alias.md`](2026-10-07-blur-effect-alias.md). It is not this click.
