# Overview app search — first query shows icons; next keystroke shows Searching…

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
> tree. **No** `GLib.idle_add` / Idle / Timeout / defer as a product fix.
> No layout.js ship hacks. **🚫** vendor `search.js` / `searchController.js`.
> **🚫** invented GI.
>
> ## 🚫 Do not invent shit in this tree
>
> A stack frame / “allocation RPC” / “same as destroy_rpc” pattern is **not**
> a license to dump Helper methods, local GValue caches, deny lists, or ABI
> “fixes” into `src/` before a FAIL names **the second-term miss**.
>
> Required order:
>
> 1. Reproduce second-term Searching (live or nested smoke `after-fi`).
> 2. Write a **FAIL** that dies on **that** miss — not a gate that already
>    PASSes (`H-allocation`) while the overlay still comes back.
> 3. Only then a **minimal** change that makes **that** FAIL PASS.
> 4. Re-run. If the overlay still returns on a **new** frame, update this
>    bug and go to (2). Do **not** invent the next subsystem in the same turn.
>
> **Forbidden:** Helper `set_relay_`* / kind switches / local caches /
> “while we’re here” deny expansions — before a FAIL smoke names the fix.
> Revert speculative dumps; do not leave them “for later.”

**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Source of truth for stock JS:** read
`vendor/gnome-shell/js/ui/{init.js,search.js,searchController.js}` directly.
Do **not** use `gresource list` / `gresource extract` to inspect code that is
already vendored in this repository.

## Next

**User types. Agent reads the log.** Live search is easier for the
user to reproduce in the held nest than for an agent to drive
(`clutter_text`, xdotool, staged keys). Agents **ask the user to type**
`ter` then `m` (or wait), then grep `app-search-observe:` in
`~/.cache/gnome-shell-rpc/nested-weston-prove.tee.log`. Do **not**
automate the typing.

Live: type `ter` → icons. Type `m` **or wait** → **Searching…** and it
**never comes back**. Overlay is **still open**. Do **not** reintroduce
“never shrink allocation” on every actor — that crashed the clock (see
chrome bug).

**Handoff 2026-09-22** — GLSL unpack archived ([`done/2026-09-21-shell-glsleffect-bin-alias.md`](done/2026-09-21-shell-glsleffect-bin-alias.md)). Search product miss is unchanged.

Rolled-back 2026-09-21 dumps stay **out**. They did not move the live needle; never-shrink crashed the clock. Do **not** gently reapply `call_depth` / local `get_laters` / undeny `queue-relayout` / never-shrink without a FAIL that names the **second-term** miss. Keep the allocation getter that skips non-finite mutter width.

Smoke must reproduce the normal-session interaction path: enter `ter`, observe
icons, then enter `m` and observe the permanent Searching state. **No** 1px
`allocate` toy and no timeout manipulation. Elapsed time is not a causal
variable in this bug; “or wait” describes another way the same broken state
becomes visible, not a duration to tune.

**Named miss (live observe 2026-09-22 09:47, user typed in the hold):**
width is **not** the cause. Stock `SearchResultsBase.updateSearch`
**catch** clears the grid after a successful fill.

Held-session observe (`app-search-observe:` in
`~/.cache/gnome-shell-rpc/nested-weston-prove.tee.log`):

```
09:47:28.552  updateSearch-in  terms=["t"]    results=140 nGrid=0 width=0
09:47:28.575  _getMaxDisplayedResults width=0 mutter=-Infinity n=6
09:47:29.017  updateSearch-out terms=["t"]    nGrid=6 first=true  width=0
09:47:29.592  updateSearch-in  terms=["ter"]  results=25  nGrid=6 width=792
09:47:29.629  _getMaxDisplayedResults width=792 mutter=792 n=5
09:47:29.957  updateSearch-out terms=["ter"]  nGrid=5 first=true  vis=true width=792
09:47:30.082  updateSearch-out terms=["ter"]  nGrid=0 first=false vis=true width=792
09:47:30.264  progress terms=["ter"] inProgress=false status="No results" nGrid=0
09:47:31.092  updateSearch-in  terms=["term"] results=6 nGrid=0 width=792
09:47:31.094  _getMaxDisplayedResults width=792 mutter=792 n=6
09:47:31.170  updateSearch-out terms=["term"] nGrid=6 first=true  vis=true width=792
09:47:31.176  updateSearch-out terms=["term"] nGrid=0 first=false vis=true width=792
```

