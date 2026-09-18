# Hang after settle — git-bisect dissection (REJECTED)

**Status:** ❌ **REJECTED** (2026-09-18) — the hang is an **intermittent race**
(rare on old states, ~every-time at HEAD), so a revert / git-bisect scored by
pass/fail **cannot localise it** — a “no hang” is luck, not a fix. Approach
abandoned. Superseded by the smoke/debug dissection:
[`../2026-09-18-hang-after-settle-race.md`](../2026-09-18-hang-after-settle-race.md).

**Kept for reuse:** the file-level audit (Parts 1–2) and the **sync-RPC /
re-entrant-emit call-site table** (PIVOT section) — the new bug builds on those.

**Last known good:** `e1a7c46` — *“virtual desktop backgrounds working on
preview”* (user-corrected 2026-09-18; the earlier draft wrongly used
`fd1305b`).
**Broken (hang):** `8765ee3` — *“hang after settle”*.

**Commit chain (good → broken):**

```
e1a7c46  virtual desktop backgrounds working on preview   ← GOOD
ce4939e  app selection picker position vertically correct  ┐ newly in scope
fd1305b  mark next milestone - starting an app             ┘ (was mis-called good)
82fe136  broken build                                       (intermediate — ignore)
8765ee3  hang after settle                                  ← BROKEN
e9010e8  park disecting                                     (this bisect's WIP — ignore)
```

This audit diffs `e1a7c46..8765ee3` directly (intermediates `82fe136` and the
WIP `e9010e8` ignored).

**Why the base moved — key finding.** The first draft assumed `fd1305b` was
good and reverted only `fd1305b..8765ee3`. That state (committed as
`e9010e8`) **still hung**, so `fd1305b` is **not** good. That **exonerates the
`fd1305b..8765ee3` changes** (event relay / `App.vala` / search wrapper /
Clutter require) as the sole cause and **points the regression into
`e1a7c46..fd1305b`** — the **workarea / workspace re-emit corridor**.

**Method (user-directed):** audit only, **no agent testing**. Then bisect by
relevance: diff the working tree back to `e1a7c46` (**no checkout**), user
tests; re-apply groups **least-likely → most-likely** with a user test
between each, until the hang returns and names the culprit.

**Symptom / repro anchor (user 2026-09-18):** the hang fires **just before or
just after the IBus notification disappears**. A notification dismiss runs a
MessageTray **hide (Clutter transition → `stopped`)** and can recompute chrome
**regions / struts / workarea**. Both halves land on the **`Runtime.vala`
notification→signal re-emit** change: the `stopped` case *and* the new generic
`default` `emit_by_name`.

---

## ⚠️ PIVOT (user 2026-09-18): intermittent race — analyse from HEAD

**The hang is INTERMITTENT.** It fired sometimes even on older/“good” states;
at **HEAD it is near-deterministic** (“pretty much every time”). So the change
did not *introduce* the hang — it **widened an existing race** until it is
almost always hit.

**Why the revert-bisect is parked.** A pass/fail bisect is unreliable here: a
“no hang” result can be luck, not a fix. All prior results are consistent with
a race, not a single culprit chunk:

| State | E code | R2 code | Result |
| ----- | :----: | :-----: | ------ |
| `e1a7c46` (base) | ✗ | ✗ | intermittent (rare) — **T0 confirm pending** |
| step 2 / `e9010e8` | ✓ | ✗ | hangs |
| **T1** (`8765ee3` − E) | ✗ | ✓ | hangs |
| `8765ee3` (HEAD tip) | ✓ | ✓ | **every time** |

**Leading hypothesis — cross-process re-entrant sync-RPC deadlock.** Both
`ce4939e` (E) and R2 each **add more “synchronous RPC / blocking emit invoked
from inside a signal / vfunc / notification handler” call sites.** More sites →
higher odds that the client is blocked in a sync call while the server is
blocked mid-emit awaiting the client’s reply (or vice-versa) → deadlock. That
is exactly “intermittent, additive, ~100 % once enough sites exist.”

**Working base for analysis:** the tree is now restored to **`8765ee3`** (the
reliable-hang tip), built. Analyse here where the hang is deterministic.

