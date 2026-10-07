# Picker click never becomes clicked

**Status:** ⏳ Weston second click is the Activities button opening the overview. Clicks after that lose the release. No fix proposed.

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

✔️ Third click, 15:11:45, `(341, 60)`. Press becomes `button-press-event` and `set_key_focus`. During that press the client constructs `St.Button` and layouts. Release is `captured-event` type 7 and never becomes `button-release-event` or `clicked`.

✔️ Fourth click, 15:12:22, `(713, 389)`. Press and release are 4ms apart. No `button-press-event`.

## Root cause

⏳ The second click is the Activities toggle, and it does take the overview modal grab. The hang is the clicks after that: the release is captured and not delivered. Do not patch `dnd.js`, the grab, or `get_time` from this note.

## Crash in the same session

ℹ️ 14:39:05 `client exited`. That death is [`2026-10-07-blur-effect-alias.md`](2026-10-07-blur-effect-alias.md). It is not this click.