Between each fill/clear pair: **no** second `updateSearch-in`, **no**
`_getMaxDisplayedResults`. `term` pair is 6ms. RPC after the fill:
highlight (`add_style_pseudo_class`) + `ensureActorVisibleInScrollView`
(`get_vadjustment` / `get_effect`), then `remove_all_children` with
**no** `hide` and **no** `add_child`. That is stock catch:

```
} catch (e) {
    this._clearResultDisplay();
    callback();
}
```

(empty-results path would `hide()` first; we do not see that hide.)
Stock `GridSearchResults.updateSearch` re-enters `super.updateSearch`
from `notify::allocation` → `get_laters(BEFORE_REDRAW)` with the **same**
callback, so observe logs a second `updateSearch-out` without a new
`-in`. The swallowed catch error was not logged in 09:47; observe now
wraps `_ensureResultActors` so the next hold names it.

`(0, minW]` / `maxResults=0` is **disproven** (`width=792` on fill and
clear).

**Smoke 09:52 (notify after `after-ter`, too late) — PASS, not the miss.**
`ter` fill `nGrid=6` `width=0`, snapshot `after-ter` `nGrid=6` `allocW=792`
`notifyN=0` `allocateN=0`. Then `display.notify('allocation')`:
`_getMaxDisplayedResults width=792 n=5`, `updateSearch-out nGrid=5`
`first=true` (later **refills**, does not catch). `after-wait` /
`after-term` still `nGrid=5` `first=true`. `ok`. A later that runs
**after** the first `updateSearch` has finished is not the live catch.

**Smoke 09:54 (notify during fill) — also PASS, not the miss.**
`ter`: `-in`, `n=6` `width=0`, `notify w=0`, second `n=6`, `-out nGrid=6`
`width=0`, then another `-out nGrid=6 width=792` (later **refills** as
width arrives). `term`: `-in`, `n=5`, `notify w=792`, three more `n=5`,
**four** `-out` all `nGrid=5 first=true`. No `_ensureResultActors`
throw. **`ok`**. Forcing `notify::allocation` produces extra
`updateSearch-out` that **succeed**. Live second out is catch (`nGrid=0`,
no `_getMaxDisplayedResults`). That emit is a rejected probe — same
class as late 09:52 notify and 1px allocate. **Removing it from the
smoke.** FAIL detector `second-updateSearch-clear` stays.

**10:01 hold (user typed; observe stacks):** the emptying `_clearResultDisplay`
is stock **catch** at `search.js:278`, not the success clear at 271.

```
10:01:28.690  clear nGrid=6 vis=false width=792  stack=search.js:271  (hide/clear/add — fill)
10:01:29.239  updateSearch-out terms=["term"] nGrid=5 first=true
10:01:29.253  clear nGrid=5 vis=true  width=792  stack=search.js:278  (catch)
10:01:29.258  updateSearch-out terms=["term"] nGrid=0 first=false
```

Same pair on `termi`. Wrapped `hide` / `show` / `_addItem` /
`_ensureResultActors` / `getResultMetas` **did not throw**. The try
body filled; then `callback()` after `show()` threw; catch cleared the
grid it just built. That callback is `_updateResults` →
`_maybeSetInitialSelection` → `ensureActorVisibleInScrollView` →
`scrollView.get_effect('fade')` then `vfade.fade_margins.top` (09:47
RPC: `get_effect` then `remove_all_children`, no `get_allocation_box`).

**10:05 hold (user typed `term`):** `e` is named.

```
10:05:04.739  updateSearch-out terms=["ter"]  nGrid=5 first=true
10:05:04.784  updateSearch-callback threw vfade.fade_margins is undefined
10:05:04.786  clear nGrid=5 vis=true stack=search.js:278
10:05:04.820  updateSearch-out terms=["ter"]  nGrid=0 first=false
10:05:05.209  updateSearch-out terms=["term"] nGrid=6 first=true
10:05:05.213  updateSearch-callback threw vfade.fade_margins is undefined
10:05:05.218  updateSearch-out terms=["term"] nGrid=0 first=false
10:05:05.235  progress status="No results" nGrid=0
```

Stock `ensureActorVisibleInScrollView` (`animationUtils.js` ~45):

```
const vfade = scrollView.get_effect('fade');
if (vfade)
    offset = vfade.fade_margins.top;
```

