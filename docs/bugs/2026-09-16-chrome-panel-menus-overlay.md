# Panel / menus / grey overlay — current chrome bar

> # ⚠️⚠️⚠️ AGENTS — READ THIS FIRST ⚠️⚠️⚠️
>
> ## DO NOT STOP for “status theatre”
>
> **Keep working.** Do not pause to narrate progress, summarize what you tried,
> or ask whether to continue after every prove / dead end / rebuild. Carry on
> until the bar moves or you hit one of the stop conditions below.
>
> ## When you MAY stop
>
> 1. **You actually need the user’s help** — a decision only they can make,
>    credentials, a machine/session you cannot reach, or explicit approval the
>    plan forbids you from assuming. Say what you need in one short ask, then
>    wait.
> 2. **OPC / libocrpc is the problem** — and only then: write a **FAIL-backed**
>    gate under `tests/call-sync-repro/` that **FAIL**s, file the **bug in
>    OLLMchat** (`docs/bugs/`), **do not edit OLLMchat code from this tree**,
>    and **stop**. Do **not** file OPC bugs under this repo’s `docs/bugs/`.
>    PASS gates → chase the **consumer**; do not stop to “report” a theory.
>
> ## Everything else
>
> File/update **this** bug, pick the next allowed prove step, rebuild, prove,
> repeat. **Prove-first** in the **test area** (`src/gjs-embed/`, observe
> probe) — **no** speculative stub / Helper / deny / JS thrash on the main
> tree. **No** `GLib.idle_add` / Idle / defer. No layout.js ship hacks.
>
> ## 🚫 Do not invent shit in this tree
>
> **User call 2026-09-16:** a stack frame / Class-offset theory / “same as
> Transition” pattern is **not** a license to dump Helper methods, local
> GValue caches, deny lists, or ABI “fixes” into `src/`. That is wasting
> everyone’s time and polluting the codebase.
>
> Required order — **no exceptions** for Boot death:
>
> 1. Reproduce on stay-up (client 139 / stack). File the frame here.
> 2. Write a **FAIL** smoke in `src/gjs-embed/` that dies (or asserts) on
>    **that** frame — not a smoke that already PASSes while chrome dies.
> 3. Only then a **minimal** change that makes **that** smoke PASS.
> 4. Re-run stay-up. If chrome still dies on a **new** frame, update this
>    bug and go to (2). Do **not** invent the next subsystem in the same
>    turn.
>
> **Forbidden:** Helper `set_relay_*` / kind switches / local caches /
> “while we’re here” deny expansions / renaming half the tree to match a
> theory — before a FAIL smoke names the fix. Revert speculative dumps;
> do not leave them “for later.”
>
> **User call 2026-09-16:** banner on **this bug only** (plus the active
> plan) — do not re-splat onto other bugs/docs. Prove without modifying
> the main codebase until the smoke names the fix.

**Status:** ⏳ open — **primary** chrome bar (panel, menus, grey overlay). Allocate Flow 2/3 archived.  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Allocate (done):** [`done/2026-09-16-allocate-follow-reference.md`](done/2026-09-16-allocate-follow-reference.md)

**Roles:** consumer of the stock allocate program · **not** a new layout.

---

## Boot death (CLOSED for stay-up — 2026-09-16 22:36)

**Bar met:** nest reached `READY=1` and stayed until prove **timeout**
(30s and 45s). No client **139** / mutter **ec=133** on those runs.

| Run | Result |
| --- | --- |
| Stay-up 30s (`GSR_NESTED_STAYUP=1`) | `stop (timeout) after 30s` — no SEGV |
| Stay-up 45s | `READY=1` → `stop (timeout) after 45s` — no SEGV |

Earlier deaths (allocate trampoline → Interval peek) are no longer the
top of a stay-up crash. Do **not** reopen boot death without a new
139/133 prove.

### Historical proved (death A / B — for archaeology)

