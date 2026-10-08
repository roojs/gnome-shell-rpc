# Window overview has no thumbnails

**Status:** ⏳ open.

**Working rule for this bug:** no status theatre — do not stop to narrate, summarise, or ask to continue. Keep proving until the bar moves or a real stop condition hits.

**What the bug is:** the window overview draws no thumbnails of open windows. User hand repro: boot the nested debug session, open the app picker, type `gedit`, start it, gedit running, back to the app picker — no preview. Window under test is gedit, not a terminal.

**Diagnosis (updated 15:05 — much of the original is now superseded):** the `window-created` / `window-added` delivery gap theory is REFUTED for this bug — phase 2 proves a late window clones fine into pre-existing Workspace actors.

What was actually wrong, both now fixed:

1. The paint lands. `preview_actor` paints the stand-in's `TextureContent`, which needed `implements=Clutter.Content` to decode (`TextureContent.override`, meson-registered).
2. The trigger was blind. The server packed actor handles with retval unset, so the client decoded zero actors and stock bulk-add saw nothing (server handle pairs + `Compositor.override.vala` hydration, `Meta.deny` entry).

`notify::title` / `focus-window` “not writable” messages are not the thumbnail drop. Returning or cloning the live window actor killed Weston (09:31). That path is not coming back without a script that shows otherwise.

**Reproduction:** `tests/gjs-embed/thumbnail-smoke.js` boots product `main.start`, launches `gedit --new-window` on the nested display via Gio, waits for a Meta NORMAL window with a real frame, checks `get_window_app` is non-null, shows the overview in-process, waits for the repaint, then asserts the stand-in has non-null content and a non-zero `WindowPreview` exists.

Pass is `thumbnail-smoke: ok`. Fail is `thumbnail-smoke: miss <reason>`.

```bash
GI_META_SMOKE=thumbnail-smoke \
GI_META_SMOKE_CMD='gedit --new-window' \
GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
timeout --foreground -k 2 90 ./scripts/weston-gsr-session.sh --debug
```

**Latest result (2026-10-08 15:02):** `thumbnail-smoke: ok` twice over.

Phase 1, bulk-add: `[Workspace _windows=1]`, nonzero gedit preview, `window-actors=1 has-gedit=true`.

Phase 2, late second window with the overview already shown: `[Workspace _windows=2]`, both previews nonzero.

Fixes in tree: TextureContent Content decode, Compositor actor-handle pairs and the hydration override, and `set_pivot_point` restored in `Actor.override.vala` (the hand-seen picker crash). The smoke also drives pivot calls and the full stock `zoomOutActor` path.

## LLM efforts

### 2026-10-06 14:03 `alan@192.168.88.197` session 6

Help (`/usr/bin/yelp` 6040) and Terminal (`gnome-terminal-server` 6314) were running. Both windows were created with no title and no size. Server:

```text
14:03:37.624  window_created title=(null) frame=0,0 0x0 minimized=false
14:03:55.989  window_created title=(null) frame=0,0 0x0 minimized=false
```

Client, Help then the terminal:

```text
14:03:37.625  notification method=window-entered-monitor
14:03:37.626  notification method=Window.created
14:03:37.959  JS ERROR: TypeError: app is null
            _init@windowPreview.js:133
            _addWindowClone@workspace.js:1341
            _windowEnteredMonitor@workspace.js:1266
```

The same throw repeats at 14:03:38.082 from `_windowAdded`. `windowPreview.js` line 133 is `app.create_icon_texture`, and `app` is `Shell.WindowTracker.get_default().get_window_app(metaWindow)`.

### 2026-10-07 hacks (in tree, unproven as fixes)

`WindowTracker.get_window_app` associates the window on the first ask when `window-created` has not arrived yet. The 2026-10-07 09:17 nest no longer logs `app is null`.

`windowPreview.js` calls `metaWindow.get_compositor_private()` before `create_icon_texture`. Every call that morning returned `-32602` with an empty message (`Meta-Window.get_compositor_private`, ids 20002 onward). `get_compositor_private` now returns one stand-in per window (`Meta.WindowActor` with `meta_window` set); the picture is painted into that actor by `Gsr-Mutter-Window.preview_actor`, and the overview clones the stand-in. The live window actor stays on the stage.

2026-10-07 10:20: the empty actor from the previous stand-in had no `meta_window`, so leaving the overview threw `TypeError: win is undefined` in `workspaceThumbnail.js` `_isMyWindow`. `preview_actor` ran once, in the same second the window was still `frame=0,0 0x0`, and `size-changed` was never subscribed, so the paint was not repeated after the window had a buffer.

2026-10-07 10:31: the overview no longer crashes. There is still no picture of the windows. The bottom footer app select does not raise the window that was clicked (Help stayed above Terminal). Footer-raise is a separate observation, not this bug's bar.

### 2026-10-07 17:50 gedit run