`get_effect('fade')` is **truthy** but has no `fade_margins`. Real St
type is `StScrollViewFade` (`st-scroll-view-fade.c`) — property
`fade-margins` / `ClutterMargin`. Not in our generated St stubs.
Do **not** invent `fade_margins` on `Clutter.Effect`.

**Smoke 10:08:** `after-ter` `nGrid=6` `first=true` `fade=St_ScrollViewFade`
`fadeMargins=undefined` → **`miss fade-margins`**. FAIL died.

`St.ScrollViewFade` exists; generator **silently** skipped the GIR
**property** (boxed `ay`, not a scalar `gprop`) and left only
`get_fade_margins` methods. No row in `St_generated.missing.md`. GJS
uses `.fade_margins`, not the method. That omit-without-gap is a
generator hole — carry-on:
[`2026-09-22-gi-stub-gen-silent-property-skip.md`](2026-09-22-gi-stub-gen-silent-property-skip.md).
Generate must **print + fail** (exit ≠ 0) so compile cannot continue.
Deny-only is a hide. Override may supply `fade_margins` (client local
`Clutter.Margin`) **after** generate fails closed. Do not put it on
`Clutter.Effect`.

```bash
GSR_NESTED_TIMEOUT=60 GI_META_SMOKE=app-search-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
```

Held observe — **start this, then ask the user to type** `ter` then `m`.
Do not type for them.

```bash
GI_RPC_GJS_EMBED_DIR=src/gjs-embed \
GI_RPC_REGISTER_CLASS_TRACE=1 \
GI_RPC_APP_SEARCH_OBSERVE=1 \
  GSR_WESTON_MODE=session ./scripts/weston-gsr-session.sh
```

After they say they are done, grep `updateSearch-callback threw` and
`clear stack=` in the tee log.

`REGISTER_CLASS_TRACE=1` is only the host preload hook. Observe **skips**
the class tracer — that tracer died on duplicate GType `Source` and left
a blank nest (2026-09-22 09:44).

Stock JS is `vendor/gnome-shell/js/ui/search.js`. Use the RPC log. Do not
start over.

### Evidence ledger — carry this forward

Established:

- Live held session reproduces `ter` icons → next character / later frame →
  permanent Searching. Observe 09:47 / 10:01: fill then catch-clear at
  `width=792`. **User types; agent does not automate the keys.**
- Search plumbing works through `AppSystem.search`, app lookup, result metas,
  result-object creation, `text-changed`, and `setTerms` in the smoke.
- Passing smoke snapshots keep a real applications first result; the live
  failure is later than basic provider/metas creation.
- The current smoke is not a valid reproduction of the live failure
  unless it hits the 09:47 second-out catch (`nGrid=0` after fill).

Already tried or ruled out:

- Allocation-box unpack/getter did not move the live symptom.
- Global never-shrink allocation is invalid and crashed panel/clock UI.
- Synthetic 1px allocation only manufactured `maxResults=0`.
- `overview.show()` probes, provider-timeout manipulation, key-focus probing, local
  `get_laters`, queue-relayout undeny, and call-depth workarounds did not name
  the live second-term miss.
- Calendar/provider timeout was coincident with one capture, not the cause.
- Changing delays cannot make the current smoke a valid reproduction.
- **09:52:** `notify('allocation')` **after** `after-ter`. Later
  **refilled** `nGrid=5`. Not the live catch.
- **09:54:** same emit **during** fill. Extra `-out`s all `nGrid=5/6`
  `first=true`. Still not the catch. Emit **removed**.

10:05 named `e`: `vfade.fade_margins is undefined`. Smoke FAIL is
`fade-margins`. Then a **minimal** `St.ScrollViewFade.fade_margins`
(real C / GIR), not `Clutter.Effect`. Do not invent GI.

## Symptom

Type `ter` → application icons. Type `m` or wait a bit → overlay **Searching…**, grid empty, **stays that way**.

## Stock

`SearchResultsView.setTerms` sets `_startingSearch` and calls `_updateSearchProgress` immediately. Overlay is **Searching…** when `getFirstResult()` is null and something is still in progress.

`GridSearchResults.updateSearch` (`search.js` ~493) connects
`notify::allocation`, may `get_laters(BEFORE_REDRAW)` →
`super.updateSearch(...args)` again (same results / terms / callback),
then also calls `super.updateSearch` immediately.

