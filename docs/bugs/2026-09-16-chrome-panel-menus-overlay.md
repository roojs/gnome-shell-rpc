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
| 2 | Boot / desktop | ✔️ overview ends WINDOW_PICKER (`state=1`) after `set_to` wire rename — stock boot. User Esc → idle. Was stuck `state=0` (−32601 on `set_to_value`). | Stock: WINDOW_PICKER after startup; Esc hides |
| 3 | Clock (dateMenu) | Click **opens** calendar menu | Same |
| 4 | Clock menu | Calendar **nav broken**; **cannot close** the menu | Month nav works; click-out / Esc / re-click closes |
| 5 | System menu (quickSettings) | Mostly laid out; volume icon present; volume block **size balked**; **cannot close** once open | Content-sized tiles; toggle / click-out closes |
| 6 | Geom (probe) | `messageTray` still odd; BoxPointer dateMenu ~stage-wide preferred | Finite tray; menu ~content |

**Probe after settle (≥15s)** — aligns with user on open; click-close not asserted yet:

| After `delayed15s` (2026-09-16 22:58) | Meaning |
| --- | --- |
| `startingUp=false` · indicators `n=16` · panel-right / QS finite | setup finished |
| `dateMenu-click-open-ok` | matches user §3 open |
| `FAIL overview-still-showing` | matches user §2 app-chooser / overview stuck |
| `FAIL quickSettings-click-no-open` | probe click path; user can open QS by hand |
| `FAIL dateMenu-boxpointer-stage-sized w=754` | wide popover (content sum) |
| ~~`this._workarea is null`~~ | ✔️ `set_container` → `set_container_vfunc` |
| ~~panel-left hpadding `_natHPadding=0`~~ | ✔️ Helper `style_changed` → client emit (`buttonbox-hpadding-smoke`) |

**Early probe lies** (empty QS / `startingUp=true` / panel-right `0x32`) — timing
only until `QuickSettings._setupIndicators` finishes. Score `delayed15s` +
user live, not early/later.

**Resumed (2026-09-17).** Primary: **§2 overview / app-search at boot**.
QS `-12` / mutter death **deferred** (nest does not crash currently).
**🚫** vendor `js/` / `GI_RPC_JS_OVERRIDE_DIR` production fix for QSLayout.
**🚫** sniffing preferred sizes inside `RPC-Live-Callback.reply`.

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

### Todo (resume here)

1. ~~**§2 overview / app-search at boot**~~ — ✔️ wire `set_to` / `set_final` (typelib names); nest `state=1`.
2. Menu **close** (clock + QS) + calendar nav.
3. **Later:** QS `-12` guard / child-set vs lifecycle (deferred above).
4. Soft: `clutter-interval-gvalue-gate` still `final=0` after rename (no −32601) — peek/set stick separate from chrome; not blocking.

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
| 2 | Overview / app search | Stuck open after boot (as if Super) | Closed; wallpaper idle |
| 3 | Clock | Opens on click; no close; calendar nav dead | Open/close + month nav |
| 4 | System menu | Opens; layout rough (volume size); no close | Toggle close; sane tile size |
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
   PASS). Residual: overview stuck / menu close / calendar nav /
   QS volume size (see **Live chrome**).

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
`delayed15s`. Residual: menus **do not close** (user); overview / app
search **stuck**; QS volume size; calendar nav.

**BinLayout super (ruled out):** `gjs-binlayout-super-smoke` **A/B/C**
PASS — not the stage-wide BoxPointer cause.

**Client rewrite of C (reverted).** `layout_changed_invoke` → client
`queue_relayout` + Actor allocate Hook as LM. **F** reenter-storm; nest
EOS / mutter ec=133.

**Observe:** score `delayed15s` + user live. Wallpaper on
`_backgroundGroup`. Programmatic `menu.open(0)` works; click-close and
calendar nav not yet gated.

**Not this chrome:** Interval / Transition / Animatable corridor already
landed.

**Supersedes leftover chase on:**
[`done/2026-09-15-chrome-placement.md`](done/2026-09-15-chrome-placement.md)
· [`done/2026-09-15-adjustment-animatable-startup-grey.md`](done/2026-09-15-adjustment-animatable-startup-grey.md)
· [`done/2026-09-15-boot-blank-background.md`](done/2026-09-15-boot-blank-background.md)
· [`done/2026-09-16-allocate-follow-reference.md`](done/2026-09-16-allocate-follow-reference.md)