Nested debug session, `gsr-server` 3116041, `gsr-client` 3116070. `READY=1` at 17:49:32. gedit 3116646 started 17:50:06 with `GDK_BACKEND=wayland`, `WAYLAND_DISPLAY=wayland-mutter-gsr`, and the nested session bus. `DISPLAY` was unset so it did not open on the host.

Server, 17:50:08.147: `window_created title=(null) frame=0,0 0x0`. One compositor window actor. Then `notify::title` twice, each `property 'title' of object class 'MetaWindow' is not writable`. Then `size-changed`, and `Gsr-Mutter-Window.preview_actor` at 17:50:08.156 and again at 17:50:08.230. No `preview_actor:` warning. No `app is null`. Client order is still `window-entered-monitor`, then `Window.created`. No `method=window-created`.

Activities click at 17:51:55 hit `panelActivities`. `WindowPreview` measured `nat=1546` by `nat=1034`. `preview_actor` ran once more (id 29901). `Clutter-Grab.dismiss` followed in the same second. The stage stayed on the wallpaper. gedit's window was not drawn on it. The overview did not stay up. Session later died to a Weston segfault (exit 139, `failed to read Wayland events: Connection reset by peer`); gedit exited `Broken pipe` with it.

### 2026-10-07 18:02 thumbnail-smoke written, session failed to boot

`tests/gjs-embed/thumbnail-smoke.js` written (see Reproduction above). `build/src/gsr-smoke` exists. The restart never booted: Weston `failed to create egl surface` / `Enabling output "screen0" failed`, exit 1.

## 2026-10-08 runs (parent on `GSR_WESTON_PIXMAN=1`, see below)

Host EGL refused all morning (`failed to create egl surface`, pixman parent works). New script knob, not product path: `GSR_WESTON_PIXMAN=1` on `scripts/weston-gsr-session.sh`. Mutter nested still renders the shell itself. EGL refusal + two Weston SIGSEGVs (cores 12:28, plus 10-07) are host-side; parent deaths are classified per `nested-debug.md`, not product.

Smoke verdicts live in the tee log (`GNOME Shell-Message: thumbnail-smoke: ...`), not the client log — `log()` from the smoke process lands there.

`miss window`: Gio-launched gedit/xterm vanished with `launch returned true` and no process. Cause: gsr-smoke carries `WAYLAND_SOCKET=<fd>` for its own pre-connected socket; the grandchild inherits the number, not the fd, and its Wayland handshake dies instantly. Smoke now `ctx.unsetenv('WAYLAND_SOCKET')` (plus existing DISPLAY unset). Manual `env -u DISPLAY ... gedit` on the same session mapped fine.

`miss paint`: `preview_actor` ran once but the stand-in read `content=null`, with `g_value_set_object: assertion 'g_value_type_compatible ...' failed` on `Clutter-Actor.get_content`. Root cause: generated `Clutter.TextureContent` stub did not implement `Clutter.Content`, so the painted server texture could not decode into a Content GValue. Fix (in tree, proven on the smoke — `compositor-private=content=set 800x568`): `TextureContent implements=Content` in `Clutter.overrides` plus `overrides/TextureContent.override.vala` (Content methods, `[GIR (visible=false)]`, same unreachable-by-design shape as BackgroundContent.override), registered in `src/meson.build` `clutter_override_files`.

`miss preview`: paint works, tracker app set, frame real, but zero `WindowPreview` under the stage and no JS error. diag: `located=true monitor=0 skip_taskbar=false has_transient=false`. _reading_: stock `_doAddWindow` runs on window-added/entered-monitor while `get_compositor_private()` is still null (stand-in was lazy) and its one-shot idle retry fires before any first read, so no clone is ever built. Trial (in tree, UNPROVEN): create the stand-in in a Display `window-entered-monitor` handler (`Display.override.vala` construct). First version subscribed + connected inside construct and segfaulted the client three times (`gsr-smoke SIGSEGV`, cores; gdb: OPC `bin_stream_parse_object` with null types during `get_display` decode — nested call_poll from `ensure_signal_subscribe` inside the decoder). Second version deferred via `GLib.Idle.add` — user called out idle as a known-bad pattern here; replaced with a bare local `.connect` (stock Workspace subscribes the same signal, so no ensure call, no RPC at construct). Awaiting smoke verdict.

### 2026-10-08 12:40–13:25 trigger hunt and fix (this session)

Repro-side stepping (smoke only, no product change) drove stock `_doAddWindow` directly: gates read `isMy=false isOverview=true` on the first Workspace probed. Per-actor probe showed why — the first three Workspace actors sit on metaWs 1–3 while gedit is on winWs 0; the metaWs 0 actor reads `onWs=true mon=0/0 isMy=true isOver=true has=false`, and a manual `_doAddWindow` there yielded `previews-after-doAdd=1 [Untitled Document 1 - gedit 539x383]` → `ok` (twice). Clone + TextureContent paint proven end to end; only the trigger was missing. Trial code then removed from the smoke.