`SearchResultsBase.updateSearch` (`~251`): empty results → clear +
`hide` + callback. Else `_getMaxDisplayedResults`,
`filterResults`, `await _ensureResultActors`, then hide / clear / add /
show / callback. **Catch** (swallows `e`): `_clearResultDisplay()` +
callback — **no hide**. Live 09:47 second out is this catch.

`_getMaxDisplayedResults` (`~518`) uses `this.allocation.get_width()`
**before** try/catch; `width === 0` → `maxResults` (6), else
`columnsForWidth`. `getFirstResult` is `for (let child of this._grid)`
skipping `!child.visible`.

`AppSearchProvider.getResultMetas` (`appDisplay.js` ~1793) ignores the
cancellable and always resolves metas. Stock then throws if
`this._cancellable.is_cancelled()` and `metas.length > 0`
(“returned results after the request was canceled”). That throw is a
candidate for the swallowed catch; 09:47 did not log it.

## Validation

```bash
meson test -C build --print-errorlogs app-search-empty-gate
```

- `H-allocation`: GObject property `Clutter.Actor.allocation` exists (first query).
- `H-queue-relayout`: `GObject.signal_lookup('queue-relayout', Clutter.Actor)` — live 11:56 `JS ERROR: No signal 'queue-relayout' on … AppIcon` (`iconGrid.js:560`, FolderView `_loadApps` stack, not the search grid `add_child`).

```bash
GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=app-search-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
```

Smoke types `ter`, waits, then extra key `term`. Logs `_getMaxDisplayedResults`, `after-ter` / `after-wait` / `after-term` (`allocW`, `nCols`, `minW`, `statusBin`, `scroll`, `nGrid`). No 1px allocate.

### 2026-09-22 live capture and rejected probes

- **Observe 09:47 (held session, user typed).** Full lines in **Next**.
  Named miss `second-updateSearch-clear`. Width / `maxResults=0` is not
  this miss. `_ensureResultActors` throw is now logged on observe +
  smoke so the next run names the catch.
- **Smoke 09:52.** Direct `ter` / `term` plus `notify('allocation')`
  **after** `after-ter`. `after-ter` `nGrid=6` `allocW=792` `notifyN=0`
  `allocateN=0` (getter served 792 without `allocate` / notify). Later
  from the late emit: `n=5`, `updateSearch-out nGrid=5 first=true`.
  `after-term` `nGrid=5` `first=true`. **`ok`**. Late later ≠ live catch.
- **Smoke 09:54.** `notify('allocation')` immediately after
  `GridSearchResults.updateSearch` returns. `ter` two `-out` (`nGrid=6`
  `width=0` then `width=792`). `term` four `-out` all `nGrid=5`
  `first=true`. No ensure throw. **`ok`**. Mid-fill notify **removed**.
- **Live reproduced by user in the held nested session.** RPC log
  09:03:16 already has the stock success path: `hide` →
  `remove_all_children` → five `add_child` → `show` →
  `get_child_at_index` + `add_style_pseudo_class` (default highlight, so
  `getFirstResult` was non-null). Then another `remove_all_children`.
  Next `_updateSearchProgress` walk (`get_first_child` / `get_n_children`
  on every provider) found no first result and set Searching. That later
  clear is the live miss. Calendar's error is unrelated. Smoke
  `after-term` still has `nGrid=5` `first=true` `notifyN=0` — it never
  takes that later `updateSearch`.
- Baseline direct-assignment smoke (`ter`, then `term`) **PASSed**:
  `allocW=792`, app `nGrid=6` then `5`, `first=true`. It did not reproduce the
  live state.
- A physical-key/focus probe found a swallowed key after focus loss. That was
  an input-path detour, not the reported result-loss miss; the probe was
  reverted and no product inference is being made from it.
- Provider-timeout manipulation and altered delays either **PASSed** or hung
  before a result snapshot. They did not reproduce the UI bug, were the wrong
  direction, and have been removed from the smoke.
- Current smoke is restored to the prior direct `ter` / `term` probe. That
  probe still PASSes while the normal held session fails, so the **test
  harness itself is not yet a valid reproduction**. Fix that mismatch next;
  do not vary delays again.

**2026-09-21 09:19 prove:** typed `fi`. `after-f` `nGrid=6` `first=true`. Hung before `after-fi` on `Meta-Compositor.enable_unredirect` (`pending=1`). Not the overlay.

**2026-09-21 09:23 prove:** hung in `main.start`: client wrote `Clutter-GestureAction.new` id=750 then nested `Meta.prefs_get_dynamic_workspaces` id=751 from `before-update`; mutter `recv` 750 only.