| Fact | Evidence |
| --- | --- |
| Death **A**: GJS ← **our** `clutter_actor_allocate+0x71` (virtual Class+464 vs GIR@240) | `/tmp/gsr-segfault.bt` |
| After non-virtual `allocate`: death **B** `clutter_interval_peek_initial_value+0x1ff` | `/tmp/gsr-segfault-deathA-recheck.txt` |
| Fix path that cleared stay-up red | non-virtual allocate + Interval peek ABI override (local mirror) + capital-`V` set_* (no `bsid`) |

### Not proved — do not treat as done

| Claim | Reality |
| --- | --- |
| Stay-up green = chrome fixed | **False.** Probe FAILs remain (below). |
| Kind casting / Shared fundamental switch | Dropped; `args("V")` + Gi. |
| `allocate-segv-smoke` names the chrome fix | Still useless for chrome layout. |

### Live chrome (OPEN — nest survives)

**User live (2026-09-16 ~23:06)** — nest up; score this over early probe:

| # | Surface | Observed | Stock |
| - | ------- | -------- | ----- |
| 1 | Workspace selectors (left) | ✔️ closed — centred + hpadding (`workspace-dot-align-smoke` **C**, `buttonbox-hpadding-smoke`) | Vertically centred; ~12px left pad |
| 2 | Boot / desktop | **Better (user 2026-09-17 ~16:37).** App-picker / WINDOW_PICKER now shows **wallpaper / app thumbnails**. Search **too high**. Desktop panes **too high** (same). Workspace-thumbnail row (tiny per-desktop squares) **still missing**. Grey square + red dot ~2/3 along. See **Panel inset**. | Search below panel → thumbs row → wallpaper pane |
| 3 | Clock (dateMenu) | Click-crash regression **2026-09-21** — see **Clock click crash** below. Nested `date-menu-open-smoke: ok`. Live click not re-scored. | Same |
| 4 | Clock menu | **Open/close ✔️.** Buttons inside dead (month nav, events, …) — backlog | Month nav + items work |
| 5 | System menu (quickSettings) | **Open/close ✔️.** Tiles / sliders / settings row dead — same backlog. Volume size later | Tiles click; sane size |
| 6 | Geom (probe) | `messageTray` still odd; BoxPointer dateMenu ~stage-wide preferred | Finite tray; menu ~content |

**Probe after settle (≥15s)** — aligns with user on open; click-close not asserted yet:

| After `delayed15s` (2026-09-16 22:58) | Meaning |
| --- | --- |
| `startingUp=false` · indicators `n=16` · panel-right / QS finite | setup finished |
| `dateMenu-click-open-ok` | matches user §3 open |
| `overview-shown-after-boot` · `state=1` | stock WINDOW_PICKER (was mis-scored as stuck chooser) |
| `FAIL quickSettings-click-no-open` | probe click path; user can open QS by hand |
| `FAIL dateMenu-boxpointer-stage-sized w=754` | wide popover (content sum) |
| ~~`this._workarea is null`~~ | ✔️ `set_container` → `set_container_vfunc` |
| ~~panel-left hpadding `_natHPadding=0`~~ | ✔️ Helper `style_changed` → client emit (`buttonbox-hpadding-smoke`) |

**Early probe lies** (empty QS / `startingUp=true` / panel-right `0x32`) — timing
only until `QuickSettings._setupIndicators` finishes. Score `delayed15s` +
user live, not early/later.

**Resumed (2026-09-17).** Menu **open/close** ✔️ (user live). **Backlog:**
no control inside any popdown works (user). Likely Compact Event coords
(`0,0` / `222,1`) so inside clicks look like click-out / miss the child.
QS `-12` later. Boot landing is stock WINDOW_PICKER but **content incomplete** (below). **🚫** ImageContent / vendor `js/`.

### Clock click crash (2026-09-21) — handoff

Came off the search ticket ([`2026-09-19-overview-app-search-empty.md`](2026-09-19-overview-app-search-empty.md)): a speculative “never shrink `actor_allocation`” on **every** actor crashed clicking the top-panel time. Search overlay is still open; do **not** put never-shrink back.

