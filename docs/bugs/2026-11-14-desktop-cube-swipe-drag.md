# Desktop Cube horizontal swipe does not rotate workspaces

**Status:** Open. Split from [`docs/bugs/done/2026-11-10-ding-gjs-window-and-cube-swipe.md`](done/2026-11-10-ding-gjs-window-and-cube-swipe.md) after DING was fixed. `event.get_state()` packing for GJS `LayoutHooks` actors is already in `src/` and proven necessary but **not sufficient**. Mutter 18 gesture / `Backend.get_sprite` peers exist on disk and are **not** wired from `rpc_register()`. Authoritative reproduce is the Ubuntu 26.04 VM (`alan@192.168.122.115`, Shell 50 / mutter 18), not Weston (mutter 16).

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

### Still open — missing mutter-18 `rpc_register` wiring

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
| LayoutHooks omit `event.get_state()` → panel MOTION cancels on BUTTON1 | **PROVEN** (VM + gate); **fixed in tree** |
| Packing restores non-zero state on LayoutHooks path | **PROVEN** (panel `state=256`) |
| Packing alone makes cube swipe / swipeTracker begin | **DISPROVEN** (post-apply all `began=0`) |
| `_backgroundGroup` via EventOverride already had state and could reach ACTIVE+grab | **PROVEN** (pre-apply) |
| After ACTIVE, events stop + `get_sprite -32602` | **OBSERVED** pre-apply; register wiring still missing |
| Missing `Backend`/`Click`/`Pan`/`LongPress` `rpc_register` → `-32602` | **Strong code audit**; not re-logged post-apply |
| DING maximized covers `_backgroundGroup` @ `y=400` | **PROVEN** |
| Panel LEAVE @ `x=680` from DateMenuButton cancels PENDING | **PROVEN** for that smoke geometry |
| Empty-panel drag + Backend register → panel cube swipe works | **UNPROVEN** (next) |
| Overview `began=0` is a real regression vs 2026-11-13 | **UNCLEAR** (DING/timing/`event_actor`) |
| Post-grab motion needs a `Stage.grab` / Grab lease path | **UNPROVEN** |

## Next steps (for the carrying session)

Follow [`docs/debugging.md`](../debugging.md). Do not land unproven `src/` edits.

1. **Prove missing register:** on the VM with current tree, trigger panel press and confirm `Clutter-Backend.get_sprite` still returns `-32602` (or write a tiny gate that calls it). Then propose wiring the four `rpc_register` calls in `namespace.vala` (trivial once proven — peers already exist).
2. **Retarget smoke panel drag** to an empty panel region (e.g. start `x≈300` left of the clock, drag left to `≈150` at `y=10`). Require instrumented `grab=true` / `ACTIVE` and `panel began≥1`. Keep overview/desktop asserts or soften until panel path is green.
3. **Optional DING-off run** to isolate `_backgroundGroup` path A after X11 alias fix (should no longer abort).
4. If ACTIVE but swipeTracker still silent: gate/prove post-`stage.grab` `event` delivery before inventing Stage grab RPC.
5. Re-check overview after panel path works; if still `began=0`, treat as a separate overview tracker defect (possibly tied to app-grid / `PanGesture` neighborhood).

## Code proposal (candidate only — not proven as sufficient)

### 1. `src/server/libmutter-clutter-18/namespace.vala` — call the existing 18 peers from `rpc_register()`

**Why:** Peers are compiled and their headers claim startup registration; only `PressGesture` is actually called. Client `Backend.get_sprite` and shell/extension gesture constructors need the live classes.

**Where:** `Gsr.Server.Clutter.rpc_register()`, immediately around the existing `PressGesture.rpc_register(clutter)`.

**Depends on:** prove `-32602` (or equivalent) on current tree first.

#### Keep
```vala
		var clutter = Clutter.rpc_register();
		PressGesture.rpc_register(clutter);
```

#### Add
```vala
		Backend.rpc_register();
		ClickGesture.rpc_register(clutter);
		PanGesture.rpc_register(clutter);
		LongPressGesture.rpc_register(clutter);
```

Do **not** apply until step 1 of Next steps has a FAIL-backed prove and a post-wire PASS on the same command. Smoke geometry changes stay in `tests/gjs-embed/desktop-cube-swipe/ui/init.js`, not in product code.

## LLM efforts

- 2026-11-13 10:45. Headless `cube-swipe` on VM: overview swipe OK (`began=1 updated=13 ended=1 ws=3`); desktop/panel `began=0`. Panel MOTION `state=0` via LayoutHooks; bg path reached ACTIVE then lost events + `get_sprite -32602` + X11 actor abort. Gate `captured-event-motion-state-*` written. Proposals lived in the DING bug file.
- 2026-11-14. Applied LayoutHooks/Actor state packing with DING fixes. Post-apply VM smoke `desktop-cube-swipe/ui/init`: panel `state=256` on PRESS → PENDING, then LEAVE at DateMenuButton cancels; overview/desktop `began=0`; `miss overview-swipe`. DING single-launch OK in the same log.
- 2026-11-14. User: close DING bug; split cube swipe into this file with enough context to continue. Audited `namespace.vala`: `Backend` / `ClickGesture` / `PanGesture` / `LongPressGesture` `rpc_register` still unwired. No further `src/` edit.
- 2026-11-14. User: archive old desktop cube / icons / DING bugs into `docs/bugs/done/`. This swipe bug stays open.