### Sync-RPC / re-entrant-emit call sites to inspect (static, from the diffs)

| # | Site | File | Shape |
| - | ---- | ---- | ----- |
| 1 | `Helper-Actor.add_hook` at init | `shell-gi/Global.vala` | **sync** `call_value` during `initialize` |
| 2 | key `measure_event` → `hook.emit` | `rpc/helper/LayoutHooks.vala` (server, via `ClutterActor.add_hook` connect) | **blocking** emit from a key signal handler |
| 3 | `set_builtin_struts` → RPC **+** `emit "workareas-changed"` | `gi-stub/overrides/Workspace.override.vala` (E) | sync RPC then re-entrant client emit → GJS relayout |
| 4 | notification generic `default` re-emit | `gi-stub/Runtime.vala` (E) | `emit_by_name(proxy, method)` inside notification dispatch |
| 5 | `get_current_event` | `gi-stub/overrides-clutter/Clutter.override.vala` + `rpc/helper/Clutter.vala` | **sync** client→server round-trip during event handling |
| 6 | `relay_event` emits key-press/-release | `gi-stub/overrides-clutter/Actor.override.vala` | client emit that can trigger (5) |

**Deadlock to look for at the hang:** client thread blocked in a sync
`call_value`/`hook.emit` waiting for a reply, while the server thread is
blocked inside a vfunc/hook emit waiting for the client (or the client’s main
loop is not pumping because it is inside a signal handler). Confirm with paired
backtraces of **both** processes captured at the hang, or last-in-flight RPC id
on each side from the debug logs.

### Runtime evidence to capture (user runs; agent does not test)

- `~/.cache/gnome-shell-rpc/{org.gnome.ShellRpc,mutter-rpc}.debug.log` — last
  RPC method + id on each side at freeze.
- `gdb -p` (or `gcore`) on **both** the client and `mutter-rpc` at the hang →
  paired backtraces; look for a sync send waiting on a recv on both.

---

---

## Part 1 — Full audit of every changed file (`e1a7c46..8765ee3`)

32 files. Grouped by origin region and role. **Region R1** = `e1a7c46..fd1305b`
(newly in scope). **Region R2** = `fd1305b..8765ee3` (earlier draft's scope —
now exonerated as sole cause).

