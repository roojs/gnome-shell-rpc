# Hang after settle — regression since `fd1305b`

**Status:** ⏳ open — regression. Nested session **hangs after settle**.

**Last known good:** `fd1305b` — *“mark next milestone - starting an app”*.
**First bad (current HEAD):** `8765ee3` — *“hang after settle”*
(intermediate `82fe136` *“broken build”* is **ignored** — this audit diffs
`fd1305b..HEAD` directly).

**Method (user-directed):** audit only, **no testing**. Then bisect by
relevance: **diff back** the working tree to `fd1305b` (not a checkout),
user tests; then re-apply groups **least-likely → most-likely** with a user
test between each, until the hang returns and names the culprit.

---

## Part 1 — Full audit of every changed file (`fd1305b..HEAD`)

25 files, +811 / −101. Grouped by role.

| # | File | ± | Role | Runtime-relevant? |
| - | ---- | -- | ---- | ----------------- |
| 1 | `docs/plans/0.8-init-complete-and-interaction.md` | 1/1 | plan note | 🚫 no |
| 2 | `docs/plans/1.0-run-to-end.md` | 15/5 | plan S.27/S.28 | 🚫 no |
| 3 | `scripts/nested-weston-prove.sh` | 1/1 | prove: add `app-search-smoke: ok` to OK pattern | 🚫 no (harness) |
| 4 | `g-ir-cpp-866kemf0.c` | 4/0 | **stray** g-ir-scanner temp file committed to repo root | 🚫 no (not in build) |
| 5 | `tests/gstrv-gir-gate/README.md` | 11/0 | new gate doc | 🚫 no |
| 6 | `tests/gstrv-gir-gate/app-system.c` | 46/0 | new GStrv GIR gate | 🚫 no (test) |
| 7 | `tests/gstrv-gir-gate/app-system.h` | 13/0 | new GStrv GIR gate | 🚫 no (test) |
| 8 | `tests/gstrv-gir-gate/check.js` | 19/0 | new GStrv GIR gate | 🚫 no (test) |
| 9 | `tests/gstrv-gir-gate/check.sh` | 27/0 | new GStrv GIR gate | 🚫 no (test) |
| 10 | `tests/gstrv-gir-gate/meson.build` | 35/0 | new GStrv GIR gate | 🚫 no (test) |
| 11 | `tests/meson.build` | 1/0 | subdir the new gate | 🚫 no (test) |
| 12 | `src/gjs-embed/app-search-smoke.js` | 171/0 | new smoke (runs only under `GI_META_SMOKE`) | 🚫 no (smoke-only) |
| 13 | `src/shell-gi/app-system-search.c` | 30/0 | new C GStrv wrapper for `search` | ✅ compiled |
| 14 | `src/shell-gi/app-system-search.h` | 10/0 | header for the C wrapper | ✅ compiled |
| 15 | `src/shell-gi/AppSystem.vala` | 0/8 | remove Vala `search` (moved to C) | ✅ compiled |
| 16 | `src/meson.build` | 5/0 | add C wrapper + `gio-2.0` / `gio-unix-2.0` to `shell_gi_lib` | ✅ build graph |
| 17 | `src/shell-client/ShellApplication.vala` | 5/0 | client: `require("Clutter","16")` at startup | ✅ compiled (client) |
| 18 | `src/shell-gi/App.vala` | 322/71 | **big rewrite** — launch surface + `Gee.ArrayList` windows + sort | ✅ compiled |
| 19 | `src/shell-gi/Global.vala` | 28/0 | **init:** bind stage `event` callback + sync `Helper-Actor.add_hook` | ✅ compiled |
| 20 | `src/gi-stub/Runtime.vala` | 8/0 | client: re-emit `key-press-event` notification to proxies | ✅ compiled (client) |
| 21 | `src/gi-stub/overrides-clutter/Actor.override.vala` | 22/4 | client relay_event: keyval arg + emit key-press/-release | ✅ compiled (client) |
| 22 | `src/gi-stub/overrides-clutter/Clutter.override.vala` | 6/1 | client `get_current_event`: read keyval slot | ✅ compiled (client) |
| 23 | `src/rpc/helper/Clutter.vala` | 3/3 | Helper `get_current_event`: pack keyval (`idddu`→`iddduu`) | ✅ compiled (server) |
| 24 | `src/rpc/helper/ClutterActor.vala` | 24/4 | Helper `add_hook`: connect `key_press/release_event` on raw actor | ✅ compiled (server) |
| 25 | `src/rpc/helper/LayoutHooks.vala` | 4/3 | Helper `measure_event`: raw `Clutter.Actor` + pack keyval | ✅ compiled (server) |

