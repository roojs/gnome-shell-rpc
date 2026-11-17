# Desktop Cube horizontal swipe does not rotate workspaces

**Status:** Open. The 09:56 reinstall still does not spin the cube. Login `gsr-client` 271923 throws while the overview animation runs:

```text
TypeError: can't access property "set_child_at_index", parent is null
_depthSortCubeFaces extension.js:876
_updateWorkspacesState extension.js:255
```

Journal times 09:57:07 and 09:57:38. The throw aborts the cube's workspace update, so the faces never reorder. Same stack in headless `/tmp/cube-parent.log` during `overview.show()`. After that show finishes, `get_parent()` on the first workspace is not null. A plain `St.Widget` child also round-trips (`probe same=true`). The actor whose parent is null on the throwing call is not identified yet. The same login also throws `this.layout_manager is null` from `iconGrid.js:1262` while building the app grid.

Related but different:
- [`docs/bugs/done/2026-11-07-desktop-cube-lockup.md`](done/2026-11-07-desktop-cube-lockup.md) — enable lockup from `Stage.perspective` / `ClutterPerspective` write (`parent is null`). Fixed for local mutter 16.
- [`docs/bugs/2026-11-05-app-grid-swipe-disappears.md`](2026-11-05-app-grid-swipe-disappears.md) — app-grid upward swipe → `Invalid position NaN` via `PanGesture` / `swipeTracker.js`. Same gesture neighborhood; not cube rotation.

## Diagnosis

`desktop-cube@schneegans.github.com` attaches a `DragGesture` (`~/.local/share/gnome-shell/extensions/desktop-cube@schneegans.github.com/src/DragGesture.js` on the VM) to overview chrome, `Main.layoutManager._backgroundGroup`, and `Main.panel`. On horizontal drag past `drag_threshold` it should grab the stage and drive `Main.wm._workspaceAnimation._swipeTracker` (desktop/panel) or the overview workspaces swipe tracker.

Three independent surfaces, three different failure modes after the DING + state-packing apply:

| Surface | Expected | Observed (post-apply 2026-11-14 12:19 `/tmp/cube-err.log`) |
|---------|----------|--------------------------------------------------------------|
| Overview | swipeTracker `begin`/`update`/`end`, workspace changes | `began=0 updated=0 ended=0 ws=0` (pre-apply on 2026-11-13 had `began=1 updated=13 ended=1 ws=3`) |
| Desktop background | same via `_backgroundGroup` | `began=0`; no `ev bg` lines — maximized DING `Desktop Icons 1` covers `_backgroundGroup` at `y=400` |
| Panel | same via `Main.panel` | `BUTTON_PRESS state=256` → PENDING (`0->1`); then `LEAVE` at `680,10` → cancel (`1->0`); `grab=false`; `began=0` |

Clutter 18 event types (from VM `clutter-enums.h`): `MOTION=3`, `ENTER=4`, `LEAVE=5`, `BUTTON_PRESS=6`, `BUTTON_RELEASE=7`. `BUTTON1_MASK = 1<<8 = 256`.

### Two event delivery paths

| Path | Actors | Wire | `get_state()` |
|------|--------|------|---------------|
| **A. `ClutterEventOverride`** | Stock actors e.g. `_backgroundGroup` (`MetaBackgroundGroup`) | Full event pack including `row.state` for MOTION/BUTTON (`src/server/libmutter-clutter-18/ClutterEventOverride.vala`) | Already had `state=256` before the LayoutHooks fix |
| **B. `LayoutHooks.measure_event`** | GJS `St.Widget` subclasses: `Main.panel`, overview chrome | Live.Hook → `Actor.relay_event` / `relay_captured_event` | Used to omit state → client `state=0`. **Now packed** |

Packing only repairs path B. Path A already had state; pre-apply it could reach `State.ACTIVE` after `global.stage.grab(this._actor)`, then lost further events and logged `Clutter-Backend.get_sprite` `-32602`, and (before the X11 alias fix) aborted when Xwayland created `MetaWindowActorX11`.