| Attempt | Result | Now |
| --- | --- | --- |
| Never-shrink cache on all `allocate` / `allocation` getters | Calendar / date menu died. User called out coding standards (`bool` flags, no braces) | **Reverted.** `allocate` always stores the box. Getter copies finite mutter width, else cache (skip `-Infinity` / empty) |
| `date-menu-open-smoke` + `menu.open(0)` | Named the next death: mutter **ec=133**, client `Unrecognized type alias: Shell-GLSLEffect` on `get_effect` during menu show | Keep the smoke |
| Host `ShellApplication` `try { Bin.register("Shell-GLSLEffect", typeof(Shell.GLSLEffect)) }` after `Runtime.register()` | Open no longer 133’d. User: “this looks unlikely” — wrong layer, swallowed errors, one-off | **Removed** |
| `GLSLEffect` `static construct { Bin.register(...) }` | User: not a valid way | **Removed** |
| `GLSLEffect.rpc_register()` from `Global.bind_display` | User: one place calls all of these, not random sites | **Removed** |
| Helper `Bin.register("Shell-GLSLEffect")` | Invented a Shell wire name on mutter. `get_effect` encoded the compositor OffscreenEffect as that alias | **Removed.** `register_alias("Clutter-OffscreenEffect", …)` |
| `Shell.register()` (`shell_register`) from `GiStub.Runtime.register()` to unpack `Shell-GLSLEffect` | User: Shell GLSLEffect is never on the server. It extends Clutter; alias the helper as `Clutter-OffscreenEffect`, `register_handle` the lease | **Removed.** See [`2026-09-21-shell-glsleffect-bin-alias.md`](2026-09-21-shell-glsleffect-bin-alias.md) |
| Smoke `fire_button_press` after `open()` | Toggles **closed** (`isOpen=false`); prove hung to timeout until click was dropped | Smoke is **open-only**. `SMOKE_OK_PAT` includes `date-menu-open-smoke: ok` |
| Nested prove **2026-09-21 ~15:35** | `date-menu-open-smoke: open dateMenu` then `ok`. No unpack 133. Early-stop once the pattern was listed | Gate PASSed. **Live click** (user) not re-scored this session |

```bash
GSR_NESTED_TIMEOUT=40 GI_META_SMOKE=date-menu-open-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
# expect: date-menu-open-smoke: ok  and  nested-weston-prove: stop (smoke-ok)
```

Do **not:** never-shrink globally · `Bin.register` in `ShellApplication` · `static construct` Bin.register · `rpc_register` from `bind_display` · treat nested `open(0)` as a live click score · Idle as a menu fix.

If the nest/session bus is dead (“too many connections”), that is leftover `dbus-run-session` daemons, not this chrome miss: `./scripts/clear-nested-dbus.sh` ([`weston-nested-test-env.md`](../weston-nested-test-env.md)).

### §2 diagnosis (2026-09-17 — debug only, no fix yet)

| Fact | Evidence |
| --- | --- |
| After settle | overview `SHOWN` but `_stateAdjustment.value=0` (want ~1 WINDOW_PICKER) |
| RPC | client `Clutter-Transition.set_to_value` + `args("V")` → reply **-32601** |
| Same miss | `clutter-interval-gvalue-gate` FAIL on `Clutter-Interval.set_final_value` (same empty WARNING) |
| `value-v-gate` | **PASS** — capital-V transport OK on Helper `"V"`; not a wire packing miss |
| **Root** | typelib `find_method("set_to_value")` / `find_method("set_final_value")` → **NULL**. GIR shadows collapse the name: listed method is **`set_to`** / **`set_final`**, symbol still `clutter_*_set_*_value`. Gi.dispatch looks up the wire method name → METHOD_NOT_FOUND. |
| Probe (host) | `/tmp/gi-find-method`: `find_method(set_to) → clutter_transition_set_to_value`; `find_method(set_to_value) → NULL`. Interval: `set_final` hits, `set_final_value` NULL. |
| **Fix (2026-09-17)** | Wire rename only: `Clutter-Transition.set_to` / `set_from`, `Clutter-Interval.set_initial` / `set_final`, still `args("V")`. No Helper relay. |
| Prove | nest `delayed15s`: `_shownState=SHOWN` · **`state=1`** (WINDOW_PICKER) · `showAppsChecked=false` · `Clutter-Transition.set_to` (no `-32601`). Was `state=0`. |

