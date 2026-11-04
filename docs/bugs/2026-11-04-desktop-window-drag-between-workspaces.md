# Desktop window drag between workspaces does not work

**Status:** Mutter 18 / Shell 50.1 on `alan@192.168.122.52`. This host Weston is mutter 16 and is not that proof. Shell 50 empty-panel move is `ClickGesture.recognize` → `get_point_event(0)` → `Backend.get_sprite` → `get_coords_abs` → `begin_grab_op(MOVING, sprite)`. `recognize` / `may-recognize` were not in the `add_signals` blocking switch, so the compositor cleared sequences before the client handler ran. Guest live: `get_point_event` asserts empty sequences; `get_sprite` 0; `begin_grab_op` 0. Off-code gate `gesture-recognize-point-gate current` FAIL / `fixed` PASS. Landed the two blocking names in `ClutterActor.add_signals`. Not installed on the live guest. Vibration is overview restack, not this path. Clipboard is lock-screen.

This is not [`2026-11-04-overview-window-drag-between-workspaces.md`](2026-11-04-overview-window-drag-between-workspaces.md). Overview previews use `St.DndStartGesture`. A mapped window on the regular desktop does not.

## Diagnosis

Guest client log `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` on `192.168.122.52`. Clipboard:

```text
14:40:05.865498 … St-Clipboard.get_default
14:40:05.867527 … St-Clipboard.set_text
```

Those sit between `Gsr-Mutter-IdleMonitor.add_user_active_watch`, `Clutter-Actor.grab_key_focus`, and `AccountsService.User::password-mode`. They are not a content drag.

`Gsr-Mutter-Window.begin_grab_op` and `Clutter-Backend.get_sprite` never appear on the guest (0 recv). Shell 50 `panel.js` `_onWindowDragGestureRecognize` is:

```js
const event = this._clickGesture.get_point_event(0);
const sprite = backend.get_sprite(global.stage, event);
const coords = this._clickGesture.get_coords_abs();
dragWindow.begin_grab_op(Meta.GrabOp.MOVING, sprite, event.get_time(), coords);
```

`Gsr-Clutter-PressGesture.get_point_event` hits `clutter_gesture_get_point_event: assertion 'point_index < (int) priv->sequences->len' failed`, replies empty, client returns null, JS throws `Argument event may not be null` (`searchController._maybeCancelSearch` at 16:51:57). The panel `recognize` path never reached `get_sprite` or `begin_grab_op`.

`Clutter-ClickGesture.new`, `set_recognize_on_press`, and `add_action` already go through Gi (219 / 71 / 317). `ClickGesture.rpc_register` not being called is not why construct fails. Client `get_coords_abs` RPCs `Clutter-PressGesture.get_coords_abs` via Gi (1 recv at 14:34:22, not the panel path — panel would have called `get_sprite` first). `recognize` notifications do arrive (`notification method=recognize` at 17:43:33) but the Activities-button handler does not call `get_point_event`.

Stock `clutter-gesture.c` emits `recognize` in `set_state`, then `maybe_move_to_waiting` clears `sequences` when every point has ended. `Gsr-Clutter-Actor.add_signals` treated `recognize` / `may-recognize` as one-way (not in the blocking switch). The client handler therefore runs after WAITING.

Guest vibration at 16:51 is overview chrome: 100 `WorkspacesView` + 88 `WindowPreview` preferred-width in ~15s, then `activate` → `set_child_above_sibling` / `layout_changed` / `get_stable_sequence` (`workspace.syncStacking`). Host mutter-16 Weston did not vibrate and is not this proof.

## Reproduction

Installed session on `alan@192.168.122.52` (mutter 18 / Shell 50.1). This host has only `libmutter-16`; its Weston nest is not the API-18 proof.

```bash
meson compile -C build tests/call-sync-repro/gesture-recognize-point-gate
timeout 5 ./build/tests/call-sync-repro/gesture-recognize-point-gate current
timeout 5 ./build/tests/call-sync-repro/gesture-recognize-point-gate fixed
```

