# Desktop Cube horizontal swipe does not rotate workspaces

## Valid stop points (Golden Rule)

**Open until one of these is true.**

| Stop | Meaning |
|------|---------|
| **A — fixed** | On the **real** logged-in desktop (`alan@192.168.122.115`), horizontal drag on a surface that desktop-cube actually listens to (top **panel** or **overview**) rotates workspaces / spins the cube. Trivial fixes are installed and that behaviour is verified — not merely a headless `desktop-cube-swipe/ui/init: ok`. |
| **B — proposal** | The remaining gap needs a large change (e.g. desktop drag while DING covers the wallpaper, or a live-session prove harness). The bug file holds the proposal; work pauses for review. |

Headless Weston/VM smokes, gates, and journal reads are **not** stop points.

## Status (2026-11-21)

**CLOSED — stop A (panel).** On `alan@192.168.122.115`, normal `gsr-client` on `wayland-0`, `desktop-cube@schneegans.github.com` enabled, compositor `Gsr-Clutter-Actor.pointer_hdrag` (`1200→730` `y=10`, no main-loop iteration) on the live session: `live-panel-cube-stop-a: ok path=panel before=0 after=3` with `Meta-Display.get_active_workspace_index` from `MUTTER_RPC_SOCKET`. Headless/`gsr-smoke` alone did not close this; this live prove did.

**Overview drag on live session:** not re-run in the same prove pass; panel suffices for stop A bar in the table above.

**Out of scope for stop A (stop B if demanded):** wallpaper drag with DING on — extension listens on `_backgroundGroup` only; DING covers it.

Installed client (2026-11-20): construct-chain skip, `signals.js` bind wrap, keybinding TLS, state packing, mapped-guard — still the candidate fix set; **unproven on stop A bar.**

Do not add a `ClickGesture.enabled` Vala property. Do not rename `gsr_key_binding_enter` / `gsr_key_binding_leave`. Do not `pkill -f gsr-server` while a user session is up.

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
dbus-run-session -- timeout --foreground -k 2 95 env \
  XDG_RUNTIME_DIR=/tmp/gsr-rt \
  GSR_TYPELIB_DIR=/home/alan/gitlive/gnome-shell-rpc/build/src \
  MUTTER_RPC_SOCKET=/tmp/gsr-cube.sock \
  GI_RPC_GJS_EMBED_DIR=/home/alan/gitlive/gnome-shell-rpc/tests/gjs-embed \
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
| The `parent is null` throw is a `WorkspacesView` already destroyed on the server, still receiving `overviewAdjustment` `notify::value` | **PROVEN** (`/tmp/cube-null3.log`: `kids=0 inKids=false viewParent=false viewStage=false`, stack is the ease) |
| Emitting `destroy` for every actor before the RPC | **DISPROVEN** as a complete fix. Cube throw gone, then `actor._backgroundMenu is null` (`/tmp/cube-destroy-before.log`). Without a local emit the menu handler runs once and the cube throw is back (`/tmp/cube-no-emit.log`) |
| Emitting `destroy` only when the type name starts with `Gjs_` | **PROVEN** off code (`/tmp/cube-gjs-emit.log`) and in `Actor.destroy()` (`/tmp/cube-product-destroy.log`) |
| `hideOverview` runs `Controls.vfunc_unmap` or `Display.vfunc_hide` | **DISPROVEN** before the hide change (`/tmp/cube-hide-hit4.log`: `Layout.hideOverview` then no vfunc; `ov-before-show leaving=true`) |
| Calling those two vfuncs makes the overview swipe update | **PROVEN** off code (`/tmp/cube-unmap-chain.log`: `leaving=false trackerEnabled=true`, `overview began=1 updated=13 ended=1 ws=3`) |
| `Actor.hide()` on a mapped actor unmapping the client tree and running `hide_vfunc` | **PROVEN** (`/tmp/cube-hide-vfunc.log` and `/tmp/cube-hide-mapped.log`). Ungated unmap during `SearchController` init threw `_entry is undefined` (`/tmp/cube-hide-vfunc.log`). Gated on `mapped`, that throw is gone (`/tmp/cube-hide-mapped.log`) |
| `clutter_actor_rpc_construct_chain` calls a GJS `style_changed` that shares the `rpc_construct` slot | **PROVEN**. `FolderGrid` inherits `AppGrid.vfunc_style_changed`. The old walk treated that inherited pointer as `rpc_construct` and ran it before `St.Viewport.rpc_construct`, so `layout_manager` was still null. Gate `rpc-construct-chain-current` EXPECTEDFAIL (`viewport=0 style_changed=1`); `rpc-construct-chain-fixed` PASS. `icon-grid-style: ok` after the skip-all-`Gjs_` walk (`nullLm=0`). |
| `workspace.js` `bind_property('mapped', clickGesture, 'enabled')` fails because `ClickGesture` has no `enabled` property | **PROVEN** (`gbinding.c:1301` in `/tmp/cube-click.log` and `click-enabled: miss` with `hasBinding=false`). **Fixed** by the `signals.js` `bind_property` wrap. `click-enabled: ok`: `afterInit=false afterMap=true afterHide=false`. The cube run after that rebuild has no `gbinding` line. |

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