| # | File | Region | Role | Runtime? |
| - | ---- | :----: | ---- | :------: |
| 1 | `docs/bugs/2026-09-16-chrome-panel-menus-overlay.md` | R1 | notes | 🚫 |
| 2 | `docs/plans/0.8-init-complete-and-interaction.md` | R1/R2 | plan | 🚫 |
| 3 | `docs/plans/1.0-run-to-end.md` | R2 | plan | 🚫 |
| 4 | `scripts/nested-weston-prove.sh` | R1/R2 | prove pattern | 🚫 |
| 5 | `g-ir-cpp-866kemf0.c` | R2 | stray scanner temp | 🚫 |
| 6 | `src/gjs-embed/app-search-smoke.js` | R2 | smoke (GI_META_SMOKE only) | 🚫 |
| 7 | `src/gjs-embed/workarea-panel-chrome-smoke.js` | R1 | smoke (GI_META_SMOKE only) | 🚫 |
| 8 | `src/gjs-embed/workarea-panel-inset-smoke.js` | R1 | smoke (GI_META_SMOKE only) | 🚫 |
| 9 | `src/shell-js-probe/ui/main.js` | R1 | probe overlay (only under `GI_RPC_JS_OVERRIDE_DIR`) | ⚠️ probe-only |
| 10 | `tests/gstrv-gir-gate/README.md` | R2 | test gate | 🚫 |
| 11 | `tests/gstrv-gir-gate/app-system.c` | R2 | test gate | 🚫 |
| 12 | `tests/gstrv-gir-gate/app-system.h` | R2 | test gate | 🚫 |
| 13 | `tests/gstrv-gir-gate/check.js` | R2 | test gate | 🚫 |
| 14 | `tests/gstrv-gir-gate/check.sh` | R2 | test gate | 🚫 |
| 15 | `tests/gstrv-gir-gate/meson.build` | R2 | test gate | 🚫 |
| 16 | `tests/meson.build` | R2 | subdir test gate | 🚫 |
| 17 | `src/gi-stub-gen/Meta.deny` | R1 | **deny `Workspace.set_builtin_struts`** (use hand override) | ✅ gen |
| 18 | `src/gi-stub/overrides/Workspace.override.vala` | R1 | **NEW** `set_builtin_struts` → RPC + **emit `Display::workareas-changed`** | ✅ client |
| 19 | `src/gi-stub/overrides/Meta.override.vala` | R1 | `get_display()` → **`ensure_signal_subscribe(display,"workareas-changed")`** | ✅ client |
| 20 | `src/gi-stub/Runtime.vala` | R1**+**R2 | R1: notification handler → `switch` with **generic `default` re-emit** of any subscribed signal. R2: `key-press-event` case | ✅ client |
| 21 | `src/meson.build` | R1**+**R2 | R1: +`Workspace.override.vala`. R2: +`app-system-search.c` +gio deps | ✅ build |
| 22 | `src/gi-stub/overrides-clutter/Actor.override.vala` | R2 | relay_event: keyval + emit key-press/-release | ✅ client |
| 23 | `src/gi-stub/overrides-clutter/Clutter.override.vala` | R2 | `get_current_event`: keyval slot | ✅ client |
| 24 | `src/rpc/helper/Clutter.vala` | R2 | `get_current_event`: pack keyval | ✅ server |
| 25 | `src/rpc/helper/ClutterActor.vala` | R2 | `add_hook`: connect key_press/release on raw actor | ✅ server |
| 26 | `src/rpc/helper/LayoutHooks.vala` | R2 | `measure_event`: raw actor + keyval | ✅ server |
| 27 | `src/shell-client/ShellApplication.vala` | R2 | `require("Clutter","16")` | ✅ client |
| 28 | `src/shell-gi/App.vala` | R2 | big rewrite — ArrayList + sort + launch surface | ✅ lib |
| 29 | `src/shell-gi/AppSystem.vala` | R2 | remove Vala `search` | ✅ lib |
| 30 | `src/shell-gi/Global.vala` | R2 | init: stage `event` hook + sync `Helper-Actor.add_hook` | ✅ lib |
| 31 | `src/shell-gi/app-system-search.c` | R2 | NEW C GStrv `search` wrapper | ✅ lib |
| 32 | `src/shell-gi/app-system-search.h` | R2 | header | ✅ lib |

---

## Part 2 — Audit of the relevant (compiled / generated) files only

Docs, tests, smokes, probe overlay, prove-pattern and the stray
`g-ir-cpp-*.c` excluded. Grouped E, A, B, C, D.

### E. Workarea / workspace re-emit corridor  ·  **region R1 — prime suspect**

- **`src/gi-stub/overrides/Workspace.override.vala`** (NEW) —
  `set_builtin_struts` marshals the strut list, calls
  `Meta-Workspace.set_builtin_struts` over RPC, then **manually
  `GLib.Signal.emit_by_name(display, "workareas-changed")`** on the client
  display. Stock mutter fires `workareas-changed` internally; here it is
  re-emitted client-side after the RPC. GJS `ControlsManagerLayout` refreshes
  `_workAreaBox` on that signal — if that refresh path re-enters strut/relayout
  it is a **re-entrant signal loop → hang**.
- **`src/gi-stub/overrides/Meta.override.vala`** — `get_display()` now
  `ensure_signal_subscribe(display,"workareas-changed")`. Its own comment:
  *“not in Display construct (nested RPC during parse hung the chrome
  smoke)”* — **documented prior hang in this exact corridor.**
- **`src/gi-stub/Runtime.vala`** (R1 hunk) — notification handler rewritten to
  a `switch`; the new **`default` case generically `emit_by_name(proxy,
  notif.method)`** for every subscribed signal. Broadens what a server
  Notification can drive on the client — the delivery half of the
  `workareas-changed` loop above.
- **`src/gi-stub-gen/Meta.deny`** — deny generated
  `Workspace.set_builtin_struts` so the hand override (with the extra emit) is
  used.
- **`src/meson.build`** (R1 hunk) — add `Workspace.override.vala`.