With DING enabled, path A is usually unreachable on the desktop. Real-session cube swipe is mostly **panel path B** or overview.

### `DragGesture._handleEvent` contract (VM extension)

- Always listens on `captured-event`; listens on `event` only after `_lastGrab` is set.
- `BUTTON_PRESS` → `State.PENDING` if `global.stage.get_event_actor(event)` is ok.
- `LEAVE` while `PENDING` → `_cancel()`.
- `MOTION` while not `INACTIVE` and `(event.get_state() & BUTTON1_MASK) == 0` → `_cancel()` (this is what zero state packing broke).
- Past `drag_threshold` → `_grab()` = `global.stage.grab(this._actor)` → `State.ACTIVE`; further motion needs grab delivery on `event`.
- States: `INACTIVE=0`, `PENDING=1`, `ACTIVE=2`.

### Already applied (necessary, not sufficient)

In `src/` from the DING apply pass:

1. `src/server/libmutter-clutter-18/LayoutHooks.vala` `measure_event()` — appends `event.get_state()` for non-`SCROLL` (lines 143–145).
2. `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` — `relay_event` / `relay_captured_event` unpack `call.args.get(9)` into `Event.from_local(..., state, ...)` (around 496–500 and 552–556).

**Off-code gate:** `tests/call-sync-repro/captured-event-motion-state-gate.vala`

```bash
meson test -C build captured-event-motion-state-current captured-event-motion-state-fixed --verbose
# current EXPECTEDFAIL state=0x0; fixed PASS state=0x100
```

**VM proof packing works:** post-apply panel log `ev panel type=6 state=256 coords=800,10 0->1 grab=false`.

**VM proof packing is not enough:** same run then `ev panel type=5 state=0 coords=680,10 1->0` (LEAVE into the center-box `DateMenuButton` before threshold; smoke dragged `800 → 680` at `y=10`). Smoke ends `miss overview-swipe`.

The sections below through the 2026-11-14 log quotes are the account before 2026-11-15. The current account is the status at the top, plus **Applied** and **Still open** after the hypothesis table.

### 2026-11-14 account — missing mutter-18 `rpc_register` wiring

`src/server/meson.build` compiles these for API 18:

- `libmutter-clutter-18/Backend.vala`
- `libmutter-clutter-18/ClickGesture.vala`
- `libmutter-clutter-18/PressGesture.vala`
- `libmutter-clutter-18/PanGesture.vala`
- `libmutter-clutter-18/LongPressGesture.vala`

`src/server/libmutter-clutter-18/namespace.vala` `rpc_register()` currently calls `PressGesture.rpc_register(clutter)` only. It does **not** call:

```vala
Backend.rpc_register();
ClickGesture.rpc_register(clutter);
PanGesture.rpc_register(clutter);
LongPressGesture.rpc_register(clutter);
```

Those files' own headers claim “The 18 startup calls `rpc_register`” — that is false today.

`Backend.rpc_register()` registers live methods `Clutter-Backend.get_sprite` / `get_pointer_sprite`. Alias-only registration of the backend **type** in `register_alias()` (`namespace.vala` ~56–58) does **not** install those methods. The client still calls:

```vala
// src/client/libmutter-clutter-rpc-18/overrides/Backend.override.vala
Gsr.Client.Rpc.call_value("Clutter-Backend.get_sprite", this, …);
```

Pre-apply panel press logged `-32602` for that method. Not re-proven after the DING apply, but the wiring is still missing in tree.

### Still open — post-grab motion delivery

Pre-apply `_backgroundGroup` path: PRESS → PENDING → MOTION `state=256` → `stage.grab` → ACTIVE → **no further `event` / `captured-event` updates**. `ClutterStage.rpc_register()` only exposes `get_view_at` / `paint_to_buffer` — no `grab` peer under `src/`. Whether stock `Stage.grab` works over RPC without a helper, and whether ACTIVE motion should arrive on the grabbed actor’s `event` signal, is **unproven by a gate**. Need a standalone repro if empty-panel drag + Backend register still stalls after ACTIVE.