**2026-09-21 coalesced-nested-request-gate:** that 09:23 shape — two Requests already on the socket, OPC `on_input_ready` loops the unbuffered IOChannel so the second sits in `bin.in_stream`. **FAIL** (`Gate.inner` timeout, server `create n=1` never `inner`). `Connection.on_input_ready` now `drain_readable()` / `input_pending()`. Gate **PASS**. Nested start hangs of that shape are this, not the overlay. Not an OLLMchat edit.

**2026-09-21 10:04 prove** (`overview.show()` before type): `after-f` / `at-fi` / `after-fi` all `terms` still set, `overview.visible=true`, `displayMapped=true`, `nGrid=6` `first=true` `allocW=0`. Smoke **ok**. Nested second term is not empty. Later `overview.show()` runs died `mutter exited ec=133` (`g_closure_ref`). Show wrap removed.

**2026-09-21 10:10 prove:** `at-fi` `statusBin=false` `scroll=true` `nGrid=6` `first=true` `minW=25/568` `c1=0` `c1280=51`. Stock `columnsForWidth`: `width === 0` → 6 results; `0 < width ≤ minW` → `nCols=0` → `maxResults=0` → hide/clear → overlay. `set_width(1280)` then `allocation.get_width()` still **0** (getter is `actor_allocation`, not mutter). Nested never leaves the `width === 0` shortcut. `after-fi` without overview is still `SearchController.reset` (`text=""`, `miss text-changed`).

**2026-09-20 11:59 prove:** `hook` then hang. Client sent `Meta-Compositor.get_laters` id=565 during `main.start` → `XdndHandler` → `LayoutManager._updateRegions`; no reply until SIGKILL (~48s). Aftermath `laters is null`. Live hold session gets past start (user can type).

**2026-09-20 12:11 prove** (local `Compositor.get_laters`): reached snapshots. `after-f`: `nGrid=6` `first=true` `allocW=0` `nCols=0` `status="Searching?"` `displayMapped=false` `overview.visible=false` (typed before overview). `_getMaxDisplayedResults width=0 n=6`. `after-fi`: `text=""` `terms=[]` `nGrid=0` `status="No results"` `miss text-changed` (`textChangedN=3`) — search reset, not the live second-term.

**2026-09-20 08:24 prove:** wait `startup-complete` hung 60s (`ensureAllocation` in `ControlsManager.runStartupAnimation`). `main.start()` does not wait that signal. Do not block the smoke on it.

**2026-09-21 08:50 prove:** died in the smoke: `FAIL start TypeError: main.overview.controls is undefined`. Did not reach `after-f` / `after-fi`. That wrap is removed.

## What is not the second-term miss

RPC unpack of the allocation box (user 2026-09-21: that getter did not move the live needle). `-Infinity` / width `0` (those use `_maxResults` 6). Remote D-Bus taking ~25s (icons stay in nested, overlay hidden). Nested extra-key / `term` keeps icons; nested wait often `notifyN=0`. Live wait **or** second key empties the grid.

A later-frame box in `(0, minW]` after a wide grid **would** make stock `columnsForWidth` return 0 → `maxResults=0` → hide/clear → overlay. **Live 09:47 disproved that for this miss** (`width=792` on both fill and clear; no `_getMaxDisplayedResults` on the clearing callback). The clear is stock `updateSearch` **catch**.

A `notify::allocation` later that runs **after** a finished fill
**refills** (smoke 09:52 `nGrid=5`). That is not the live catch. 10:01
stacks: success clear at `search.js:271`, then catch at `278` because
`callback()` after `show()` threw (`_maybeSetInitialSelection` /
`ensureActorVisibleInScrollView` / `get_effect('fade')`). `e` still
unnamed.

Neither fact is a license to never-shrink every actor’s cache (user:
crashed the clock; not a real fix).

## 2026-09-21 — what we tried, what we rolled back

Worked this ticket, then the clock regression it caused. Chrome details: [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md) (clock row + GLSLEffect). D-Bus leftovers: [`weston-nested-test-env.md`](../weston-nested-test-env.md).