### Boot search / “app chooser” (2026-09-17)

**Why it shows:** not a miss. Nested session is stock **`user`**,
`hasOverview: true`. `LayoutManager._startupAnimationSession` then
`await Main.overview.runStartupAnimation()`:

1. `Overview.runStartupAnimation` sets `_shown` / `_visible` and
   `layoutManager.showOverview()`.
2. `ControlsManager.runStartupAnimation` eases `_stateAdjustment`
   **HIDDEN → WINDOW_PICKER** (`state=1`), `showAppsButton.checked=false`,
   and **drops `_searchEntryBin` from the top** (“Type to search”).
3. `SearchController` is constructed `visible: false`,
   `searchActive=false`. App grid is visible only when `state > WINDOW_PICKER`.

**Stock look (user, 2026-09-17)** — same stack on real nested Shell:

```bash
dbus-run-session -- gnome-shell --wayland --nested --sm-disable --mode=user
```

Top to bottom after boot:

1. **Search bar** (“Type to search”).
2. **Workspace row** — virtual-desktop thumbnails underneath the search bar.
3. **Current desktop** — wallpaper with window thumbnails of running apps.
   At startup that is usually **empty** (just the screen / wallpaper; no
   windows yet). Dash still sits at the bottom.

That is WINDOW_PICKER, not `SearchResultsView` and not the app grid
(`APP_GRID` / `showApps`). Esc hides to idle (user). Wallpaper-only
boot without this overview would be `overview.hide()` after startup — a
**product deviation** from stock `user` JS. **🚫** vendor `js/` hide,
Idle, layout.js.

**User live (2026-09-17 ~15:49):** landing is **~50%**. Search bar is
there. **Not** there: virtual-desktop thumbnail row
(`ThumbnailsBox`) and the current-desktop / background pane
(`WorkspacesDisplay` / `WorkspaceBackground`). Not a “hide after boot”
fix.

**User live (2026-09-17 ~16:37):** wallpaper / app thumbnails **now
show** on the picker. Remaining: search too high; desktop panes too
high (same); thumbs row still not there; grey square + red dot ~2/3
along. User: not taking the menu bar into account.

**User live (2026-09-18):** hang after settle **closed** (session stays
up). App search (text fills, icons empty) is **not this bug** —
[`2026-09-19-overview-app-search-empty.md`](2026-09-19-overview-app-search-empty.md).

### Panel inset (2026-09-17)

Stock (`vendor/gnome-shell/js/ui/`):

| Piece | Rule |
| ----- | ---- |
| `layout.js` | `panelBox` `addChrome({affectsStruts: true})` → `_updateRegions` → `Meta.Strut` TOP → `Workspace.set_builtin_struts` |
| `getWorkAreaForMonitor` | `ws.get_work_area_for_monitor` |
| `overviewControls.js` | `startY = work.y - mon.y`; search / thumbs / wallpaper origin at `startY` |

Probe `delayed15s` (15:51): `entryBin @ 215,0` — `startY=0` means workarea
equals the monitor (no panel strut). Same miss for wallpaper sitting too
high. Thumbs were mapped `305,62 190x30` then; if they still look absent
after inset, that is a separate paint miss. Grey/red-dot leftover open.