---

## Part 2 — Audit of the relevant (compiled) files only

Test files, smoke JS, docs, the prove-script pattern, and the stray
`g-ir-cpp-*.c` are excluded. The Vala/C that actually links into the running
`shell-gi` / server (`mutter-rpc`) / client (`gnome-shell-rpc`) binaries:

### A. Keyboard-event relay corridor (spans server + client + init)

- **`src/shell-gi/Global.vala`** — in the singleton `initialize`, after
  `instance = new Global(display)`, it now:
  - computes `Clutter.Actor.event` vfunc offset,
  - `callback_bind`s a client-side trampoline that rebuilds a
    `Clutter.Event.from_local(...)` and `Signal.emit_by_name` on
    `instance.stage` for `key_press`/`key_release`,
  - fires **synchronous** `GnomeShellRpc.call_value("Helper-Actor.add_hook",
    instance.stage, args("it", event_vfunc_id, event_hook_id))` at init.
- **`src/rpc/helper/ClutterActor.vala`** — `add_hook` gained a new branch:
  when the lease is **not** a Helper `Actor` peer but a raw `Clutter.Actor`
  and `vfunc_id == ActorVfuncIds.event_id`, it `.connect`s
  `key_press_event` / `key_release_event`, each calling
  `LayoutHooks.measure_event(hook, clutter_actor, ev)` and returning `false`.
- **`src/rpc/helper/LayoutHooks.vala`** — `measure_event` now takes a
  `Clutter.Actor` (was Helper `Actor`) and packs an extra `get_key_symbol()`
  into the emit (`tiddu`→`tidduu`). Emit is a **blocking round-trip**
  (reads `hook.reply_args`).
- **`src/rpc/helper/Clutter.vala`** — `get_current_event` packs keyval
  (`idddu`→`iddduu`).
- **`src/gi-stub/overrides-clutter/Actor.override.vala`** — client
  `relay_event` reads the keyval slot and, after the vfunc relay, emits
  `key-press-event` / `key-release-event` on `this`.
- **`src/gi-stub/overrides-clutter/Clutter.override.vala`** — client
  `get_current_event` reads the keyval slot (guarded `size > 5`).
- **`src/gi-stub/Runtime.vala`** — client Notification handler: new
  `key-press-event` case re-emits on the matching proxy.

### B. `Shell.App` launch/running surface (S.27)

- **`src/shell-gi/App.vala`** — windows storage `GLib.List<Meta.Window>` →
  `Gee.ArrayList<Meta.Window>` with a `window_sort_stale` flag; `get_windows`
  now **sorts** (queries `Global.get().workspace_manager.get_active_workspace()`,
  per-window `showing_on_its_workspace` / `user_time`) and filters
  override-redirect; `id` / `get_name` / `icon` reworked; `activate_action`
  rewritten to build a startup-id platform dict; **new** `activate`,
  `activate_full`, `launch`, `launch_action`, `open_new_window`,
  `can_open_new_window`, `activate_window`, `request_quit`.

### C. `AppSystem.search` C GStrv wrapper (S.27 support)

- **`src/shell-gi/AppSystem.vala`** — remove Vala `search` static method.
- **`src/shell-gi/app-system-search.c` / `.h`** — C `shell_app_system_search`
  wrapping `g_desktop_app_info_search`, UTF-8-scrubbing results.
- **`src/meson.build`** — add the C source to `shell_gi_lib` + `gio-2.0` /
  `gio-unix-2.0` deps.

### D. Client typelib require

- **`src/shell-client/ShellApplication.vala`** — `require("Clutter","16",0)`
  (warn on failure) before resource register.

---

## Part 3 — Unlikely candidates (compiled but implausible as the hang)

- **🔷 C. `AppSystem.search` C wrapper + meson deps** — pure library/GIR
  surface. Only invoked by the search smoke; adding `gio-*` deps and a C file
  changes the typelib shape (`search`) but nothing on the settle path calls
  it. A wrong GStrv shape would crash/`METHOD_NOT_FOUND`, not **hang**.
