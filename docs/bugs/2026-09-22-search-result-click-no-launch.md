# Search result click does not spawn the application

> # ⚠️ AGENTS — DO NOT STOP FOR STATUS THEATRE
>
> Keep working until the user-visible bar moves or a real stop condition is
> reached. A smoke failure, disproved hypothesis, rebuild, or partial explanation
> is not a stopping point. Update this bug, take the next test-only prove step,
> and continue.
>
> Stop only when user input is genuinely required, or when a FAIL-backed
> `tests/call-sync-repro/` gate proves OPC/libocrpc is the problem. In the latter
> case, follow the workspace OPC rule exactly.
>
> This instruction does **not** authorize speculative product edits. Follow
> “Takeover guardrail” below: prove the missing boundary in test/probe code first.

**Status:** ⏳ **open** — bar is **your** session: overview search → click **Terminal** →
Terminal actually opens. Smokes are agent gates only; **`app-search-launch-smoke: ok`** does
**not** close this bug.

**In tree (2026-09-22):** search click → `Shell.App.launch` → compositor
`Helper-AppLaunch.launch_desktop_file` (mutter `create_launcher()` on the compositor).
**Not verified** until click Terminal opens.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Related:** search fill ✔️ [`done/2026-09-19-overview-app-search-empty.md`](done/2026-09-19-overview-app-search-empty.md) · chrome inset / Event coords [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md)

---

## Takeover guardrail — read before touching `src/`

**Do not edit product code to chase this yet.** In particular, do not add another
launch Helper, force `GDK_BACKEND`, unset `DISPLAY` in `AppLaunch.vala`, alter
`Shell.App`, invent Meta APIs, or patch vendor GNOME Shell JS.

The source tree currently contains the already-committed compositor
`Helper-AppLaunch`; the working-tree change intentionally removes its unproven
environment manipulation. An 18:06 rebuild/retest with that manipulation restored
still produced `miss L1` and `miss L3`, so repeating it is not a next step.

Allowed next work is **test/probe code only** (`src/gjs-embed/` and harness scripts)
until one test:

1. reproduces one precise missing boundary;
2. records the child command, environment, PID/exit, and target compositor;
3. fails before a proposed product change; and
4. passes because of that minimal change.

Keep these as separate questions:

- **Physical click:** did the real press/release invoke `AppIcon.vfunc_clicked`?
- **Shell activation:** did `AppIcon.activate()` call `Shell.App.launch()`?
- **Process dispatch:** did Gio actually create/activate the requested process?
- **Window attachment:** did that process connect to this `mutter-rpc` and map a
  `Meta.Window`?

Do not report a launch failure as a click failure, or a D-Bus teardown message as
the launch cause.

---

## For you (plain English)

**What’s wrong:** Overview search lists apps fine. When you click a result, the app does not open (your report 2026-09-22).

**What is now proven:** calling the icon activation path directly reaches
`Shell.App.launch`, crosses RPC to compositor `Helper-AppLaunch`, and Gio reports
success. For Terminal, the `gnome-terminal` frontend also asks the nested session
bus to activate `org.gnome.Terminal`. No application window is then mapped on
`mutter-rpc`.

That means the automated failure is currently **after launch dispatch and before a
window appears**. It does **not** yet prove that a real physical click reaches the
icon; that remains a separate unclosed boundary.

**What D-Bus means here:** GNOME Terminal is a client/server application. The
launched `gnome-terminal` command asks the session bus to start or contact the
Terminal service. The log proves that request was made. The later “bus killed” /
“connection closed” messages occur after the smoke terminates the nested session,
so they are teardown fallout, not evidence that D-Bus originally blocked the
click.

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
| Direct `AppIcon.activate()` reaches `Helper-AppLaunch` | User-visible window after dispatch |
| Gio reports launch success | Real physical-click boundary is still unproven |
| Explicitly corrected GTK launch maps on mutter | Default launch environment maps no window |

Not a regression of “search is empty” — that ticket is closed.

---

## How stock is supposed to work

Search results are normal **app icons**. Click → icon activate →
`Shell.App.launch()` → Gio launches the `.desktop` application. Stock
gnome-shell and mutter share one process. This project splits them, so
`Shell.App.launch()` currently crosses RPC to compositor `Helper-AppLaunch`,
which calls real `Gio.DesktopAppInfo.launch()` with mutter's startup-notification
context.

That dispatch path exists and is reached. The unresolved problem is where the
launched process connects and why no window maps on this Mutter. Do not add a
second launch path or disable Gio.

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

## Latest evidence (2026-09-22 18:03–18:06)

### Bare GTK launch: exact nested environment split

After a full rebuild:

- Default `gtk4-demo` launch: Gio returned true; `windows-normal=0`.
- `env -u DISPLAY GDK_BACKEND=wayland gtk4-demo`: failed to open a display.
- `env -u WAYLAND_SOCKET gtk4-demo`: launched away from mutter;
  `windows-normal=0`.
- `env -u DISPLAY -u WAYLAND_SOCKET GDK_BACKEND=wayland gtk4-demo`:
  **`windows-normal=1` in about 200 ms**.

This proves two independent hazards in the nested harness:

1. the shell process has private `WAYLAND_SOCKET=3`; a normally spawned child
   must not reuse that inherited fd; and
2. `DISPLAY=:1` belongs to parent Weston, while
   `WAYLAND_DISPLAY=wayland-mutter-gsr` belongs to the Mutter under test.

It does **not** prove that globally rewriting those variables in product code is
correct. That experiment has already been tried and did not make the
search-launch smoke pass.

### Search activation and Terminal D-Bus

The 18:06 run recorded:

- search grid populated (`nGrid=6`);
- direct `Shell.App.launch()` called
  `Helper-AppLaunch.launch_desktop_file`;
- Helper replied and `launch()` returned true;
- direct `AppIcon.activate()` also reached the Helper without throwing;
- `gnome-terminal` requested D-Bus activation of `org.gnome.Terminal`;
- after four seconds: `windows-normal=0`, app state STOPPED, zero windows;
- synthetic pointer L3 also ended with zero windows.

The environment-rewrite version of `AppLaunch.vala` was rebuilt for this run and
still missed. It was reverted immediately. **Do not repeat that edit.**

The smoke does not yet prove a real mouse click reaches `vfunc_clicked`, and its
L3 result is confounded because L2 has already attempted to launch another result.
Fix the test/probe before drawing a product-code conclusion from L3.

### Next test-only step

Make the launch smoke deterministic without changing `src/` product behavior:

1. launch a known non-D-Bus GTK desktop app (for example
   `org.gtk.Demo4.desktop`) through the existing `Shell.App` →
   `Helper-AppLaunch` route;
2. capture PID, actual child environment, exit status/stderr, and whether the
   process maps on Weston or mutter;
3. test Terminal separately and follow the owner/activation environment of
   `org.gnome.Terminal`; and
4. use a fresh third icon for synthetic L3, then separately trace a real physical
   press/release to `AppIcon.vfunc_clicked`.

No product edit is justified until one of those probes fails at a named boundary.

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