### Still open — smoke geometry and DING layering

- Panel drag in `tests/gjs-embed/desktop-cube-swipe/ui/init.js` starts at `x=800` (or `240`) at `y=10`. On a 1280-wide panel that crosses the clock (`DateMenuButton`) and emits `LEAVE` on `Main.panel` before `DragGesture` threshold → cancel while still `PENDING` / `grab=false`.
- Desktop drag at `y=400` hits maximized DING, not `_backgroundGroup`. Isolate background by disabling DING for one run, or treat panel/overview as the product paths.
- Overview `began=0` on 2026-11-14 may be timing (DING mapped mid-overview; also `__lambda29_: assertion 'event_actor != NULL' failed` in that log) rather than a permanent regression of the 2026-11-13 overview pass — re-check after panel path is clean.

## Reproduction

### Smoke (in tree)

`tests/gjs-embed/desktop-cube-swipe/ui/init.js` — enables `desktop-cube@schneegans.github.com`, ensures ≥4 workspaces, instruments `DragGesture._handleEvent`, virtual-pointer drags overview / desktop / panel, requires swipeTracker `began≥1` and `updated≥1` on each.

Pass: `desktop-cube-swipe/ui/init: ok`  
Fail: `desktop-cube-swipe/ui/init: miss <reason>`

### VM headless (mutter 18) — use this

```bash
ssh alan@192.168.122.115
rm -rf /tmp/gsr-rt && mkdir -p /tmp/gsr-rt && chmod 700 /tmp/gsr-rt
dbus-run-session -- timeout --foreground -k 2 22 env \
  XDG_RUNTIME_DIR=/tmp/gsr-rt \
  GSR_TYPELIB_DIR=/home/alan/gitlive/gnome-shell-rpc/build/src \
  MUTTER_RPC_SOCKET=/tmp/gsr-cube.sock \
  GI_META_SMOKE=desktop-cube-swipe/ui/init \
  XDG_CURRENT_DESKTOP=ubuntu:GNOME NO_AT_BRIDGE=1 GIO_USE_VFS=local \
  /home/alan/gitlive/gnome-shell-rpc/build/src/server/gsr-server \
  --headless --virtual-monitor 1280x800 --wayland-display wayland-gsr-cube \
  > /tmp/cube-err.log 2>&1
grep -E 'desktop-cube-swipe|began=|ev panel|ev bg|miss |ok|get_sprite|-32602' /tmp/cube-err.log
```

Older ad-hoc probe name on the guest: `GI_META_SMOKE=cube-swipe/ui/init`.

### Weston (mutter 16) — limited

```bash
GSR_NESTED_TIMEOUT=45 GI_META_SMOKE=desktop-cube-swipe/ui/init \
  ./scripts/weston-gsr-prove.sh
```

Mutter 16 does not build the clutter-18 `Backend` / gesture peers. Prefer the VM for this bug.

### State packing gate (already landed)

```bash
meson compile -C build captured-event-motion-state-gate
meson test -C build captured-event-motion-state-current \
  captured-event-motion-state-fixed --verbose
```

## Key log quotes

**Pre-apply (2026-11-13 ~10:45, `cube-swipe/ui/init`):**

```text
overview began=1 updated=13 ended=1 ws=3
desktop/panel began=0
panel captured type=5 state=0
backgroundGroup: BUTTON_PRESS → PENDING; MOTION state=256 → grab ACTIVE → no further events;
  Clutter-Backend.get_sprite -32602; Server.vala:172 MetaWindowActorX11 abort (core 93216)
```

**Post-apply (2026-11-14 12:19, `desktop-cube-swipe/ui/init`, `/tmp/cube-err.log`):**

