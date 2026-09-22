# Search result click does not spawn the application

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
> repeat. **Prove-first** in the **test area** (`src/gjs-embed/`,
> `app-search-launch-smoke.js`) — **no** speculative stub / Helper / deny /
> `Shell.App` / Event / vendor JS thrash on the main tree. **No**
> `GLib.idle_add` / Idle / defer. No layout.js ship hacks.
>
> ## 🚫 Do not invent shit in this tree
>
> **User call 2026-09-16:** a stack frame / Class-offset theory / “same as
> Transition” pattern is **not** a license to dump Helper methods, local
> GValue caches, deny lists, or ABI “fixes” into `src/`. That is wasting
> everyone’s time and polluting the codebase.
>
> Required order — **no exceptions**:
>
> 1. Reproduce on stay-up (user live + nested). File the miss here (`miss L1`
>    / `L2` / `L3` or log frame).
> 2. **`app-search-launch-smoke`** must FAIL on **that** miss — not PASS
>    while live click-to-launch still dead.
> 3. Only then a **minimal** change that makes **that** smoke step PASS.
> 4. Re-run prove / stay-up. New miss → update this bug and go to (2). Do
>    **not** invent the next subsystem in the same turn.
>
> **Forbidden:** Helper `set_relay_*` / kind switches / local caches /
> “while we’re here” deny expansions / renaming half the tree to match a
> theory — before a FAIL smoke names the fix. Revert speculative dumps;
> do not leave them “for later.”
>
> **User call 2026-09-16:** banner on **this bug only** (plus the active
> plan) — do not re-splat onto other bugs/docs. Prove without modifying
> the main codebase until the smoke names the fix.

**Status:** ⏳ **open** — bar is **your** session: overview search → click **Terminal** →
Terminal actually opens. Smokes are agent gates only; **`app-search-launch-smoke: ok`** does
**not** close this bug.

**In tree (2026-09-22):** compositor `Helper-AppLaunch` launch ctx — when mutter has both
`DISPLAY` and `WAYLAND_DISPLAY`, child env drops `DISPLAY` and sets `GDK_BACKEND=wayland`
(nested Weston `:1` + mutter WL). Desktop launch from `Shell.App.launch` already uses that
Helper (search click → activate → launch). Client `list_all_windows` → compositor
`list_windows` snapshots (remote-shell model; see 0.2). **Not verified as fixing your click**
until the user bar passes.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Related:** search fill ✔️ [`done/2026-09-19-overview-app-search-empty.md`](done/2026-09-19-overview-app-search-empty.md) · chrome inset / Event coords [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md)

---

## For you (plain English)

**What’s wrong:** Overview search lists apps fine. When you click a result, the app does not open (your report 2026-09-22).

**Do you need to do something?** Only if you are checking whether **this bug is fixed for
you** — that is clicking Terminal in search and seeing it open. Agents do not treat smoke
PASS as “fixed for user.”

**When we’ll ask you:** A real decision we cannot make, nested prove cannot run here, or
agents cannot observe your click and have done what they can on the launch/click path in
tree — then one line whether Terminal still fails on click (that is the product bar).

---

## What we know

| Works | Does not work |
| ----- | ------------- |
| Typing in overview search and getting application icons | Clicking an icon to start that app |
| `app-search-smoke` (grid fills) | User-visible spawn after click |

Not a regression of “search is empty” — that ticket is closed.

---

## How stock is supposed to work

Search results are normal **app icons**. Click → icon’s activate → `Shell.App` launch → `Gio` starts the `.desktop` app. On stock that runs inside **gnome-shell (= mutter)**. In this tree the JS runs in **`gnome-shell-rpc`**, so **`Gio` spawn is a child of the shell client**, unlike **`Meta.WaylandClient.spawnv`** for the shell itself (compositor child). Breakage may be **click → activate** *or* **launch must be compositor-side** — smoke decides; not the search provider API.

Launch code already lives in `src/shell-gi/App.vala`. Do **not** re-implement S.27 or disable `Gio.launch`.

---

## Why it might fail (hypotheses — smoke decides)

