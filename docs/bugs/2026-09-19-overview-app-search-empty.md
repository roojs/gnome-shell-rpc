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

Smoke types `f` then `fi`; logs `_getMaxDisplayedResults width= n=`, `after-f` / `after-fi` (`allocW`, `nCols`, `status`, `nGrid`, `updateSearchErr`).

**2026-09-20 11:59 prove:** `hook` then hang. Client sent `Meta-Compositor.get_laters` id=565 during `main.start` → `XdndHandler` → `LayoutManager._updateRegions`; no reply until SIGKILL (~48s). Aftermath `laters is null`. Live hold session gets past start (user can type).

**2026-09-20 12:11 prove** (local `Compositor.get_laters`): reached snapshots. `after-f`: `nGrid=6` `first=true` `allocW=0` `nCols=0` `status="Searching?"` `displayMapped=false` `overview.visible=false` (typed before overview). `_getMaxDisplayedResults width=0 n=6`. `after-fi`: `text=""` `terms=[]` `nGrid=0` `status="No results"` `miss text-changed` (`textChangedN=3`) — search reset, not the live second-term.

**2026-09-20 08:24 prove:** wait `startup-complete` hung 60s (`ensureAllocation` in `ControlsManager.runStartupAnimation`). `main.start()` does not wait that signal. Do not block the smoke on it.

**2026-09-21 08:50 prove:** died in the smoke: `FAIL start TypeError: main.overview.controls is undefined`. Did not reach `after-f` / `after-fi`. That wrap is removed.

## What is not the second-term miss

`Actor.allocation` getter RPC vs last `allocate()` box. Landed `actor_allocation`; user: needle did not move. First query still works via `width === 0` → 6 hits. That property is why the first query works, not why the second fails.

## Reverted (2026-09-21)

Product-tree dumps from this bug were reverted (hang workaround, not a FAIL of the second-term miss):

- `Runtime.call_depth` / skip `before-update` during `call_poll`
- `Compositor.get_laters` client-local + `Compositor.override.vala` + `Meta.deny`
- `queue_relayout_rpc` / undeny `queue-relayout` signal

`actor_allocation` stays (named field; first query). It is **not** the second-term miss.

## Next (test area only)

Out-of-tree Vala `tests/call-sync-repro/notif-nested-call-gate` (08:28 `set_width` / `before-update` / nested `get_children`): nested calls are `Client.pending` + the connection read watch, not `emit_wait_poll` in the handler. Reply after the Notification (queue/watch): **PASS**. Blocking the handler with `usleep`: **FAIL** (watch cannot run). `emit_wait_poll` in outer was the wrong replica “fix”.