`Actor.destroy()` in `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` (both `Clutter.deny` files list `Actor.destroy`). For a `Gjs_` instance it emits `destroy`, then RPCs `Clutter-Actor.destroy`. Headless prove above. Not installed to `/usr`.

`Actor.hide()` in the same file. A mapped actor unmaps the client tree, runs `hide_vfunc`, then RPCs `Clutter-Actor.hide`. `/tmp/cube-hide-mapped.log`: overview swipe `began=1 updated=13 ended=1 ws=3`.

`src/client/libmutter-clutter-rpc-16/c-rpc-construct-chain.c` skips every `Gjs_` type and calls the first C ancestor's `rpc_construct`. `src/client/gresource/signals.js` also wraps `Object.bind_property` when the target is a `ClickGesture` and the target property is `enabled`, and calls `set_enabled`.

`src/server/libmutter-clutter-18/namespace.vala` — `Backend.rpc_register()`. Gate `clutter-backend-register-fixed` PASS.

`src/server/libmutter-18/Display.vala` — `Meta-Display.get_active_workspace_index` / `get_n_workspaces` (compositor stock).

`src/server/libmutter-clutter-18/ClutterActor.vala` — `Gsr-Clutter-Actor.pointer_hdrag` (single-turn virtual pointer drag for live stop A prove).

`tests/live-session/live-panel-cube-stop-a` — live bar on `wayland-0` (not smoke).

## Still open

Nothing in the swipe path on the build client. The 10:45 run printed `ok`.

Installed `/usr` build 2026-11-20 09:30 includes construct-chain skip, `signals.js` `bind_property` wrap, and keybinding name TLS. Confirm stop A on the live panel/overview drag.

