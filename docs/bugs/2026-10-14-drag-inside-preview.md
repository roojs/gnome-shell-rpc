# Drag that stays on the preview never starts

Split from [`2026-10-12-overview-thumbnail-drag.md`](2026-10-12-overview-thumbnail-drag.md) on 2026-10-14. That file is only a pointer. The long log is [`archive/2026-10-12-overview-thumbnail-drag.md`](archive/2026-10-12-overview-thumbnail-drag.md).

**Review:** not done. There is no fix to accept.

**Status:** a press on an overview window preview followed by a move that stays on the preview does not start a drag. The 13:33 smoke printed `miss drag-begin` with `began=false inDrag=false dx=0`. No `type=3` motion is delivered to the preview after the press. The next reproduction is a Vala gate under `tests/call-sync-repro/`. Try strategies there. Do not use a JavaScript smoke as the place to invent the fix. The leave path is a different bug and is fixed. The hang after a drag has started is [`2026-10-14-drag-scale-gone.md`](2026-10-14-drag-scale-gone.md).

## What this is not

A move that leaves the preview does start a drag. `get_current_event` returns a copy of that crossing when stock current event is null (`open_event` in `src/server/libmutter-clutter-16/Clutter.vala`). Do not reopen `dnd.js:151`.

Before that copy, Weston 11:05:05 and the guest `alan@192.168.122.52` at 11:05:49.315 and 11:05:51.760 were the same throw. Weston lines:

```text
11:05:04.684  captured-event type=6 (button press) on WindowPreview
11:05:04.685  notification method=long-press
11:05:04.685  method=RPC-Live-Callback.reply
11:05:04.829  backend motion x=433
11:05:05.114  backend motion x=640
              no actor type=3 between the press and the leave
11:05:05.118  captured-event type=5 (leave) on WindowPreview
11:05:05.118  notification method=long-press
11:05:05.118  method=Gsr-Clutter.get_current_event id=38506
11:05:05.119  JS ERROR: TypeError: event is null
              addClickAction/<@resource:///org/gnome/shell/ui/dnd.js:151
11:05:05.121  notification method=leave-event
```

`dnd.js:151` is `event.get_event_sequence()` after `Clutter.get_current_event()`. The server reply was empty. The user retest at 13:16:45.949, 13:17:10.762, and 13:17:17.478 was that same `event is null` sequence: `long-press`, empty `get_current_event`, `leave-event`.

After the copy, the smoke that moves to `x + w + 80`, `y + h + 80` printed, at 13:35:50:

```text
overview-thumbnail-drag-smoke: after began=true inDrag=true dx=108.09375
overview-thumbnail-drag-smoke: ok
```

No `event is null` in that window. That run was fast enough that `scale-x` was still alive at `dnd.js:522`. It does not cover the scale hang, and it does not cover a move that stays on the preview.

Click-to-activate is fixed (`event-reschedule`). `overview-window-activate-smoke` printed `ok`. Do not reopen it.

The queue flush in the event filter does not deliver the post-press motions on the live RPC path. `tests/call-sync-repro/clutter-drag-leave-gate` PASSes with motion type 3 because the filter is compiled into the gate and the gate does not reenter the main loop. Do not flip `should_fail`. The unfixed batched failure was `FAIL ... leave cancel had no current event type=-1`.

## The failure

The cache logs are not on the next machine. The lines below are the record. Copied from `org.gnome.ShellRpc.debug.log` and `mutter-rpc.debug.log` before those files were left behind.

Hand session 2026-10-14 12:12–12:13. No drag started:

```text
12:12:51.637  button press, x=327, on the preview
12:12:51.641  notification method=long-press
12:12:51.737  one actor type=3 cluster, then no further motion on the preview
              backend motions continue from x=327 to x=586
12:12:52.154  notification method=long-press, then activate
              no Gsr-Clutter.get_current_event
12:12:57      same long-press query, then activate
12:13:28      same long-press query, then activate
```