```text
desktop-cube-swipe/ui/init: extension-state=1 hasStateObj=true
desktop-cube-swipe/ui/init: overview began=0 updated=0 ended=0 ws=0
desktop-cube-swipe/ui/init: desktop began=0 updated=0 ended=0 ws=0
desktop-cube-swipe/ui/init: ev panel type=6 state=256 coords=800,10 0->1 grab=false
desktop-cube-swipe/ui/init: ev panel type=5 state=0 coords=680,10 1->0 grab=false
desktop-cube-swipe/ui/init: panel began=0 updated=0 ended=0 ws=0
desktop-cube-swipe/ui/init: miss Error: miss overview-swipe
```

DING mapped successfully in that same run (`DING map client=true`, `DING owns=true`) — DING is no longer the blocker for cube work.

## Source map

| Piece | Path |
|-------|------|
| State pack (applied) | `src/server/libmutter-clutter-18/LayoutHooks.vala` |
| State unpack (applied) | `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` |
| EventOverride (bg path, state already OK) | `src/server/libmutter-clutter-18/ClutterEventOverride.vala` |
| Backend peer (not called) | `src/server/libmutter-clutter-18/Backend.vala` |
| Client `get_sprite` | `src/client/libmutter-clutter-rpc-18/overrides/Backend.override.vala` |
| Gesture peers (Click/Pan/LongPress not called; Press is) | `src/server/libmutter-clutter-18/{Click,Pan,LongPress,Press}Gesture.vala` |
| Startup register | `src/server/libmutter-clutter-18/namespace.vala` |
| Stage helper (no grab) | `src/server/libmutter-clutter-18/ClutterStage.vala` |
| Smoke | `tests/gjs-embed/desktop-cube-swipe/ui/init.js` |
| Gate | `tests/call-sync-repro/captured-event-motion-state-gate.vala` |
| DragGesture (VM) | `~/.local/share/gnome-shell/extensions/desktop-cube@schneegans.github.com/src/DragGesture.js` |

## Hypotheses

| Hypothesis | Status |
|------------|--------|
| LayoutHooks omit `event.get_state()` → panel MOTION cancels on BUTTON1 | **PROVEN**; **fixed in tree** |
| Packing alone makes cube swipe | **DISPROVEN** |
| Panel click gesture `.enabled = false` stays local; `get_enabled()` stays true | **PROVEN** (`cgEnabled=false cgGetEnabled=true` in `/tmp/cube-panel-first.log`) |
| That still-enabled gesture calls `Clutter-Backend.get_sprite` and the press gets no MOTION | **PROVEN** (`Clutter_generated.vala:3634` `-32602` on the press; `panel began=0`) |
| `ActorMeta.set_enabled(false)` on an empty panel span lets the swipe finish, including post-grab motion | **PROVEN** (`/tmp/cube-ov-clear.log`: `grab=true`, `panel began=1 updated=14 ended=1 ws=1`) |
| Post-grab motion needs a new `Stage.grab` RPC | **DISPROVEN** for the panel and for the DING-off desktop drag |
| Wiring `ClickGesture` / `PanGesture` / `LongPressGesture.rpc_register` fixes `get_sprite` | **DISPROVEN** as the cube panel fix. Those peers register `Gsr-Clutter-*`. The client constructs `Clutter-ClickGesture.new`. `get_sprite` is `Clutter-Backend.get_sprite`, and `Backend.rpc_register()` is still not called. It is not what the passing panel run needed. |
| Idle-sync of `ClickGesture.enabled` → `set_enabled` restores the panel swipe without the smoke calling `set_enabled` | **PROVEN**; **applied** (`/tmp/cube-after-panel-fix.log`) |
| A setter that calls `set_enabled` immediately nests inside `Clutter-ClickGesture.new` and drops the connection | **PROVEN** (`/tmp/cube-click-debug.log` id=206 then id=207 `disconnect abort`). A second `construct {}` does not compile (`class already contains a constructor`). |
| Overview tracker stays off because `_leavingOverview` stays true | **PROVEN** (`leaving=true trackerEnabled=false`, `began=1 updated=0 ended=14`) |
| `WorkspacesDisplay.vfunc_hide()` clears the flag and the overview swipe then updates | **PROVEN** off product code (`/tmp/cube-vfunc-hide.log`) |
| `Actor.hide()` or `vfunc_unmap` is the call that should run that vfunc | **UNPROVEN**. `hide()` does not call `hide_vfunc`. `signal:Actor.hide` is denied. A counter on `hide` / `vfunc_unmap` died at `Signals.vala:255` (`Client: disconnected`) before it logged. |
| DING maximized covers `_backgroundGroup` at `y=400` | **PROVEN**. DING disabled: `desktop began=1 updated=14 ended=1` in `/tmp/cube-ov-clear.log`. |
| Panel LEAVE at `x=680` is the product bug | **DISPROVEN**. That was the clock (`centerBox` 569..712). Empty span 1200→730 stays on the panel. |
| `ThemeContext.get_for_stage` null is the desktop root cause | **DISPROVEN** as a missing method. It was logged while the client was already disconnecting. The DING-off drag later completed. |