### A. Keyboard-event relay corridor  ·  region R2 (exonerated as sole cause)

`Global.vala` init hook (`callback_bind` + sync `Helper-Actor.add_hook` on
`instance.stage`); `ClutterActor.add_hook` connects `key_press/release_event`
→ blocking `LayoutHooks.measure_event` emit; `Actor.override`/`Clutter.override`
keyval; `Runtime.vala` R2 `key-press-event` case; `Clutter.vala` keyval pack.

### B. `Shell.App` launch/running surface  ·  region R2

`App.vala`: `GLib.List` → `Gee.ArrayList`, `window_sort_stale`, sorting
`get_windows` (queries `workspace_manager` / `user_time`), `activate*` /
`launch*` / `open_new_window` / `can_open_new_window` / `activate_window` /
`request_quit`.

### C. `AppSystem.search` C GStrv wrapper  ·  region R2

Remove Vala `search`; add `app-system-search.c/.h`; `src/meson.build` R2 hunk
(+C source, +`gio-2.0`/`gio-unix-2.0`).

### D. Client typelib require  ·  region R2

`ShellApplication.vala`: `require("Clutter","16",0)` (warn on fail).

---

## Part 3 — Unlikely candidates (compiled but implausible as the hang)

- **🔷 C (search wrapper)** — library/GIR only; nothing on the settle path
  calls `search`. A bad GStrv shape crashes/`METHOD_NOT_FOUND`, not hangs.
- **🔷 D (Clutter require)** — startup-only; failure warns.
- **🔷 Keyval packing** (subset of A) — additive, guarded wire fields.
- **🔷 All of region R2 as the *sole* cause** — reverting R2 alone
  (`e9010e8`) still hung. R2 may still contribute but is not the primary.

## Part 4 — Least-likely → most-likely chunks (the outage ladder)

Re-apply in this order after the full revert; the group that reintroduces the
hang is the culprit. Ranking updated for the new base + the `e9010e8`
still-hangs finding.

| Rank | Group | Region | Why (for a *hang after settle*) |
| ---- | ----- | :----: | ----- |
| 0 (irrelevant) | Docs, `tests/**`, all `gjs-embed` smokes, `shell-js-probe/ui/main.js`, prove pattern, stray `g-ir-cpp` | R1/R2 | Not in a normal running binary; smokes/probe only under their env flags. |
| 1 (lowest) | **C** — search C wrapper + meson gio deps | R2 | GIR only; exonerated by `e9010e8`. |
| 2 | **D** — client `require("Clutter","16")` | R2 | startup-only; exonerated. |
| 3 | Keyval **packing** widen (part of A) | R2 | additive fields; exonerated. |
| 4 | **B** — `App.vala` rewrite | R2 | activation/window-change path; exonerated by `e9010e8`. |
| 5 | **A** — event-relay corridor (remainder) | R2 | structural per-event round-trip, but present in `e9010e8` which still hung. |
| 6 (highest) | **E** — workarea/workspace re-emit: `Workspace.override.set_builtin_struts` **emit `workareas-changed`** + `Meta.override` subscribe + `Runtime.vala` generic `default` re-emit + `Meta.deny` | R1 | **Only region NOT reverted in `e9010e8`** (which still hung). Manual `Display::workareas-changed` re-emit after an RPC → GJS `_workAreaBox` refresh → potential **re-entrant strut/relayout loop**. Code comment already records a hang in this corridor. **Prime suspect.** |

**Prime suspect:** group **E** (rank 6) — the `set_builtin_struts` →
`workareas-changed` re-emit and the generic `Runtime.vala` re-emit `default`.

---

## Targeted bisect — ⏸️ PARKED (intermittent race; see PIVOT above)

> Kept for the record. Pass/fail results below are **unreliable** — a “no
> hang” may be luck, not a fix. Do not resume unless we get a deterministic
> per-chunk signal.

**Per-commit finding:** `ce4939e` is the **only code commit** in
`e1a7c46..fd1305b` — it carries the *entire* group **E** (Runtime re-emit +
`Meta.override` subscribe + new `Workspace.override.set_builtin_struts` +
`Meta.deny` + meson). `fd1305b` is **docs-only** (one plan file). So the
regression code is 100 % `ce4939e`. **User:** `ce4939e` (the commit right after
good) is **bad**, tested earlier.