`current` (product switch before the landing): `FAIL … miss null blocking=false points=0` and the same assertion string as the guest mutter log. `fixed` (recognize blocking): `PASS … points=1 blocking=true`.

```bash
meson test -C build gesture-recognize-point-current gesture-recognize-point-fixed --print-errorlogs
```

### 1. `src/server/libmutter-clutter-18/ClutterActor.vala` — `add_signals`

**Why.** Shell 50 `recognize` / `may-recognize` handlers call `get_point_event(0)` while stock still has sequences. One-way delivery lets `COMPLETED` → `WAITING` clear them first. The gate `fixed` mode is this edit.

**Where.** `Gsr.Server.Clutter.Actor.add_signals` blocking switch.

**Depends on.** `gesture-recognize-point-gate fixed` PASS.

#### Add

```
					case "long-press":
					case "recognize":
					case "may-recognize":
```

Landed in this tree. Guest `/usr/bin/gsr-server` is still the 14:32 binary.

## LLM efforts

- 2026-11-04 14:35. User reported the overview workspace drag failure, then this as a side note: on the normal desktop a window also would not drag to the other workspace, and asked whether the clipboard is taking the gesture. Opened this report. Distinguished from overview `St.DndStartGesture`. Guest `192.168.122.115` did not answer (`No route to host`). No session log for this drag.
- 2026-11-04 15:04. User gave `192.168.122.52` and asked to follow the debugging procedure. Guest hostname `alan-VirtualBox`, `gsr-client` pid 2705, `gsr-server` pid 2445. Read `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` and `mutter-rpc.debug.log`. No `begin_grab_op`. `St-Clipboard.set_text` at 14:40:05 is lock-screen construction. `St-Clipboard.get_default` at 15:03:34 is session start. Overview `StDndStartGesture` criticals are the other bug. Shell 50 `panel.js` `_onWindowDragGestureRecognize` calls `get_sprite` then `begin_grab_op`. Wrote `tests/gjs-embed/desktop-window-workspace-smoke.js`.
- 2026-11-04 15:11. Weston `GI_META_SMOKE=desktop-window-workspace-smoke` died in `main.start()`: `desktop-window-workspace-smoke: miss TypeError: global.stage.context is null`. `nested-weston-prove: mutter exited ec=133 after 4s`. The smoke omitted the PanelMenu `setMenu` hide that the working overview smokes use. That miss is boot, not the desktop move.
- 2026-11-04 15:12. Same command with the PanelMenu hide. `home=0 target=1 n=6 overview=false`, `grab=true`, `after=1 active=0`, `desktop-window-workspace-smoke: ok`. Programmatic `begin_grab_op` and `change_workspace_by_index` work on this mutter 16 nest. The prove then sat until `stop (timeout) after 90s` because the ok pattern did not list this smoke. Guest hand-drag still has no `begin_grab_op`. Clipboard is not that drag. Rewrote the smoke to press the titlebar and drag to the right edge, which is the user path.
- 2026-11-04 15:16. Titlebar/edge smoke: `frame=0,0 800x600`, `after=0 active=0`, `desktop-window-workspace-smoke: miss Error: miss edge-workspace after=0 target=1 home=0`. `nested-weston-prove: stop (smoke-fail) after 12s`. No `begin_grab_op` / `change_workspace` / clipboard in that window.
- 2026-11-04 15:16. Same smoke with `begin_grab_op` first: `grab=true` at 15:16:55.745, then the nest died during virtual motion (`mutter exited` / Weston signal 15) with no `after=` line. Guest generated `get_coords_abs` exists; server `PressGesture` does not register it. That is the Shell 50 panel path, not this mutter 16 press.
- 2026-11-04 16:26. Rewrote the smoke to require the frame to follow a 200px horizontal drag. First run `moved=0,32` from `0,0` and printed `ok` (false pass: y=32 is the panel inset, not the drag). Mutter 48 `meta-window-drag.c` has edge tiling only; it does not `change_workspace` on a side-edge move.
- 2026-11-04 16:27. After a 600ms wait, `overview=true` and `miss titlebar-move dx=0`. Launch brings the overview back.
- 2026-11-04 16:27. Hide after launch + 400ms still `miss desktop after launch (overview visible)`.
- 2026-11-04 16:28. Poll hide + `showing` → hide. `overview=false frame=0,0`, press `400,12` (panel), `miss titlebar-move dx=0 from=0,0 to=0,32`.
- 2026-11-04 16:29. Settled titlebar: `frame=0,32 800x568`, press `80,48` drag `280,48`, `miss titlebar-move dx=0 from=0,32 to=0,32`. `nested-weston-prove: stop (smoke-fail)`.
- 2026-11-04 16:29. `begin_grab_op` then motion only: `grab=true press=80,48 drag=280,48` at 16:29:36, then the nest hung until timeout. No `moved=` line.
- 2026-11-04 16:31. Same titlebar press+drag with timestamp `0` (as `pointer_click`). Still `miss titlebar-move dx=0 from=0,32 to=0,32`. Guest `St-Clipboard.set_text` at 15:11:09 is another lock-screen (`IdleMonitor` + `grab_key_focus`), not a content drag. `org.gnome.Shell.Eval` on the guest returns `(false, '')`.
- 2026-11-04 16:32. Pick at `80,48`: `[ClutterActor]` not a `Meta.WindowActor`. `maxh=true maxv=true` on a `800x568` frame. Maximized titlebar drag does not move. `win.unmaximize(BOTH)` then `frame=100,49 664x450` `maxh=false`, press `180,65`, then `notify_button(PRESSED)` never returned and the nest sat until timeout. Grab-start during a client-side virtual-button RPC hangs. The completing miss is the maximized titlebar path.
- 2026-11-04 16:35. Pick chain is `_coverPane` (`ClutterActor` 800x600, parent `uiGroup` insensitive, stage title still `Starting GNOME Shell`). `MetaWindowActorWayland` for gedit is `reactive=false` (normal for Wayland). `layout.js` adds that reactive cover during `_prepareStartupAnimation` and destroys it in `_startupAnimationComplete`. The smoke was dragging through startup. Guest journal has no `laters is null`. Next: wait for `layoutManager._startingUp === false`.
- 2026-11-04 16:36. Waiting for `!_startingUp` while `showing` → `hide` hung the nest (no further smoke lines).
- 2026-11-04 16:38. Wait startup first (no showing hook): `startingUp=true`, then `startup-complete cover=no`, then `miss desktop (overview still visible)` — hide-loop did not land.
- 2026-11-04 16:39. Wait `hidden` after startup: `overview=false`, pick chain is `MetaWindowActorWayland` (cover gone). Still `maxh=true maxv=true`, `miss titlebar-move dx=0 from=0,32 to=0,32`. Stock titlebar-drag should unmaximize and move. It did not.
- 2026-11-04 16:40. Same hide-after-startup was flaky: `miss desktop (overview still visible)` after 8s. Did not reach unmaximize. The 16:39 line is the completing bar.
- 2026-11-04 16:52. User: they never said maximized; their windows are not maximized and are vibrating; the review stop was wrong. Guest still `gsr-client` 2705 / `gsr-server` 2445. `Argument event may not be null` at 16:51:57 and 16:51:58 is Shell 50 `searchController._maybeCancelSearch`: `get_point_event(0)` is null, then `stage.get_event_actor(event)`. Followed by `Meta-Window.activate` and `Gsr-Clutter.get_current_event`. `set_allocation` is bursting. Rewrote the smoke to unmaximize, sample frames, `move_frame`, then titlebar-drag.
- 2026-11-04 16:53. Weston: `startup-complete cover=no`, `overview=false`, `maxh=false` `frame=100,79 664x426`, eight samples all `100,79` (no vibrate on the nest). `move_frame` to `300,79`. Titlebar press `380,95` drag `580,95`, pick is `MetaWindowActorWayland`. `moved=300,79`, `miss titlebar-move dx=0`. Guest mutter log for the 16:51 click: `clutter_gesture_get_point_event: assertion 'point_index < (int) priv->sequences->len' failed` on `Gsr-Clutter-PressGesture.get_point_event` id=119143.
- 2026-11-04 16:55. Hide-after-startup flaked again: `miss desktop (overview still visible)`. The 16:53 floating `dx=0` after `move_frame` is the bar.
- 2026-11-04 17:02. Two gedits, overview shown. Previews `130,227 416,227` ×8 (no vibrate). Click preview, then hide. `maxh=false` `frame=0,32 800x568`, `move_frame` to `200,32`. Titlebar press `280,48`: `pressed focus=Untitled Document 2 same=true grabbed=false`. Mutter: `notify_button` → `raw button press` device 2. `moved=200,32`, `miss titlebar-move dx=0`. Pre-launch hide still flakes; skipped.
- 2026-11-04 17:04. Same path. `allows_move=true captured=5` (LEAVE only). Overlapping 800-wide frames; pick was Document 1's actor while `win` was Document 2.
- 2026-11-04 17:05. `move_resize_frame` to non-overlap did not stick (both `100,79 664x220`). After `move_frame` Doc2=`140,79` Doc1=`100,79`. Pick is Doc2. `captured=3,6` (MOTION + BUTTON_PRESS). `grabbed=false allows_move=true`. After drag both unmoved. Titlebar Clutter press does not become a move grab.
- 2026-11-04 17:27. Host 16 nest with `WAYLAND_DEBUG=1`: titlebar motion sent `wl_pointer.leave` on the gedit surface; `get_event_actor` was `MetaBackgroundActor`. That is a mutter-16 nest, not the guest 18 failure.
- 2026-11-04 17:29. User: this is mutter 18; host 16 Weston has not reproduced it. Guest `libmutter-18` 50.1, session `gsr-server` 2445 / `gsr-client` 2705, `meson` `mutter API 18`. `st-dnd-start-gesture-lease` EXPECTEDFAIL on that tree. Guest `panel.js` `_onWindowDragGestureRecognize` uses `get_point_event` + `get_sprite` + `get_coords_abs` + `begin_grab_op`. Live mutter log: `get_sprite` 0, `begin_grab_op` 0, `get_point_event` assertion at 16:51:57. `Clutter-18` namespace registers `PressGesture` only; `ClickGesture` / `Backend` / `PanGesture` / `LongPressGesture` peers exist and are not registered. Client `get_coords_abs` RPCs `Clutter-PressGesture.get_coords_abs`; server `PressGesture` does not declare it.
- 2026-11-04 17:51. Guest session still `gsr-server` 2445 / `gsr-client` 2705. `Clutter-ClickGesture.new` 219, `set_recognize_on_press` 71, `add_action` 317 — Gi already constructs and attaches. `get_point_event` 15 (last 16:51:58 assertion). `get_sprite` 0. `begin_grab_op` 0. `get_coords_abs` 1 at 14:34:22 (not panel: no `get_sprite` before it). Client `notification method=recognize` at 17:43:33 with no following `get_point_event` (Activities-button handler). `add_signals` blocking switch omitted `recognize` / `may-recognize`. Wrote `tests/call-sync-repro/gesture-recognize-point-gate.vala`. `current` FAIL `miss null blocking=false points=0` plus the live assertion string. `fixed` PASS `points=1 blocking=true`. Landed those two names in `src/server/libmutter-clutter-18/ClutterActor.vala` `add_signals`. Not meson-installed on the live guest. Titlebar `xdg_toplevel.move` and overview `St.DndStartGesture` are other paths.