Smoke that stayed inside the preview. Runs at 13:23, 13:30, 13:32, and 13:33 all ended the same way. The 13:33 lines:

```text
overview-thumbnail-drag-smoke: after began=false inDrag=false dx=0
overview-thumbnail-drag-smoke: miss Error: miss drag-begin
nested-weston-prove: stop (smoke-fail) after 11s
```

Server side of that run: press on the preview, then motions from x=413 to x=553, and no actor `type=3` after the press. The event filter does see those motions. The device is `Virtual core pointer`. The actor is `GsrServerClutterActor`. They are not emitted to the preview.

An earlier smoke that only required `drag-begin` printed `ok` at 12:08:04 while the client log at that moment was `TypeError: this._dragActor.get_transition(...) is null` at `dnd.js:522`. That `ok` is not this bug and it is not a pass of the scale hang either.

`clutter_stage_handle_event` updates the device, and that update emits the leave, before it pushes `current_event`. Motions that would cancel the long press from `clutter_stage_process_event`, where `current_event` is set, stay queued. The queue drops a motion when the next event is a leave. That explains the leave cancel, which is fixed. It does not explain the in-preview miss: those motions never become actor `type=3` events after the press, so the long-press cancel that starts the drag does not run.

## Reproduction

Prefer a Vala gate under `tests/call-sync-repro/`, on the pattern of `signal-reentrancy-gate.vala`: modes for each strategy, no product source linked, no shell boot. The failing mode is a press, then motions that stay on the actor, with no actor `type=3` after the press, and no drag. A passing mode delivers those motions and starts the drag. Strategies stay in that file until one mode passes. Only then may a minor change be copied into `src/`.

`clutter-drag-leave-gate` is the wrong program. It PASSes type 3 because the filter is compiled into the gate and the gate does not reenter the main loop. Do not flip `should_fail`.

The JavaScript smoke below is the hand evidence. It is not the suite to hack. `tests/gjs-embed/overview-thumbnail-drag-smoke.js` currently moves off the preview (`x + w + 80`, `y + h + 80`). That is the leave path, not this bug.

```bash
GI_META_SMOKE=overview-thumbnail-drag-smoke GI_META_SMOKE_CMD='gedit --new-window' GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 GSR_WESTON_PIXMAN=1 GSR_NESTED_TIMEOUT=90 ./scripts/agent-nested-smoke-prove.sh
```

The 13:33 fail line is the block above: `overview-thumbnail-drag-smoke: miss drag-begin`. Prove exit 137 is an external SIGKILL. The smoke line in this file is the result. Do not start a prove while a nested Weston session is up.

`clutter-drag-leave-gate` output, so it does not have to be rerun to see the old result:

```text
FAIL clutter-drag-leave-gate: leave cancel had no current event type=-1 count=1
PASS clutter-drag-leave-gate: flushed motion cancel type=3 count=1
```

The PASS is the flush compiled into the gate. It is not the live RPC path.

## Do not repeat

- Do not edit `src/` until the same change already passes in a Vala gate under `tests/call-sync-repro/`. Do not treat `overview-thumbnail-drag-smoke` as that suite. The gate has to fail the same way as the 13:33 `miss drag-begin` first.
- Do not treat the leave smoke's `ok` as this bug being fixed.
- Do not treat `clutter-drag-leave-gate` PASS as this bug being fixed.
- Do not add another queue flush and call it done. The flush already in `Clutter.vala` did not deliver post-press motions on the RPC path.
- Idle is not how to deliver a held notification.

## Where to start

The 12:12 and 13:33 blocks in this file are the logs. Do not go looking for `~/.cache`. The failure is: press, backend motion, no actor `type=3`, long-press activates, no drag. Shrink that into a Vala mode under `tests/call-sync-repro/`. Leave `src/` unchanged until that mode fails the same way and a later mode passes. Follow `docs/debugging.md`.

## LLM efforts

### 2026-10-14 16:47 split out of the thumbnail-drag log

Recorded here so the scale-timeline hang is not used as the diagnosis for a drag that never starts.