## Applied

`src/client/libmutter-clutter-rpc-18/overrides/ClickGesture.override.vala` — `enabled` stores the value and `Idle.add` calls `ActorMeta.set_enabled` once `rpc_lid != 0`. Rebuilt on the VM (`Clutter-18.typelib`, 2026-11-16 08:41). The smoke does not call `set_enabled`.

Post-change (`/tmp/cube-after-panel-fix.log`):

```text
panel began=1 updated=14 ended=1 ws=1 cgEnabled=false cgGetEnabled=false
ov-before-show leaving=true mapped=false
ov-state vis=true mode=2 ctrl=1 leaving=true trackerEnabled=false
overview began=1 updated=0 ended=14 ws=0
desktop began=0 updated=0 ended=0 ws=0
miss Error: miss overview-swipe
```

`get_sprite -32602` did not recur on that run. The gesture was disabled before the press.

## Still open

Overview. `vendor/gnome-shell/js/ui/workspacesView.js` `prepareToLeaveOverview` sets `_leavingOverview` and disables the tracker. The only clear is `vfunc_hide`. Startup (DING `activateWindow` → `overview.hide`) sets the flag before the smoke's `overview.show()`, and show does not clear it. `_updateTouchpadGesture` then `_interrupt`s, so `begin` fires and `update` does not.

Do not patch `Actor.hide()` until a run shows that `hide()` or `ControlsManager.vfunc_unmap` is actually invoked for this actor. The off-code pass calls `vfunc_hide()` itself (`/tmp/cube-vfunc-hide.log`: `ov-after-vfunc-hide leaving=false`, `overview began=1 updated=13 ended=1 ws=2`).

Desktop. Smoke drag `240→800` at `y=400` hits DING. Not a missing RPC once DING is out of the pick.

## LLM efforts