**Strategy:** apply the **whole broken set (`8765ee3`) except `ce4939e`'s
significant code (E)**; user tests. If no hang → culprit is inside **E** →
bisect within E (T2). Then re-apply what we couldn't (T3).

| Step | State | Applied | Built | Test | Notes |
| ---- | ----- | :-----: | :---: | :--: | ----- |
| T1 | broken `8765ee3` **minus group E** | ✔️ | ✔️ | ❌ | **still hangs** (user 2026-09-18) → **group E is NOT the sole cause** |
| **T0** | **full revert to `e1a7c46`** (confirm the baseline itself is clean) | ✔️ | ✔️ | ⏳ | **← we are here** — awaiting user test of the true good commit |

### ⚠️ New inference after T1 ❌

- **T1** (E reverted, **R2 present**) still hangs → a cause lives in **R2**
  (`fd1305b..8765ee3`: event relay A / `App.vala` B / search C / Clutter req D).
- Earlier, step 2 / `e9010e8` (**E present**, R2 reverted) also hung → a cause
  lives in **E** too.
- So either there are **two independent regressions** (one in E, one in R2), or
  the shared base `e1a7c46` is **not actually clean**. **T0 settles it:** if
  `e1a7c46` is hang-free, we have two fronts; if it hangs, the good point is
  older. Do not re-apply anything until T0 is confirmed.

**T1 applied (working-tree diff only; HEAD stays `e9010e8`):**
- **Kept at broken `8765ee3`:** group A (event relay), B (`App.vala`),
  C (`AppSystem.search` C wrapper), D (Clutter require), and all irrelevant.
- **Reverted to good `e1a7c46`:** `Runtime.vala`, `Meta.override.vala`,
  `Meta.deny`; **deleted** `Workspace.override.vala`; dropped its `meson.build`
  line.

**T1 couldn't apply (depends on E):** the `Runtime.vala` `key-press-event`
notification case (R2/group A) lives *inside* `ce4939e`'s `switch`; reverting
`Runtime.vala` to `e1a7c46` drops it. Revisit in **T3** (re-add on top of a
minimal E, or as a standalone `if`).

---

## Fallback — full least→most ladder (if the targeted split is inconclusive)

GOOD = `e1a7c46`, BROKEN = `8765ee3`. Working-tree diff only (**no checkout**;
HEAD stays `e9010e8`). Each step is cumulative on the previous. **Agent**
applies + builds; **user** tests. Tick `Test`: ✔️ no hang · ❌ hang · ⏳ awaiting.

| Step | Applies (cumulative) | Applied | Built | Test | Notes |
| ---- | ------- | :-----: | :---: | :--: | ----- |
| 1 | **Full revert** to `e1a7c46` | ☐ | ☐ | ☐ | expect: no hang |
| 2 | **rank 0** — docs / tests / smokes / probe / prove / stray | ☐ | ☐ | ☐ | ← user will call this first |
| 3 | **rank 1 (C)** — search wrapper + meson gio | ☐ | ☐ | ☐ | |
| 4 | **rank 2 (D)** — client Clutter require | ☐ | ☐ | ☐ | |
| 5 | **rank 3** — keyval packing | ☐ | ☐ | ☐ | |
| 6 | **rank 4 (B)** — `App.vala` | ☐ | ☐ | ☐ | |
| 7 | **rank 5 (A)** — event relay | ☐ | ☐ | ☐ | |
| 8 | **rank 6 (E)** — workarea/workspace re-emit | ☐ | ☐ | ☐ | *expected to reintroduce the hang* |

---

## Not this / guardrails

- **🚫** No testing by the agent — user runs every prove.
- **🚫** No `git checkout` of a commit / no moving HEAD — working-tree diff only.
- **🚫** No invented GI methods while re-shaping (stubs mirror real symbols).
- **ℹ️** `Runtime.vala` and `src/meson.build` carry hunks in **both** regions;
  they are split per-group when applied (E hunks vs A/C hunks).
- **ℹ️** After each apply the agent may `ninja -C build`, then stop for the
  user’s test.