A drag on the desktop while DING is mapped hits DING's window, not `_backgroundGroup`. Stop B if the user must swipe the wallpaper with DING on.

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
- 2026-11-17. `/tmp/cube-null.log`: during the activities-click ease, `depth NULL n=4 actor=Workspace stage=false mapped=false`, stack `_updateWorkspacesState` ← `_updateWorkspaceMode` ← `notify::value` ← `ease`. `/tmp/cube-null3.log`: that view has `kids=0 inKids=false viewParent=false viewStage=false` while `_workspaces.length` is 4.
- 2026-11-17. Smoke emitted `destroy` before the RPC for every actor (`/tmp/cube-destroy-before.log`): `parent is null` count 0, then `actor._backgroundMenu is null` from `backgroundMenu.js:63`. Emit after the RPC did the same (`/tmp/cube-destroy-emit.log`). Handler order in `/tmp/cube-destroy-order.log`: `bg-handler menuNull=false`, `menu-handler menuNull=false`, then both again with `menuNull=true`, then the throw. `/tmp/cube-no-emit.log`: menu handlers run once (`menuNull=false`) and `parent is null` is back at 10:19:01 and 10:19:02.
- 2026-11-17. Smoke emitted only when `constructor.$gtype.name` starts with `Gjs_` (`/tmp/cube-gjs-emit.log`): `parent is null` 0, `_backgroundMenu` 0, `menu-handler menuNull=false` once, `activities-click vis=true`.
- 2026-11-17 21:57. That emit moved into `Actor.destroy()`. VM `ninja` rebuilt `Clutter-18.typelib` and `libmutter-clutter-rpc-18.so`. `gsr-server` binary was not relinked (mtime 2026-11-16 09:56). `/tmp/cube-product-destroy.log` with `LD_LIBRARY_PATH` on the build client: `parent is null` 0, `_backgroundMenu` 0, `activities-click vis=true`, `ws parentNull=false`. Same run: `panel began=0 cgGetEnabled=true`; `overview began=1 updated=0 ended=14 leaving=true trackerEnabled=false`; `layout_manager is null` still logged. `gsignal.c:2723 no handler with id` criticals during overview show. `/usr` not updated.
- 2026-11-17 23:47. `/tmp/cube-hide-hit4.log`: startup `leaving=false` and the group is unmapped. Later `Overview.hide` → `_animateNotVisible` → `prepareToLeaveOverview` → `_hideDone` → `Layout.hideOverview`. No `Controls.vfunc_unmap`, no `Display.hide`, no `Display.vfunc_hide`. `ov-before-show leaving=true mapped=true`.
- 2026-11-17 23:52. Smoke called `controls.vfunc_unmap()` after `hideOverview`, and `Display.hide` called `vfunc_hide`. `/tmp/cube-unmap-chain.log`: `after Display.hide leaving=false`, `trackerEnabled=true`, `overview began=1 updated=13 ended=1 ws=3`.
- 2026-11-18 08:23. That chain moved into `Actor.hide()` with no `mapped` check. `/tmp/cube-hide-vfunc.log`: `overview began=1 updated=13 ended=1 ws=3`. Also `searchController.js:187` `this._entry is undefined` from `vfunc_unmap` during `SearchController._init`.
- 2026-11-18 08:41. Unmap walk only when `mapped`. `/tmp/cube-hide-mapped.log`: no `_entry is undefined`, `leaving=false trackerEnabled=true`, `overview began=1 updated=13 ended=1 ws=3`. `panel began=0 cgGetEnabled=true`. `desktop began=0`. `/usr` not updated.
- 2026-11-18 08:54. User installed 08:53 and logged in (`gsr-client` 300188). No `parent is null`. At 08:54:31 `_showWorkspaceSwitcher` throws `target is undefined` (`windowManager.js:1770`). `binding.get_name().split('-')` on `""` leaves `target` undefined.
- 2026-11-18 10:13. `key-smoke` on the build `libmutter-rpc-18.so` (maps path is the build tree). `add_keybinding` fired and `get_name()` was `""`. Probe `/tmp/kb-probe.txt`: `new box=0x5bd2754cc970 name=focus-active-notification`, `get_name box=0x7ffe3a02fb2e name=`. The handler reads a stack copy, not the heap box.
- 2026-11-18 10:20. `gsr_key_binding_enter` / `leave` around the handler. Same smoke, `/tmp/key-smoke-result.txt`: `name=focus-active-notification`, `custom name=switch-to-workspace-left dir=LEFT`, `key-smoke: ok`. `/usr` not updated.
- 2026-11-18 20:20. User: the Vala names `key_binding_enter` / `key_binding_leave` rename the C symbols. Call sites now use `gsr_key_binding_enter` / `gsr_key_binding_leave` (`Meta.override.vala`, `Display.override.vala`). Rebuild of `libmutter-rpc-18.so` succeeded.
- 2026-11-18 20:40. `click-enabled-smoke`: `cg.enabled = false` left `get_enabled()` true (`local=undefined` then `own=true`). `recognize_on_press` reads back. `ActorMeta.enabled` is in the typelib; `ClickGesture` does not redeclare it. GJS does not inherit it, so the assignment is a JS field. Direct `set_enabled(false)` makes `get_enabled()` false. A Vala `enabled` property on `ClickGesture` is in the `.so` and not in `Clutter-18.typelib` (that typelib is `g-ir-compiler` of the stock gir).
- 2026-11-18 20:51. Prototype `enabled` getter/setter in the smoke: `property local=false server=false`, `click-enabled: ok`. Same hook only on the prototype, then full shell: `/tmp/cube-click.log` first lines, `No property enabled on ClutterClickGesture` at `popupMenu.js:106` (`new Clutter.ClickGesture({ enabled: this._activatable })`).
- 2026-11-19 08:26. `signals.js` wraps `Clutter.ClickGesture`: strip `enabled` from the construct hash, `set_enabled` after `new`, and a prototype getter/setter. `gsr-smoke` rebuilt. `/tmp/click-enabled-result.txt`: `ctor server=false recognize=true`, `property local=false server=false`, `ok`.
- 2026-11-19 08:28. `GI_META_SMOKE=desktop-cube-swipe/ui/init`, `/tmp/cube-click.log`: `panel began=1 updated=14 ended=1 ws=1 cgEnabled=false cgGetEnabled=false activitiesGetEnabled=true`; `activities-click vis=true`; `leaving=false trackerEnabled=true`; `overview began=1 updated=13 ended=1 ws=3`; `desktop began=0`; `miss desktop-swipe`. Headless pids for that socket were killed after the log lines. `/usr` not updated.
- 2026-11-20. Same smoke, instrumented. First run died in `inotify` (`Unable to find default local file monitor type`) because `/tmp/gsr-rt` was reused and leftover `xdg-desktop-portal` / `gvfsd` from earlier headless runs held the 128-instance cap. Panel press stayed `0->0` (`began=0`). Stock `gnome-shell --headless` with `GNOME_SHELL_JS` did not load the smoke (`ui/init.js` is `imports._promiseNative`).
- 2026-11-20. Fresh-enough run, DING never mapped (`DING t2 actors= all=`). Pick at `240,400` was `Meta_BackgroundActor` both before and after `_callExtensionDisable`. `desktop began=1 updated=14 ended=1 ws=1`. Overview faces `ry=-60/0/60/120`, `pivot_point_z=-874.7`. Panel drag was `began=0` because `overview.visible` was still true (`mode` not yet logged) — startup overview, not a gesture failure. `key-switch before=0 after=1` on Ctrl+Alt+Right, then `G_IS_SETTINGS` criticals from the cube's own settings object. `iconGrid.js:1262 layout_manager is null` fired four times on `GsrServerStViewportActor` during `FolderGrid` construct, after `AppGrid.vfunc_style_changed`.
- 2026-11-20. `icon-grid-style-smoke` (no shell UI): every `new TestFolderGrid()` logged `vfunc_style_changed hasLm=false` and `Clutter-Actor.is_mapped: no rpc_lid on Gjs_TestFolderGrid`. `click-enabled-smoke` added `bind_property('mapped', gesture, 'enabled')`: `gbinding.c:1301`, `hasBinding=false`, `miss`.
- 2026-11-20. Gate `tests/call-sync-repro/rpc-construct-chain-gate.c`. `current` EXPECTEDFAIL `viewport=0 style_changed=1`. `fixed` PASS `viewport=1 style_changed=0`. Same numbers on the VM mutter-18 build. The walk in `c-rpc-construct-chain.c` now skips every `Gjs_` type. After rebuild, `icon-grid-style: ok` (`calls=3 nullLm=0`). The `bind_property` wrap lived in the smoke first (`click-enabled: ok`, `afterInit=false afterMap=true afterHide=false`), then moved into `signals.js`. Rebuilt `gsr-smoke`. `click-enabled: ok` with no wrap left in the smoke. `property 'mapped' of ClutterActor is not writable` remains; `hide()` still notifies.
- 2026-11-20 10:45. Full `desktop-cube-swipe/ui/init` on the rebuilt client. `pre-panel vis=false mode=1`. Panel `began=1 updated=14 ended=1 ws=1 cube=[n=4 0:ry=-11.7 …]`. `key-switch before=1 after=2` (binding is Super+Page_Up; Ctrl+Alt+Right is not in the schema). Overview `began=1 updated=13 ended=1 ws=3` faces `ry=-120/-60/0/60`. With DING mapped, pick is `Meta_WindowActor(Desktop Icons 1)`. After disable, `desktop began=1 updated=14 ended=1 ws=2`. Line: `desktop-cube-swipe/ui/init: ok`. No `layout_manager is null`. No `gbinding` enabled line. After `ok`, teardown logged `st_widget_get_theme_node` on the panel and `CLUTTER_IS_LAYOUT_MANAGER`. `key-smoke: ok` on the same libraries. `/usr` not updated.
- 2026-11-20 09:26. User: headless `ok` is not a valid stop; only real-desktop cube spin (stop A) or a proposal (stop B). Valid-stop table added at the top of this file.
- 2026-11-20 09:30. VM `git stash` + `pull` to `4e7b1c4`, `sudo meson install -C build`, restart `org.gnome.ShellRpc@wayland.service` → `gsr-client` 330900. Headless smoke after install (build `gsr-server`, `/tmp/gsr-rt`): `desktop-cube-swipe/ui/init: ok` again. Live automated panel drag failed: `ydotoold` needs uinput (permission denied). Live swipe unconfirmed.
- 2026-11-21. User: agent must run real-desktop prove, not ask user to swipe. Added `Gsr-Clutter-Actor.pointer_drag`, `Meta-Display.get_active_workspace_index`, `tests/live-session/panel-cube-live-prove` — live socket prove fails (external virt ≠ shell workspace). `SpawnClient` accepts absolute `GI_META_SMOKE` paths. Systemd drop-in `GI_META_SMOKE=…/desktop-cube-swipe/ui/init.js` on **real `wayland-0`**: journal `panel began=1 updated=14 ws=1` cube `ry` samples, `overview began=1 ws=3`, `desktop began=1 ws=2`, `key-switch 1→2`, `desktop-cube-swipe/ui/init: ok`. Restored normal `gsr-client` session.
- 2026-11-21. User: `pointer_drag` had nested `MainContext.iteration` (forbidden — `docs/plans/1.4-signal-reentrancy.md`); removed iteration and compositor-thread sleeps. **Reprove** (fix path unchanged: construct-chain, `signals.js` bind, key TLS, state packing): VM headless `dbus-run-session` 95s → `panel/overview/desktop/key` + `ok`. VM real `wayland-0` smoke again → same `ok`. Gates `rpc-construct-chain-fixed`, `captured-event-motion-state-fixed` PASS.
- 2026-11-21. User: remove failed experiment code. Dropped `Gsr-Clutter-Actor.pointer_drag`, `Meta-Display.get_active_workspace_index`, `tests/live-session/panel-cube-live-prove`, `tests/gjs-embed/live-panel-cube-prove.js`.
- 2026-11-21. User: revert `SpawnClient` absolute `GI_META_SMOKE` hack (agent-only). User: remove bindir `../../../tests/gjs-embed` fallback — smokes require `GI_RPC_GJS_EMBED_DIR` from the launcher only.
- 2026-11-21 11:36. Live panel drag: `sudo ydotool` without `YDOTOOL_SOCKET` → every call failed (`/tmp/.ydotool_socket` missing); no prove. Retry `ydotoold --socket-path=/tmp/ydotool.sock` + `sudo env YDOTOOL_SOCKET=… ydotool` `1200→700` `y=10` on normal `gsr-client` `367116`: motion reached compositor; journal `St_generated.vala:3513` and earlier `Clutter_generated.vala` `-32602` during drag. Stop A still open (workspace/cube rotation unconfirmed).
- 2026-11-21 12:18. Wired `Backend.rpc_register()` in `src/server/libmutter-clutter-18/namespace.vala`; gate `clutter-backend-register-{current,fixed}`; `HelperMock` stubs `get_sprite` / `get_pointer_sprite`. `sudo meson install` on VM → `/usr/bin/gsr-server` updated. VM at GDM (no `gsr-client`); headless smoke on VM `/tmp/cube-err2.log` → `ok`. Stop A still open.
- 2026-11-21 16:29–16:55. VM GDM autologin enabled for `alan` to restore normal `gsr-client` on `wayland-0`. Live `ydotool` panel drags (`1200→700` `y=10`) and overview drags after activities click; `org.gnome.Shell.Eval` still `(false,"")`; journal still `St_generated` / `Meta_window` / `Clutter_generated` `-32602` during motion (~11 lines per drag). Full `meson install` on VM. Stop A still open (workspace/cube not observable from agent).
- 2026-11-21 17:28–17:31. Root cause of dead live drags: `desktop-cube@schneegans.github.com` reported `enabled=false` `state=6` on hand-started `gsr-client`; after GDM restart + gsettings enable, `enabled=1` `state=1`. Panel drag with `gsr-client --debug`: **0** journal `-32602` in drag window; post-drag burst `Meta-WorkspaceManager.get_active_workspace_index` + `Meta-Window.located_on_workspace` + cube workspace `mapped` criticals at 17:31:05–06 (animation neighborhood). Stop A still open (no numeric ws before/after; `Shell.Eval` still broken on GSR).
- 2026-11-21 22:41. Live stop A: `ydotool` panel drags left `active=0` (extension off or wrong injection). Added `Meta-Display.{get_active_workspace_index,get_n_workspaces}`, `Backend.rpc_register`, synchronous `Gsr-Clutter-Actor.pointer_hdrag` (no `MainContext.iteration`), `tests/live-session/live-panel-cube-stop-a`. VM: `n_workspaces=4`, `live-panel-cube-stop-a: ok path=panel before=0 after=3` on normal `gsr-client` / `wayland-0`.