Root cause, proven by server log vs client: server `Compositor.get_window_actors` returned 1 actor (`Compositor.vala:53 window actors=1`) but the client decoded `window-actors=0`. The hand-written server packs raw uint64 handles into `response.args` with retval unset; the generated client expects a `Gee.ArrayList` retval (`Generator.emit_list_return`) and silently keeps an empty list. So stock `Workspace` construction bulk-add (`global.get_window_actors().map(a => this._doAddWindow(a.meta_window))`) saw nothing, and no later `window-added` fires for a pre-existing window.

Fix (follows the `Display.list_windows` snapshot-hydration precedent): server appends each actor's window lease after the actor lease (pairs; no ternary — explicit `uint64 win_lid` + `if`, per valac ternary caution); new client `Compositor.override.vala` hydrates `Window` + `WindowActor` proxies (`rpc_lid` + `register_handle`, actor `bound_meta_window` set); `Compositor.get_window_actors` added to `Meta.deny` (first build without it failed: ``Compositor' already contains a definition``); override registered in `src/meson.build`. `ok` on the pure stock path three times (12:56, 13:15, 13:25): `_windows=1`, nonzero preview, `has-gedit=true`.

Separate observation, not this fix: 3 of 8 runs died at startup with the server (`gsr-server`) SIGTRAP inside stock `clutter_actor_allocate` ← St (cores 13:09, 13:13; pending client call `Clutter-Actor.allocate`; precursor `ClutterBoxLayout ... minimum height: -12` for a `GsrServerClutterActor` plus `st_drawing_area ... in_repaint` asserts). Reverted the Compositor work per review, re-ran baseline (stable startup, `miss preview` as designed), rolled back server-only (stable, `miss`) then full fix (`ok`) — crash tracks no step; it fires before `get_window_actors` is ever called and identical binaries pass. Startup race to chase separately.

### 2026-10-08 13:35 hand repro: app-picker client SEGV (fixed)

User drove the picker by hand (type gedit, launch): client `gsr-client` SIGSEGV at 13:35:09 in `clutter_actor_set_pivot_point` (Graphene.Point property setter, value=NULL) reached from stock JS. Their screenshot shows the overview frozen by that death — workspace strip painted, window layout never completed — so its empty main area is the crash, not paint. Cause: the typelib declares the real `set_pivot_point(double, double)` but the only C symbol was the Point property setter (methods denied for "C symbol clash"), so stock callers (`iconGrid` launch animation) hit an ABI mismatch — null deref or garbage RPC depending on the garbage in rsi. Fix in `Actor.override.vala`: property setter moved to `gsr_clutter_actor_set_pivot_point_point`; new stock-signature `set_pivot_point(double, double)` owns `clutter_actor_set_pivot_point` (same deny + hand-method pattern as the Compositor fix; no stock JS uses `get_pivot_point`, set-only suffices). Smoke now drives the full stock `zoomOutActor` path plus pivot calls on stage/clone/panel: all pass, then `ok`. Blocked mid-session by a concurrent agent's uncompilable `ClutterActor.vala` debug lines (13:44); they repaired it, build green.

### 2026-10-08 15:02 late-window delivery proven (phase 2)

Hand screenshot (14:50) still showed wallpaper in the main area, which suggested Workspace actors built before the window maps never learn of it (no `window-added`). Repro-side phase 2 keeps the overview shown and launches a second gedit: `phase2 found=6 ... [Workspace _windows=2] [Untitled Document 1 ...] [Untitled Document 2 ...]` → `ok`. Late delivery WORKS — hypothesis refuted, no product change needed. The 14:50 session was concurrently running another agent's `picker-second-launch.js`, whose own grid errors (`IconGridLayout.adaptToSize wasn't called before allocation`, `clutter_margin_copy: undefined symbol` from `appDisplay _updatePadding`) explain the broken overview layout there; the missing margin symbol is that area's binding gap, not this bug. The stuck Yelp zoom icon was seen in the same broken session.

## Handoff (15:50 — user heading off)

Done: paint fix (TextureContent Content decode), trigger fix (Compositor handle pairs + hydration override), picker SEGV fix (`set_pivot_point` method). Smoke green on all of it, both orders (phase 1 bulk-add, phase 2 late delivery). Tree builds (`BUILD_EC=0`); all changes are in `src/` + the smoke file, bug log above is current. Pending: a CLEAN hand verification (boot session with no picker test running, launch gedit/Yelp directly, open overview, confirm real window content in the main area) — the last two hand screenshots were both taken in broken sessions (client SEGV; picker-test grid errors). Not this bug: the startup server SIGTRAP race (separate chase) and `clutter_margin_copy` undefined symbol (picker agent's area). Rerun command is under **Reproduction** above (bump `timeout` to 150 for the two-window phase 2).

## When you may stop

1. You actually need the user: a decision only they can make, credentials, a machine or session you cannot reach, or approval the plan forbids you from assuming. One short ask, then wait.
2. OPC / libocrpc is the problem. Only then: a failing gate under `tests/call-sync-repro/`, this bug, and no edit to OLLMchat from this tree. A passing gate means the consumer is still the problem. Do not stop to report that theory.
