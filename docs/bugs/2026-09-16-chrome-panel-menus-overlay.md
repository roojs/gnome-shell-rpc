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

**Status:** ⏳ open — land [`2026-09-16-allocate-follow-reference.md`](2026-09-16-allocate-follow-reference.md) after review  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

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

Probe (`GI_RPC_JS_OVERRIDE_DIR=src/shell-js-probe`) on the green stay-up:

| Probe line | Meaning |
| --- | --- |
| `FAIL dateMenu-boxpointer-stage-sized w=754` | menu opens via API but boxPointer is stage-wide |
| `FAIL dateMenu-click-no-open` / `quickSettings-click-no-open` | pointer click does not open |
| panel-right children `@ NaN,NaN` / `0x32` | geometry still broken |
| `JS ERROR: TypeError: this._workarea is null` | layout/workarea path still broken |
| `Unable to resolve arg type 'DesktopAppInfo'` | separate GI hole (not SEGV) |

**Next allowed step:** diagnose chrome geom / workarea / click (not boot
SEGV). Prefer FAIL smokes that assert finite panel/menu boxes and
workarea non-null.

### Prove stay-up (expect timeout, not 133)

```bash
ninja -C build src/gnome-shell-rpc src/mutter-rpc
GI_RPC_JS_OVERRIDE_DIR=$PWD/src/shell-js-probe \
  GSR_NESTED_NO_A4=1 GSR_NESTED_STAYUP=1 GSR_NESTED_TIMEOUT=45 \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
# expect: nested-weston-prove: stop (timeout) after 45s
```

---

## Symptom

| # | Surface | Observed | Stock |
| - | ------- | -------- | ----- |
| 1 | Workspace selectors | Not vertically centred on the top bar | Centred on panel height |
| 2 | System menu + clock | Click does nothing | PopupMenu below source |
| 3 | Desktop | Grey-brown over wallpaper | Wallpaper; no stuck cover |
| 4 | Geom | `messageTray` `@ NaN` · `alloc=false` · Inf box | Finite allocation |

#1 and #3 are wrong **before** the `ensureAllocation` lock. Do not start
at that lock.

**Contract:** [`clutter-layout-allocate.md`](../clutter-layout-allocate.md).  
**Fix to review:** [`2026-09-16-allocate-follow-reference.md`](2026-09-16-allocate-follow-reference.md).

---

## Do

1. **Flow 2** — ✔️ public `clutter_actor_allocate` on the Helper peer.
   Gate: `workspace-dot-align-smoke` **C** PASS (**A/B** stay PASS).
2. **Wallpaper** — same Flow 2 on `_backgroundGroup` children. Grey is
   SystemBackground `#282828`, not `_coverPane` (opacity 0).
3. **Flow 1 / 3** — ✔️ Helper LM peer + `set_layout_manager` + C
   `layout_changed` on that peer. `hook-o-gate` PASS after OPC.
   Gate: `startup-allocate-smoke` **A** PASS · **E** PASS · **F** PASS
   (`hits=1`). Nest stay-up after READY — **FAIL**: client SIGSEGV 139
   (see **Boot death**).

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
  GSR_NESTED_NO_A4=1 GSR_NESTED_SETTLE=12 GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# gsr-chrome: early startingUp=…  (dots + SystemBackground + wallpaper)

GI_META_SMOKE=startup-allocate-smoke GSR_WESTON_MODE=prove \
  ./scripts/weston-gsr-session.sh
# A PASS · E PASS · F PASS (hits=1)
```

Logs: `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log`.  
Stop reason (prove SIGKILL vs real death): [`nested-debug.md`](../nested-debug.md).

---

## LLM only — reading I don't give a crap about

Not the work. Agents: do not repeat these. Do not promote them into **Do**.

**Current FAIL numbers (so you know the gates):**
`workspace-dot-align-smoke` **C** `midDy=-12` (preferred 12×8 at origin).
**A/B** PASS (BoxLayout / `St.Bin` compute a centred child box).
`startup-allocate-smoke` **A** never resolves · **B/C** `queue_relayout`
reaches mutter, no later GJS LM vfunc · **E** `lm.allocate()` no-op
(`rpc_lid==0`) · **F** `hits=1` after revert.

**Client rewrite of C (reverted).** `layout_changed_invoke` → client
`queue_relayout` + Actor allocate Hook as LM. **F** reenter-storm; nest
EOS / mutter ec=133. A/E went green; chrome did not clear `_startingUp`.

**Observe (already used):** probe must snapshot early — do not wait for
`startingUp`. `_coverPane` opacity 0. Wallpaper is `_backgroundGroup`.
`dateMenu.menu.open(0)` / `quickSettings.menu.open(0)` set `isOpen=true`
(click path is the break). dateMenu BoxPointer still ~stage-sized when
forced. Hang site: `await this.layout_manager.ensureAllocation()`.

**Not this chrome:** Interval / Transition / Animatable corridor already
landed. Right pull-down used to open (wrong size); now does not — after
Flow 2.

**Supersedes leftover chase on:**
[`done/2026-09-15-chrome-placement.md`](done/2026-09-15-chrome-placement.md)
· [`done/2026-09-15-adjustment-animatable-startup-grey.md`](done/2026-09-15-adjustment-animatable-startup-grey.md)
· [`2026-09-15-boot-blank-background.md`](2026-09-15-boot-blank-background.md)