- **🔷 D. Client `require("Clutter","16")`** — one extra typelib require at
  client startup. Failure only warns; it cannot block after settle.
- **🔷 Keyval-only packing widening** (`Clutter.vala` / `Clutter.override.vala`
  / the keyval slot reads) — additive `uu`/`size>5`-guarded fields. On their
  own they change payload width, not control flow; unlikely to hang.

## Part 4 — Least-likely → most-likely chunks (the outage ladder)

Ordered for the bisect. Re-apply in this order after the full revert; the
group that reintroduces the hang is the culprit.

| Rank | Chunk | Why (relevancy to a *hang after settle*) |
| ---- | ----- | ----- |
| 0 (irrelevant) | Docs, `tests/**`, `app-search-smoke.js`, `nested-weston-prove.sh` pattern, stray `g-ir-cpp-866kemf0.c` | Not linked into any running binary; smoke runs only under `GI_META_SMOKE`. Cannot affect a plain settle. |
| 1 (lowest) | **C** — `AppSystem.search` C wrapper + `src/meson.build` gio deps | Library/GIR only; nothing on the settle path calls `search`. |
| 2 | **D** — client `require("Clutter","16")` in `ShellApplication.vala` | Startup-only; failure warns, does not block. |
| 3 | Keyval **packing** widen (`Clutter.vala`, `Clutter.override.vala`, keyval slot reads in `Actor.override.vala`) | Additive fields; changes wire width, not loop/control flow. |
| 4 | **B** — `App.vala` rewrite (ArrayList + `get_windows` sort querying `workspace_manager` / `user_time`, launch methods) | Runs on activation / window-change, and `get_windows` sort touches compositor state. Could stall *if* something polls it after settle, but not obviously a hang by itself. |
| 5 (highest) | **A** — keyboard-event relay corridor: `Global.vala` init hook (`callback_bind` + **sync** `Helper-Actor.add_hook` on `instance.stage`) + `ClutterActor.vala` `.connect(key_press/release_event)` → **blocking** `LayoutHooks.measure_event` emit per event + `Actor.override`/`Runtime.vala` re-emit | New **synchronous per-event RPC round-trip** wired onto the stage at init, plus client-side re-emit of `key-press-event`. Prime suspect for a **hang**: a blocking emit inside a compositor signal handler and/or a signal re-entrancy loop between server relay and client re-emit is exactly the shape that stalls after the session settles. |

**Prime suspect:** group **A** (rank 5), specifically the
`Global.vala` init `add_hook` + `ClutterActor.add_hook` signal-connect +
`LayoutHooks.measure_event` blocking emit.

---

## Bisect plan — progress tracker (apply diffs only; user tests between each)

Working-tree diff only (**no checkout**, HEAD stays `8765ee3`). Each step is
cumulative on top of the previous. **Agent** applies + builds; **user** tests.
Tick `Test` per row: ✔️ no hang · ❌ hang · ⏳ awaiting user.

| Step | Applies | Applied | Built | Test | Notes |
| ---- | ------- | :-----: | :---: | :--: | ----- |
| 1 | **Full revert** to `fd1305b` | ✔️ | ✔️ | ⏭️ | skipped separate test — user jumped to step 2 |
| 2 | **rank 0** — docs / `tests/**` / smoke / prove-pattern / stray `g-ir-cpp` | ✔️ | ✔️ | ⏳ | **← we are here** (build OK, awaiting user test) |
| 3 | **rank 1 (C)** — `AppSystem.search` C wrapper + `src/meson.build` gio deps | ☐ | ☐ | ☐ | |
| 4 | **rank 2 (D)** — client `require("Clutter","16")` | ☐ | ☐ | ☐ | |
| 5 | **rank 3** — keyval packing widen | ☐ | ☐ | ☐ | |
| 6 | **rank 4 (B)** — `App.vala` rewrite | ☐ | ☐ | ☐ | |
| 7 | **rank 5 (A)** — event-relay corridor | ☐ | ☐ | ☐ | *expected to reintroduce the hang* |

---

## Not this / guardrails

- **🚫** No testing by the agent — user runs every prove.
- **🚫** No `git checkout` / no moving HEAD — working-tree diff only.
- **🚫** No invented GI methods while re-shaping (stubs mirror real symbols).
- **ℹ️** After each apply the agent may `ninja -C build` (reconfigures if
  `meson.build` changed), then stop for the user’s test.