| Attempt | What happened | Now |
| --- | --- | --- |
| `Clutter.Actor.allocation` GObject getter (skip `-Infinity` / empty, copy finite mutter width) | Needed so `this.allocation.get_width()` is not always the cache of 0. First query can use the `width === 0` → 6 shortcut. **Did not** stop live Searching… | **Keep** — `Actor.override.vala` getter. Coding standards: `var w`, early return, no `bool` flag temps |
| `allocate()` always stores `actor_allocation = box` | Matches mutter’s last box | **Keep** |
| Synthetic `display.allocate(1px)` in `app-search-smoke.js` after `ter` | Forced FAIL `maxResults-zero` in nested. User: not the live miss (“something tells a search grid it is only one pixel wide” is a smoke toy, not a fix) | **Removed 2026-09-22.** Do not ship 1px as product |
| `display.notify('allocation')` after `after-ter` (09:52) or during fill (09:54) | Extra stock later **refills** (`nGrid=5/6 first=true`). Live later **catches** (`nGrid=0`, no `_getMaxDisplayedResults`) | **Removed 2026-09-22.** Not the miss |
| “Do not shrink a usable cache” on **every** `allocate` / getter (keep 792px if later box is 1px) | Nested smoke `maxResults-zero` went away. User: not a real fix. **Crashed clock / date menu.** Also violated coding standards (`bool new_ok` / `cached_ok`, no braces) | **Reverted 2026-09-21.** Do not put it back |
| Host `ShellApplication` `Bin.register("Shell-GLSLEffect", typeof(Shell.GLSLEffect))` after `Runtime.register()` | Unblocked `get_effect` unpack so `dateMenu.menu.open(0)` no longer 133’d. User: “this looks unlikely” — wrong layer, try/catch, one-off | **Removed.** **Not** this search ticket |
| `GLSLEffect` `static construct { Bin.register(...) }` | User: not a valid way | **Removed** |
| `GLSLEffect.rpc_register()` from `Global.bind_display` | User: one place calls all of these | **Removed** |
| Helper `Bin.register("Shell-GLSLEffect")` / client `shell_register` to unpack it | User: Shell GLSLEffect is never on the server. Compositor peer is `Clutter-OffscreenEffect` + `register_handle` | Archived [`done/2026-09-21-shell-glsleffect-bin-alias.md`](done/2026-09-21-shell-glsleffect-bin-alias.md). **Not** this search ticket |
| Click then `isOpen` in date-menu smoke | `fire_button_press` after `open()` toggles **closed** (`ok isOpen=false`). Click-no-open is an old probe miss | Smoke is **open-only**. Live click still the user’s score |
| Idle / timeout / vendor `search.js` as product fix | Forbidden on this ticket | Stay forbidden |

**Still in tree that is not the search fix:** `date-menu-open-smoke.js` (chrome). Allocation getter still skips non-finite mutter width so the first query is not poisoned. 1px allocate probe **removed** from the smoke (2026-09-22) — that was a nested toy, not the live wait / extra-key miss.

**Do not:** never-shrink globally · 1px product allocate · host `Bin.register` · `static construct` Bin.register · `rpc_register` from `bind_display` · wrap `overview.show()` · skip `columnsForWidth` · `GLib.idle_add` / Idle / Timeout as the overlay fix · invent GI.

## Reverted (2026-09-21)

Product-tree dumps from this bug were reverted (hang workaround, not a FAIL of the second-term miss):

- `Runtime.call_depth` / skip `before-update` during `call_poll`
- `Compositor.get_laters` client-local + `Compositor.override.vala` + `Meta.deny`
- `queue_relayout_rpc` / undeny `queue-relayout` signal
- **Never-shrink `actor_allocation`** on all actors (clock crash)
- **`ShellApplication` `Bin.register("Shell-GLSLEffect")`** (wrong layer)
- **`GLSLEffect` `static construct` `Bin.register`** (not a valid register path)
- **`GLSLEffect.rpc_register()` from `Global.bind_display`** (not the aggregator)

## Machine (not this miss)

Nested prove/hold used to leave `dbus-daemon --print-address --session` (and extra at-spi buses) reparented to init. Both machines then hit D-Bus max connections and the session bus dies. **Not** a gnome-shell-rpc bug.

```bash
./scripts/clear-nested-dbus.sh
```

Does not touch the systemd user/system bus. `weston-gsr-session.sh` / prove stop / hold exit call it. If a nest “stops working full stop” before you chase overlay, run that.

## Next (test area only)

See **Next** at the top. Smoke FAIL is `second-updateSearch-clear`. `coalesced-nested-request-gate` is the 09:23 start hang, not the overlay. Clock GLSL unpack is archived, not a search FAIL.