Gate **A** `workarea-panel-inset-smoke` — **PASS** `startY=32`.
Gate **B** `workarea-panel-chrome-smoke` (Weston): **A/B PASS**,
**FAIL C** `workareasHits=0` — mutter `Display::workareas-changed`
never reached GJS, so `ControlsManagerLayout._workAreaBox` stays at
construct `startY=0`. Fix: `ensure_signal_subscribe` + Runtime
Notification re-emit (same as `Transition::stopped`). **🚫** layout.js.
**🚫** mutter-rpc on the host DISPLAY.

**delayed15s 15:51:16** — actors exist, wallpaper child was 0×0:

| Actor | Geom |
| ----- | ---- |
| search entryBin | `215,0 370x55` |
| thumbs | `shouldShow=true` mapped `305,62 190x30` (`nWorkspaces=4`, static) |
| workspaces pane | mapped `0,97 800x395` · ws0 `121,97 557x395` |
| `WorkspaceBackground` preferred | `min=0 nat=0` — stock C allocate missing |

**Fix (2026-09-17):** owned `Shell.WorkspaceBackground.allocate_vfunc`
matches stock `shell-workspace-background.c` (first child + grandchild).
Gate: `GI_META_SMOKE=workspace-background-allocate-smoke` — was **FAIL**
`inner=0x0`, now **PASS** `inner=800x400`. Re-score the big pane live.
Thumbs at boot have **no** BackgroundManager (stock JS) — empty CSS
frames until windows exist; if the row still looks absent after wallpaper
lands, that is a separate paint/CSS miss.

| Probe | Meaning |
| ----- | ------- |
| `delayed15s` 13:09:17 | `_shownState=SHOWN` · `state=1` · `showAppsChecked=false` · `searchVis=false` · `appDisplayVis=false` |
| extra snap | `searchActive=false` · `entryText=""` · `resultsVis=true` is a **child** of hidden SearchController — not results on stage |
| Early snaps (`state=0`, `overview-idle-ok`) | before `runStartupAnimation` sets `_shown` |

### QS preferred `-12` (DEFERRED — 2026-09-17)

**User call 2026-09-17:** nest does **not** crash currently. `-12` still
logs (`mapped=0` on the QS grid peer) but is **not** the live bar — push
below overview / menus. Do not spend turns on the Helper measure guard
until §2 moves.

| Fact | Evidence |
| --- | --- |
| Client measure | stock `spacing = (rows.length - 1) * row_spacing`; empty rows + spacing 12 → **-12** |
| Gate | `GI_META_SMOKE=quicksettings-layout-neg-smoke` → **FAIL** `min=-12 nat=-12` |
| Historical mutter death | `ClutterBoxLayout` `g_error` when that value reaches **allocate** on a **mapped** child → `ec=133` |
| Live now | preferred `-12` still logged; parent/grid **mapped=0** → no stay-up death |
| **🚫** | JS override / `Math.max` in stock `quickSettings.js` · `LiveCallback.reply` sniff |

### Menu close (2026-09-17)

| Fact | Evidence |
| --- | --- |
| `menu.close(0)` / `toggle` after settle | **OK** — `isOpen=false`, BoxPointer hidden (+250ms) |
| Stock close path | `PopupMenuManager._onCapturedEvent` → `get_event_actor` + `!actor.contains(target)` → `menu.close(FULL)` |
| Gate | `GI_META_SMOKE=captured-event-smoke` → **ok** (`stop (smoke-ok)`). Was `sawCaptured=0`. |
| Landed | Helper `captured_event` + always-hook (connect path, not only vfunc). `Stage.get_event_actor` local pick (`get_actor_at_pos` REACTIVE / key-focus). Event is Compact — not on the wire. |
| Probe delayed15s | programmatic close/toggle still OK. Pointer **click-open** still often `FAIL *-click-no-open` (QS historically; dateMenu this run too). User live open still the score for open. |
| Residual | Compact Event coords on the GJS `Event` are wrong (`0,0` / `222,1`) so `get_event_actor(event)` often returns the **stage**. That is enough for **close**. Inside-popdown clicks miss the child. |
| **User (2026-09-17)** | Open/close **mostly done**. **Backlog:** none of the buttons on any popdown work. |