| Id | Idea | Plain terms |
| -- | ---- | ------------- |
| **A** | Click misses the icon | UI drawn too high; pointer pick hits the wrong place (same family as dead menu buttons). |
| **B** | Click never becomes a button “clicked” | Press/release / St.Button path. |
| **C** | `AppIcon.activate()` throws | Bad synthetic `Clutter.Event` from RPC (`get_current_event`, missing `get_flags`, …). |
| **D** | Launch runs but nothing appears | `Gio.spawn` / env / Meta never sees the new window in nested. |
| **D′** | Spawn on the **wrong display** | Nested prove: mutter uses Weston **X11** (`DISPLAY=:1`) plus its own **`wayland-mutter-gsr`** for shell clients. `Meta.LaunchContext` copies **`DISPLAY` + `WAYLAND_DISPLAY` from the shell process** (`src/meta-mini/LaunchContext.vala`). If the shell still has `DISPLAY=:1`, X11 (or XWayland-preferring) apps can open on **Weston’s X stack**, not as clients on mutter-rpc — smoke sees `create_launcher` / no throw but `n_windows=0`. |
| **D″** | Spawn from the **wrong process** | Stock: shell and mutter are **one** process — `Gio.AppInfo.launch` from `Shell.App` is still compositor-side. Here **`gnome-shell-rpc` is a `Meta.WaylandClient` child**; plain Gio spawn is a **subprocess of the shell**, not of **mutter-rpc**. Only **`Meta.WaylandClient.spawnv` on the compositor** (see `Server.vala`, `Helper-WaylandClient`) is wired like stock’s “launch as compositor”. App launch may need the same class of fix: **compositor-side spawn** (real Meta launch context + Gio on mutter), not env tweaks alone on the client stub. |

---

## Prove first

### Bare Wayland launch (nested prove)

**Script:** `src/gjs-embed/wayland-launch-smoke.js` — pass = new Meta NORMAL window, not
Gio `launch returned true`. Agent: `./scripts/agent-nested-smoke-prove.sh` with
`GI_META_SMOKE=wayland-launch-smoke` (`GSR_WESTON_AUTO_CLOSE=1`).

Harness **`GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1`** (2026-09-22 ~16:00): still **miss**
· `windows-normal after=0` — client ctx unset **not** sufficient alone.

**Compositor probe (2026-09-22 ~16:07, removed)** — was `Helper-AppLaunch.count_normal_windows`;
smokes now use client `list_all_windows` + `window_type` only. Historical log:
**`compositor-normal=0`** and **`client-normal=0`** after compositor launch (not RPC
export only). Compositor **`MetaLaunchContext` ctx** had **`DISPLAY=:1`** +
**`WAYLAND_DISPLAY=wayland-mutter-gsr`** (proc env). With
**`GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1`** on **mutter-rpc**, ctx log drops **`DISPLAY`**
(only **`WAYLAND_DISPLAY=wayland-mutter-gsr`**) — still **`compositor-normal=0`**,
**`proc gtk4-demo=(none)`** after 4s. **Read:** wrong DISPLAY was real; fixing ctx alone
does not pass **`wayland-launch-smoke`** on nested `--no-x11` yet (spawn/connect/wl
surface — still open).

### Search / activate path

**Script:** `src/gjs-embed/app-search-launch-smoke.js`

| Step | What it does | If it fails, suspect |
| ---- | ------------ | -------------------- |
| **L0** | `Gio` commandline (`gtk4-demo`) via `create_app_launch_context` | **D / D′** |
| **L1** | `lookup_app(id).activate()` — no mouse | **D / D′** |
| **L2** | `AppIcon.activate()` on already-touched icon — must not throw | **C** |
| **L3** | Synthetic click on a **second** search icon | **A / B** |

```bash
GSR_NESTED_TIMEOUT=90 GI_META_SMOKE=app-search-launch-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
```

Look in the log for `app-search-launch-smoke: ok` or `miss L1` / `miss L2` / `miss L3`.

### JS click/launch probe (debug only)

Sparse overlay — **not** production. Traces `AppIcon` click/activate and
`Shell.App` activate/launch (`gsr-launch:` in client log).

```bash
GI_RPC_JS_OVERRIDE_DIR=$PWD/src/shell-js-probe \
  GSR_NESTED_TIMEOUT=120 GI_META_SMOKE=app-search-launch-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
```

**Hold session (init.js)** — preload tap + activate trace (no full main.js overlay):

```bash
GI_RPC_GJS_EMBED_DIR=$PWD/src/gjs-embed GI_RPC_LAUNCH_PROBE=1 \
  ./scripts/weston-gsr-session.sh
```

Click Terminal in overview; grep **`gsr-launch:`** in
`~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log` (GNOME Shell-Message
lines). **`stage press`** without **`AppIcon.vfunc_clicked`** → click miss
(inset/coords). **`activate`** without **`Helper-AppLaunch`** in mutter log →
launch path not reached or old binaries.

Optional overlay (chrome probe main): `GI_RPC_JS_OVERRIDE_DIR=src/shell-js-probe`.

### Helper-AppLaunch vs “missing helpers”

Stock gnome-shell runs `Gio.AppInfo.launch` **inside mutter** — no RPC Helper.
This tree only had compositor-side spawn for **`Meta.WaylandClient.spawnv`**
(shell child). **Desktop app launch was never on the Helper list** (0.5.7 C
is Gio files / context terminate, not `.desktop` spawn). `Helper-AppLaunch` is
the compositor-side half of that gap — not a duplicate of an existing Helper.
The probe above tells us whether clicks and `Shell.App.launch` run before we
trust spawn/env fixes.

