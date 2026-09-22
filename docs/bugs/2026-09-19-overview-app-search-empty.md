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

## Next

Live (user): type `ter` → icons. Type `m` **or wait** → **Searching…** and it **never comes back**. Overlay is **still open**. Do **not** reintroduce “never shrink allocation” on every actor — that crashed the clock (see chrome bug).

**Handoff 2026-09-21 ~15:53** — pick up here. Session was search → clock regression → GLSLEffect → leftover D-Bus. Search product miss is unchanged.

## Symptom

Type `ter` → application icons. Type `m` or wait a bit → overlay **Searching…**, grid empty, **stays that way**.

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

RPC unpack of the allocation box (user 2026-09-21: that getter did not move the live needle). `-Infinity` / width `0` (those use `_maxResults` 6). Remote D-Bus taking ~25s (icons stay in nested, overlay hidden). Nested extra-key / `term` keeps icons; nested wait often `notifyN=0`. Live wait **or** second key empties the grid.

A later-frame box in `(0, minW]` after a wide grid **would** make stock `columnsForWidth` return 0 → `maxResults=0` → hide/clear → overlay. That is still a plausible stock path. It is **not** a license to never-shrink every actor’s cache (user: crashed the clock; not a real fix).

## 2026-09-21 — what we tried, what we rolled back

Worked this ticket, then the clock regression it caused. Chrome details: [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md) (clock row + GLSLEffect). D-Bus leftovers: [`weston-nested-test-env.md`](../weston-nested-test-env.md).

| Attempt | What happened | Now |
| --- | --- | --- |
| `Clutter.Actor.allocation` GObject getter (skip `-Infinity` / empty, copy finite mutter width) | Needed so `this.allocation.get_width()` is not always the cache of 0. First query can use the `width === 0` → 6 shortcut. **Did not** stop live Searching… | **Keep** — `Actor.override.vala` getter. Coding standards: `var w`, early return, no `bool` flag temps |
| `allocate()` always stores `actor_allocation = box` | Matches mutter’s last box | **Keep** |
| Synthetic `display.allocate(1px)` in `app-search-smoke.js` after `ter` | Forced FAIL `maxResults-zero` in nested. User: not the live miss (“something tells a search grid it is only one pixel wide” is a smoke toy, not a fix) | Smoke still **has** that `allocate w=1` probe (~line 493). Do **not** treat a PASS of that as the live bar. Do **not** ship 1px as product |
| “Do not shrink a usable cache” on **every** `allocate` / getter (keep 792px if later box is 1px) | Nested smoke `maxResults-zero` went away. User: not a real fix. **Crashed clock / date menu.** Also violated coding standards (`bool new_ok` / `cached_ok`, no braces) | **Reverted 2026-09-21.** Do not put it back |
| Host `ShellApplication` `Bin.register("Shell-GLSLEffect", typeof(Shell.GLSLEffect))` after `Runtime.register()` | Unblocked `get_effect` unpack so `dateMenu.menu.open(0)` no longer 133’d. User: “this looks unlikely” — wrong layer, try/catch, one-off | **Removed.** **Not** this search ticket |
| `GLSLEffect` `static construct { Bin.register(...) }` | User: not a valid way | **Removed** |
| `GLSLEffect.rpc_register()` from `Global.bind_display` | User: one place calls all of these | **Removed** |
| Helper `Bin.register("Shell-GLSLEffect")` / client `shell_register` to unpack it | User: Shell GLSLEffect is never on the server. Compositor peer is `Clutter-OffscreenEffect` + `register_handle` | See chrome [`2026-09-21-shell-glsleffect-bin-alias.md`](2026-09-21-shell-glsleffect-bin-alias.md). **Not** this search ticket |
| Click then `isOpen` in date-menu smoke | `fire_button_press` after `open()` toggles **closed** (`ok isOpen=false`). Click-no-open is an old probe miss | Smoke is **open-only**. Live click still the user’s score |
| Idle / timeout / vendor `search.js` as product fix | Forbidden on this ticket | Stay forbidden |

**Still in tree that is not the search fix:** `app-search-smoke.js` 1px allocate after icons; `date-menu-open-smoke.js` (chrome). Allocation getter still skips non-finite mutter width so the first query is not poisoned.

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

See **Next** at the top. Live second-term Searching… is the bar. Nested `after-fi` without overview is still `SearchController.reset`. `coalesced-nested-request-gate` is the 09:23 start hang, not the overlay. Clock click is the chrome bug, not a search FAIL.
