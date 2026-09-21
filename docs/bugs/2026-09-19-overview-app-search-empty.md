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

## Symptom

Type one character → application icons appear. Type another character or delete one → overlay **Searching…**, grid empty.

## Stock

`SearchResultsView.setTerms` sets `_startingSearch` and calls `_updateSearchProgress` immediately. Overlay is **Searching…** when `getFirstResult()` is null and something is still in progress.

`GridSearchResults.updateSearch` (`search.js` ~493) connects `notify::allocation`, may `get_laters()`, then `super.updateSearch`. `_getMaxDisplayedResults` (`~518`) uses `this.allocation.get_width()` **before** try/catch; `width === 0` → `maxResults` (6), else `columnsForWidth`. `getFirstResult` is `for (let child of this._grid)` skipping `!child.visible`.

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

Smoke types `f` then `fi` (does not abort on `after-f`); logs `_getMaxDisplayedResults`, `after-f` / `at-fi` / `after-fi` (`allocW`, `nCols`, `minW`, `statusBin`, `scroll`, `nGrid`).

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

`Actor.allocation` getter RPC vs last `allocate()` box. Landed `actor_allocation`; user: needle did not move. Nested `allocW` stays 0 (`set_width(1280)` included), so both terms use `width === 0` → 6. Live second-term empty is **not** “RPC unpack of the box”. Stock `columnsForWidth(1) === 0` while `minW=25`: a stored box in `(0, minW]` yields `maxResults=0` and the overlay; a 0 box does not. Local cache of that box would not move the needle.

## Reverted (2026-09-21)

Product-tree dumps from this bug were reverted (hang workaround, not a FAIL of the second-term miss):

- `Runtime.call_depth` / skip `before-update` during `call_poll`
- `Compositor.get_laters` client-local + `Compositor.override.vala` + `Meta.deny`
- `queue_relayout_rpc` / undeny `queue-relayout` signal

`actor_allocation` stays (named field; first query). It is **not** the second-term miss.

## Next (test area only)

Nested `after-fi` with `terms=["fi"]` is **not** empty (`10:04`). Live overlay still is. Next: FAIL that dies when `after-fi` has `terms=["fi"]` and `statusBin=true` / `nGrid=0` — that needs a non-zero `this.allocation` on the search display (`0 < allocW ≤ minW` → `nCols=0`). Do not wrap `overview.show()` (ec=133). Do not skip `columnsForWidth`. `coalesced-nested-request-gate` **PASS** after `Connection.on_input_ready` drain — that is the 09:23 start hang, not the overlay.