### Last automated run (2026-09-22 ~15:30) — compositor post-launch window count

Smoke still **miss L0/L1/L3** after 4s. New compositor probe:

- **`Helper-AppLaunch.launch_commandline post-launch normal=0`** (gtk4-demo) — immediate
  **`list_all_windows` NORMAL count on mutter-rpc**, not the RPC client.
- Same **`post-launch normal=0`** for Terminal / guake `.desktop` launches.

**Read:** Gio **`launch()` true** but **mutter compositor never sees a NORMAL window** at spawn
return — not client window export alone. Compositor still runs with **`DISPLAY=:1`**
(Weston X) + **`WAYLAND_DISPLAY=wayland-mutter-gsr`** (prove env). **D′** at compositor:
children likely on Weston X stack.

**🚫 No product tweak from this alone** — need a prove step that fails on wrong env and
passes with a **stock-shaped** fix (not ad-hoc `unset DISPLAY` in Helper).

### Re-prove (2026-09-22 ~15:45) — DISPLAY unset experiment (reverted)

Temporary compositor env hack: **`unset DISPLAY`** when `WAYLAND_DISPLAY` set (plus probe
warnings). First run never applied unset (`workspace <= -1` early return); after reorder,
**`ctx DISPLAY=(none)`** but smoke still **miss L0/L1** · compositor **`normal=0`**. Hack
**reverted from `AppLaunch.vala`** — did not move the bar; **D′** may contribute but is not
proven sufficient. **Next prove:** child process + wl socket attachment (harness-only), not
speculative Helper edits.

### Prior run (2026-09-22 ~15:05) — activate replicated, no manual clicks

Smoke **`Shell.App.launch()`** (same as STOPPED activate): **`launch() returned true`**.
Compositor log: **`Helper-AppLaunch.* ok=true`** for `gtk4-demo`, Terminal, guake with
**`DISPLAY=:1` `WAYLAND_DISPLAY=wayland-mutter-gsr`**. Still **`windows-normal=0`**
· **`state=0` `n_windows=0`** after 4s — **Gio spawn “succeeds”; Meta never sees a client window**.

**Manual hold (~15:02) with probe:** no `stage press` / no `AppIcon.vfunc_clicked` — **no
evidence physical clicks reached the shell** (probe may be blind to Weston pointer; separate from smoke).

### Prior run (2026-09-22 ~14:41)

- **`Helper-AppLaunch`** wired in rebuilt `mutter-rpc` — RPC reaches compositor (no “no handler”).
- **`miss L0`** — `launch_commandline_on_compositor(gtk4-demo)` · still `windows-normal=0`.
- **`miss L1` / `miss L3`** · **L2 ok** — same Meta window bar.
- Session **exit 137** (120s timeout after smoke `done`).

### Prior run (2026-09-22 ~14:32)

- **`proc-env`:** `DISPLAY=":1"`, `WAYLAND_DISPLAY="wayland-mutter-gsr"`, `WAYLAND_SOCKET="3"`.
- **`miss L0`** — `gtk4-demo` via `create_app_launch_context` · still `windows-normal=0` (continued).
- Search fill OK · **`miss L1`** / **`miss L3`** · **L2 ok** (same as ~14:24).
- Prove session **exit 137** (120s timeout SIGKILL after smoke `done` — expected for `stayup` prove).

### Prior run (2026-09-22 ~14:24)

- `main.overview.show()` + search fill OK (`nGrid=6`).
- **`miss L1`** — `lookup_app(Terminal).activate()` · `state=0` `n_windows=0` after 4s (RPC: `create_launcher` at L1).
- **L2 ok** — `AppIcon.activate(guake)` did not throw.
- **`miss L3`** — `pointer_click` on guake · still `state=0` `n_windows=0`.
- **Read:** direct launch **and** synthetic click both fail to spawn in nested; not click-only (A/B alone).
- **L0 (~14:27):** `gtk4-demo` via `create_app_launch_context` — launch returned, still `windows-normal=0` (**D′** strong: process env / wrong compositor, not `.desktop`-only).
- **~14:32 (env):** shell `proc-env` **`DISPLAY=":1"`** + **`WAYLAND_DISPLAY="wayland-mutter-gsr"`** + **`WAYLAND_SOCKET="3"`** — launch context inherits Weston X11 + mutter WL from the **WaylandClient child**, not from mutter’s compositor process (**D′** confirmed in log).
- **Next:** design **compositor-side** app spawn (same family as `Meta.WaylandClient.spawnv` for `gnome-shell-rpc` — **D″**); prove with smoke before `src/` change. **🚫** no fake `Meta.Display.launch`.

---

## Out of scope

Vendor `search.js` · fake `Meta.Display.launch` · no-op `Gio.launch` · undeny `queue-relayout` without a FAIL.
