# Search result click does not spawn the application

**Status:** ⏳ open — user 2026-09-22: search shows app icons; clicking one does not start the app.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Related:** search fill ✔️ [`done/2026-09-19-overview-app-search-empty.md`](done/2026-09-19-overview-app-search-empty.md) · chrome inset / bad Event coords [`2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md)

---

## What we know

| Works | Does not work |
| ----- | ------------- |
| Typing in overview search and getting application icons | Clicking an icon to start that app |
| `app-search-smoke` (grid fills, `fade_margins`, etc.) | Any sign of spawn after a user click (no extra app process) |

This is **not** “search is broken again.” It is the step **after** results appear: pointer → activate → launch.

---

## How it is supposed to work (stock)

1. Search hits are **`AppIcon`** widgets (same as the app grid), not a separate “open this result” API.
2. **Primary click** → `AppIcon` `vfunc_clicked` → `activate()` → `Shell.App.activate()` → `launch()` → **`Gio.DesktopAppInfo.launch`** with a startup-notification context from `Global.create_app_launch_context()`.
3. Launch runs **inside the shell process** (normal `Gio` spawn). It is **not** an RPC to mutter, except for building the launch context (`get_startup_notification` / `create_launcher`), which we already use at boot.

So if click-to-launch fails, the break is somewhere in **(click delivery)** → **`AppIcon.activate`** → **`Shell.App.launch`**, not in “search providers.”

---

## Why it might not be working

We have **not** run a FAIL smoke yet; below is the ordered guess list. Fix the **first** step that a smoke proves is broken — do not re-implement `Shell.App` (S.27 is already in `src/shell-gi/App.vala`) and do **not** no-op `Gio.AppInfo.launch` (dash used to launch without a click when that path worked).

### A — The click never reaches the icon (most plausible with current chrome)

Overview search UI is still **drawn too high** (panel inset bug). You click where the icon **looks** like it is; mutter’s pick may hit empty space, the stage, or something that only **closes** the overview.

Same class of bug as **popdown buttons that do not respond**: Compact `Clutter.Event` coords from the compositor are often wrong, so `get_actor_at_pos` / focus / hit-testing lie. Menu **open/close** can work while **clicks on children** do not.

**Symptom in logs:** overview hides or moves, but **no** second `create_launcher` after boot (launch never started).

### B — The click reaches the icon but `St.Button` never emits “clicked”

Stock only runs `vfunc_clicked` after a real press **and** release on the button. If the event stream is incomplete or mapped to the wrong actor, the icon may highlight but **`AppIcon.activate` never runs**.

(Dash had a different bug — spurious launch from a **class-struct offset smash** — that is **closed**. This ticket is “click and nothing launches,” not “apps launch on their own.”)

### C — `AppIcon.activate` runs but dies before `this.app.activate()`

`activate()` reads **`Clutter.get_current_event()`** (modifiers, etc.) and may run **`animateLaunch()`** first. Our Compact Event stub is **incomplete**: RPC unpack has thrown `g_value_get_uint` warnings, and symbols like **`clutter_event_get_flags`** are missing from the client `.so` (noise on other code paths). If JS throws here, you get **no launch** and possibly a half-finished overview animation.

**Symptom in logs:** still **no** `create_launcher`; you might see `get_current_event` and overview hide without spawn.

### D — `Shell.App.launch` is broken (less likely first)

If **`lookup_app(id).activate()`** were called from JS **without** any click, and spawn still failed, the bug would be launch context / `DesktopAppInfo.launch` / env. Nested log on 2026-09-22 showed **`create_launcher` only at boot**, not after the user’s click — so we have **not** seen JS reach `launch()` on that session. Prove D with smoke **L1** before chasing new Vala.

---

## Evidence (nested 2026-09-22 ~12:54)

Log: `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`

- **`create_launcher` once at boot** — normal startup; **never again** after clicking search results → **`Shell.App.launch` was not reached** on that run.
- **`Helper-Clutter.get_current_event`** once around overview **hide** (cover pane), not a full “click → animate → launch” sequence.
- **`clutter_event_get_flags` missing** — JS errors in menu grab code (related Event surface; same family as B/C).
- **`queue-relayout` missing on AppIcon** — error while redisplaying app grid on hide; separate deny/signal issue, not the root cause of “never spawn” until proven.

---

## What to prove next

Three probes; **one** must FAIL before a targeted fix:

| Smoke step | What it tests | If it fails, look at |
| ---------- | ------------- | --------------------- |
| **L1** | After search fill, call `lookup_app(firstHit).activate()` (no mouse) | D — `Shell.App` / launch context / `Gio.launch` |
| **L2** | Call `firstGridIcon.activate()` same way | C — JS `activate()` body, `get_current_event`, animation |
| **L3** | `Shell.Global.pointer_click` on the first result’s bounds | A / B — pick, coords, `vfunc_clicked`, St button |

**Pass bar for “launch works”:** log shows **`get_startup_notification` + `create_launcher` again** after the probe, and a child process appears (e.g. gtk4-demo / Terminal in nested).

```bash
# not written yet
GSR_NESTED_TIMEOUT=60 GI_META_SMOKE=app-search-launch-smoke \
  GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
```

Until that smoke exists: `./scripts/weston-gsr-session.sh`, search, click — score **spawn**, not icon count (`app-search-smoke` only covers fill).

---

## Out of scope here

- Vendor `search.js` · fake `Meta.Display.launch` · disabling `Gio.launch`
- Undeny `queue-relayout` without a FAIL that names it
- Re-closing the empty-grid / `fade_margins` search ticket