### Todo (resume here)

1. ~~**§2 overview**~~ — ✔️ `set_to` wire; nest `state=1`.
2. ~~**Menu close**~~ — ✔️ `captured-event-smoke` **ok** + **user** hide-after-show.
3. **WINDOW_PICKER content** — wallpaper pane visible (user). **Panel inset** next (search + panes too high). Thumbs row still missing visually. Grey/red-dot leftover.
4. **Clock click** — nested `date-menu-open-smoke: ok`. Needs **user live** click-the-time re-score after the GLSLEffect handle fix. Never-shrink stays reverted.
5. **Backlog — popdown buttons** — calendar, QS tiles, settings row, … (Event coords).
6. **Later:** QS volume / `-12`.
7. Soft: interval gate `final=0` — not chrome.


### Prove stay-up (expect timeout, not 133)

```bash
ninja -C build src/gnome-shell-rpc src/mutter-rpc
GI_RPC_JS_OVERRIDE_DIR=$PWD/src/shell-js-probe \
  GSR_NESTED_NO_A4=1 GSR_NESTED_STAYUP=1 GSR_NESTED_TIMEOUT=45 \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
# expect: delayed15s indicators-ok · startingUp=false · stop (timeout)
# score FAILs only from the delayed15s snap, not early/later
```

---

## Symptom

User live + settle probe (above). Historical one-liners:

| # | Surface | Observed | Stock |
| - | ------- | -------- | ----- |
| 1 | Workspace selectors | ✔️ centred (`workspace-dot-align-smoke` **C**) | Centred on panel height |
| 2 | Overview / search entry | Wallpaper visible; search + panes too high (no panel inset) | Search below panel → thumbs → wallpaper |
| 3 | Clock | Opens + closes ✔️; buttons inside dead | Open/close + month nav |
| 4 | System menu | Opens + closes ✔️; tiles dead; volume size later | Toggle close; tiles click |
| 5 | Geom | `messageTray` / BoxPointer still off | Finite allocation |

Do **not** start at the `ensureAllocation` lock for §1/§2.

**Contract:** [`clutter-layout-allocate.md`](../clutter-layout-allocate.md).  
**Allocate (archived):** [`done/2026-09-16-allocate-follow-reference.md`](done/2026-09-16-allocate-follow-reference.md).

---

## Do

1. **Flow 2** — ✔️ public `clutter_actor_allocate` on the Helper peer.
   Gate: `workspace-dot-align-smoke` **C** PASS (**A/B** stay PASS).
2. **Wallpaper** — same Flow 2 on `_backgroundGroup` children. Grey is
   SystemBackground `#282828`, not `_coverPane` (opacity 0).
3. **Flow 1 / 3** — ✔️ Helper LM peer + `set_layout_manager` + C
   `layout_changed` on that peer. `hook-o-gate` PASS after OPC.
   Gate: `startup-allocate-smoke` **A** PASS · **E** PASS · **F** PASS
   (`hits=1`). Nest stay-up after READY — ✔️ (see **Boot death** CLOSED).
4. **`set_container` → `set_container_vfunc`** — ✔️ for GJS LM
   (`rpc_lid==0`). Gate: `layout-set-container-smoke` **A/B/C/D** PASS.
5. **WorkspaceDot / GJS `Clutter.Actor` subclass** — ✔️ Helper-Actor
   attach when leaf type ≠ `Clutter.Actor` (stock `WorkspaceDot` extends
   Actor, not `St.Widget`). Gate: `workspace-dot-align-smoke` **C** PASS
   (`midDy=0`).
6. **ButtonBox hpadding / `style-changed`** — ✔️ Helper override
   `style_changed` → client `Signal.emit` (`buttonbox-hpadding-smoke`
   PASS). Residual: popdown **buttons** (backlog) / QS volume.

**🚫** Idle · vendor `js/` · client `layout_changed` → `queue_relayout` ·
Actor allocate Hook as the LM · `rpc_lid` on the GJS LM · destroy
`_coverPane` / force `_startingUp=false`.