- 2026-11-13 10:45. Headless `cube-swipe` on VM: overview swipe OK (`began=1 updated=13 ended=1 ws=3`); desktop/panel `began=0`. Panel MOTION `state=0` via LayoutHooks; bg path reached ACTIVE then lost events + `get_sprite -32602` + X11 actor abort. Gate `captured-event-motion-state-*` written. Proposals lived in the DING bug file.
- 2026-11-14. Applied LayoutHooks/Actor state packing with DING fixes. Post-apply VM smoke `desktop-cube-swipe/ui/init`: panel `state=256` on PRESS → PENDING, then LEAVE at DateMenuButton cancels; overview/desktop `began=0`; `miss overview-swipe`. DING single-launch OK in the same log.
- 2026-11-14. User: close DING bug; split cube swipe into this file with enough context to continue. Audited `namespace.vala`: `Backend` / `ClickGesture` / `PanGesture` / `LongPressGesture` `rpc_register` still unwired. No further `src/` edit.
- 2026-11-14. User: archive old desktop cube / icons / DING bugs into `docs/bugs/done/`. This swipe bug stays open.
- 2026-11-15. VM headless, empty panel `1200→730` `y=10`, extension `.enabled=false` left as-is. `/tmp/cube-panel-first.log`: `ev panel type=6 state=256` then no MOTION; `panel began=0`; `cgEnabled=false cgGetEnabled=true`; `Clutter_generated.vala:3634` `-32602` (`Clutter-Backend.get_sprite`). Then Xwayland broken pipe during `overview.show`.
- 2026-11-15. Same drag after smoke `set_enabled(false)`, plus `_leavingOverview=false` and DING disabled. `/tmp/cube-ov-clear.log` (timeout 124 after `ok`): `panel began=1 updated=14 ended=1 ws=1 cgGetEnabled=false`; `ov-after-clear leaving=false trackerEnabled=true`; `overview began=1 updated=13 ended=1 ws=3`; `desktop began=1 updated=14 ended=1 ws=2`. Post-grab motion arrived. `stage.grab` RPC hypothesis dropped.
- 2026-11-15. Applied `ClickGesture.enabled` setter that called `set_enabled` when `rpc_lid != 0`. Startup died. `--debug` `/tmp/cube-click-debug.log` (deleted after, 75KB): `Clutter-ClickGesture.new` id=206 still in flight, nested `Clutter-ActorMeta.set_enabled` id=207, `Client.vala:519 disconnect abort`. Second `construct {}` failed valac: `class already contains a constructor`.
- 2026-11-15. Replaced that setter with `Idle.add` → `set_enabled`. Rebuilt `src/Clutter-18.typelib` on the VM. Smoke does not call `set_enabled`. `/tmp/cube-after-panel-fix.log`: `panel began=1 updated=14 ended=1 ws=1 cgGetEnabled=false`; `overview began=1 updated=0 ended=14` with `leaving=true trackerEnabled=false`; `desktop began=0`; `miss overview-swipe`.
- 2026-11-15. Smoke called `ovDisplay.vfunc_hide()` before `overview.show()`. `/tmp/cube-vfunc-hide.log`: `ov-after-vfunc-hide leaving=false`; `overview began=1 updated=13 ended=1 ws=2`; `desktop began=0`; `miss desktop-swipe`. Not copied into `Actor.hide()`.
- 2026-11-15. Monkeypatch counters on `hide` / `vfunc_unmap` (`/tmp/cube-hide-counts.log`) disconnected at `Signals.vala:255` during the overview drag, before the counts were logged. Counters removed from the smoke.
- 2026-11-15. `--debug` once grew `/tmp/cube-debug.log` to 2.9G (runaway smoke). Deleted. VM `/` is still ~100% full (348M). Do not leave a `--debug` run up.
- 2026-11-16. User: session boots, desktop-icon double-click works, overview and panel menus do not. Installed client is `/usr/bin/gsr-client` mtime 09:06; login 09:07 ran that binary (`journalctl` `gsr-client[236884]`). Generated C had `g_param_spec_boolean("enabled", ..., FALSE, G_PARAM_CONSTRUCT)`. Removed `construct` from the property. Rebuild param spec is `G_PARAM_READABLE | G_PARAM_WRITABLE` only. `/tmp/cube-activities.log`: `activitiesGetEnabled=true`, `activities-click vis=true`. Panel window-drag is still `cgEnabled=false cgGetEnabled=true` (`panel began=0`); the extension write is not reaching `set_enabled` once the property is not construct. `/usr` was not reinstalled.
- 2026-11-16 09:57. User reinstalled (`/usr/bin/gsr-client` mtime 09:56:49) and logged in (`gsr-client` 271923). Session still does not spin the cube. Journal: `_depthSortCubeFaces` `parent is null` at 09:57:07 and 09:57:38, from `WorkspacesView._updateWorkspacesState` during `animateToOverview`. Also `iconGrid.js` `layout_manager is null`. Headless `/tmp/cube-parent.log` repeats the parent-null stack on `overview.show()`. `/tmp/cube-depth.log`: the first four sorts have `parent=WorkspacesView` (`n=3` then `n=4`); `get_parent()` after show is non-null. The throwing call is a later one.