Fix lands only as the stock-shaped answer to a named **MISS** row.

---

## Prove

```bash
GI_META_SMOKE=workspace-dot-align-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# C PASS (A/B stay PASS)

GI_RPC_JS_OVERRIDE_DIR=$PWD/src/shell-js-probe \
  GSR_NESTED_NO_A4=1 GSR_NESTED_STAYUP=1 GSR_NESTED_TIMEOUT=45 \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
# delayed15s: indicators-ok · startingUp=false; score that snap

GI_META_SMOKE=layout-set-container-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# A/B/C/D PASS

GI_META_SMOKE=buttonbox-hpadding-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# ok nat=12 min=6

GI_META_SMOKE=gjs-binlayout-super-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# A/B/C PASS (super.vfunc BinLayout/BoxLayout not the BoxPointer miss)

GI_META_SMOKE=captured-event-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# ok — grab + captured-event + !contains (PopupMenuManager close)

GI_META_SMOKE=workspace-background-allocate-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# PASS inner=800x400 — stock WorkspaceBackground.allocate sizes wallpaper child

GI_META_SMOKE=workarea-panel-inset-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# PASS startY=32 — Meta strut→workarea OK

GI_META_SMOKE=workarea-panel-chrome-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# A later / B monitor-index / C workareas-changed — Weston only
```

Logs: `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log`.  
Stop reason (prove SIGKILL vs real death): [`nested-debug.md`](../nested-debug.md).

---

## LLM only — reading I don't give a crap about

Not the work. Agents: do not repeat these. Do not promote them into **Do**.

**Workarea MISS (closed):** `LayoutManager.set_container` for
`rpc_lid==0` was a no-op — never called `set_container_vfunc`. Stock
`clutter_layout_manager_set_container` always hits the Class slot.
WorkspaceLayout only sets `_workarea` there. Fix in
`LayoutManager.override.vala`. Smoke: `layout-set-container-smoke`.

**WorkspaceDot (closed):** stock extends `Clutter.Actor`; smoke used
`St.Widget` → false green. Helper-Actor attach for leaf types whose
first Bin ancestor is `Clutter-Actor` but `get_type() != Actor`. Chrome
`workspace-dot` midDy=0.

**ButtonBox hpadding (closed):** theme `get_length` returned 6/12 but
`_natHPadding` stayed 0 — server peer `style-changed` never reached GJS
`connect`. Helper `style_changed` + client emit. Gate:
`buttonbox-hpadding-smoke`.

**Early probe lies:** empty QS / `startingUp=true` / panel-right `0x32`
before `QuickSettings._setupIndicators` finishes (~10–15s). Use
`delayed15s`. Residual: popdown buttons (Event coords); QS volume;
boot search = stock WINDOW_PICKER (not a miss).

**BinLayout super (ruled out):** `gjs-binlayout-super-smoke` **A/B/C**
PASS — not the stage-wide BoxPointer cause.

**Client rewrite of C (reverted).** `layout_changed_invoke` → client
`queue_relayout` + Actor allocate Hook as LM. **F** reenter-storm; nest
EOS / mutter ec=133.

**Observe:** score `delayed15s` + user live. Wallpaper on
`_backgroundGroup`. Menu open/close ✔️ (user). Popdown buttons backlog.

**Not this chrome:** Interval / Transition / Animatable corridor already
landed.

**Supersedes leftover chase on:**
[`done/2026-09-15-chrome-placement.md`](done/2026-09-15-chrome-placement.md)
· [`done/2026-09-15-adjustment-animatable-startup-grey.md`](done/2026-09-15-adjustment-animatable-startup-grey.md)
· [`done/2026-09-15-boot-blank-background.md`](done/2026-09-15-boot-blank-background.md)
· [`done/2026-09-16-allocate-follow-reference.md`](done/2026-09-16-allocate-follow-reference.md)
