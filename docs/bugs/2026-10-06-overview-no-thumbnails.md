# Window overview has no thumbnails

**Status:** ⏳ open. Paused 2026-10-09 09:51 at the user's request. Uncommitted. Last hand look is the 08:18 screenshot: selected top workspace tab has a tiny picture, the main card is the mountain wallpaper, Help's life ring is cut across the dash. That hold (`gsr-server` 237656) was killed by the first prove after it. No later hand look.

**Where the code is:** `WindowPreviewLayout` builds a plain `Clutter.Actor`, copies the stand-in's `content` onto it, and `allocate_vfunc` sizes that child from the window buffer rect. The stand-in stays offstage. `preview_actor` still copies `paint_to_content` onto the stand-in and `set_size`s it from the buffer rect. The live window actor stays on the stage. Cloning that live actor killed Weston on 2026-10-07 09:31 and stays out.

`Clutter.Interval.set_final` / `set_initial` still send a `GValue` for ordinary types. A `ClutterActorBox` goes as the raw struct on `Gsr-Clutter-Interval.set_final_box` / `set_initial_box` (`Interval.override.vala`, `src/server/libmutter-clutter-16/Interval.vala`). `workspace.js` calls `get_interval().set_final(childBox)` while the overview is laying out windows.

`tests/gjs-embed/thumbnail-smoke.js` fails unless some descendant of a `WindowPreview` has content and `has_allocation()`. `scripts/nested-weston-prove.sh` `SMOKE_OK_PAT` now includes `thumbnail-smoke: ok`. That pattern line has not been rerun.

**Last prove** (09:48, `GSR_NESTED_TIMEOUT=70`, command under Reproduction):

```text
09:49:13.811 thumbnail-smoke: preview-paints=true
09:49:14.595 thumbnail-smoke: phase1-ok
09:49:14.939 Gsr-Clutter-Interval.set_final_box id=23496
09:49:15.348 thumbnail-smoke: phase2 windows-normal=2
09:49:18.744 thumbnail-smoke: phase2 found=14 … [Untitled Document 1 - gedit 254x180] [Untitled Document 2 - gedit 254x180]
09:49:18.744 thumbnail-smoke: ok
nested-weston-prove: stop (timeout) after 70s
```

Exit 137 is the prove kill after the 70s wall. The smoke had already printed `ok`. The prove kept waiting because `thumbnail-smoke: ok` was not yet in `SMOKE_OK_PAT`.

That `ok` means the script saw allocated content on a preview and a second gedit preview while the overview stayed up. It is not a read of the framebuffer. The hand bar is still the 08:18 screenshot: the main card shows the window, the top tabs still show theirs, the life-ring zoom is gone, and the nest stays up.

**Diagnosis that is still true:**

Top tabs are `workspaceThumbnail.js` `WindowClone`, a `Clutter.Clone` of a live window actor from `global.get_window_actors()`, scaled to at most 5% (`MAX_THUMBNAIL_SCALE`). Those actors are on the stage, so the tab can paint.

Main previews are `windowPreview.js` `WindowPreview` → `get_compositor_private()` → `Shell.WindowPreviewLayout.add_window`. Mutter `clutter-clone.c` paints a `Clutter.Clone` only when the source is realized. The stand-in has no parent, so a clone of it stays blank even when `content=set` and the preview measures about 478×340. That is why the 08:18 main card was wallpaper while the tab had a picture.

Parenting the stand-in (`GsrServerClutterActor`) under the stage made `has_allocation` true and then stuck phase 2. That experiment is reverted.

`workspace.js` `set_final(childBox)` sent `ClutterActorBox` as a bin `GValue`. The wire answered `unsupported bin value type 'ClutterActorBox'`, the error was uncaught, and the next `Gsr-Clutter-Actor.allocate_public` stayed unanswered until the prove kill. Phase 2 then logged `miss phase2 (second window never appeared)` only as the socket died. The bytes methods above are the path that let 09:49 reach `thumbnail-smoke: ok`. libocrpc was not edited.

Earlier fixes that are still in the tree: `WindowTracker.get_window_app` associates on the first ask (`app is null` is gone); `get_compositor_private` returns the stand-in; `TextureContent` implements `Content`; `get_window_actors` ships handle pairs and `Compositor.override.vala` hydrates them; `Actor.override.vala` owns `set_pivot_point(double, double)`.

Help's life ring is `iconGrid.js` `zoomOutActorAtPos`: a clone, `set_pivot_point(0.5, 0.5)`, ease scale to 3 and opacity to 0 over 250ms, then `destroy()`. At 08:18:18 the destroy RPC replied about 330ms later. The screenshot still shows the ring across the dash. No failing assertion for that yet.

`property 'realized' of object class 'Gjs_ui_windowPreview_WindowPreview' is not writable` (08:18:23, 19 times) and `Can't update stage views actor unnamed [ClutterActor] is on because it needs an allocation` (08:18:24) are still in that hold's log.

Dash launches that never start, clicks on a running dash icon, and flaky workspace 1–5 selection are [`2026-10-08-dash-and-workspace-switch.md`](2026-10-08-dash-and-workspace-switch.md).

**Reproduction:**

```bash
GI_META_SMOKE=thumbnail-smoke \
GI_META_SMOKE_CMD='gedit --new-window' \
GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
GSR_NESTED_TIMEOUT=70 \
./scripts/agent-nested-smoke-prove.sh
```

Pass on the script is `thumbnail-smoke: ok` and `nested-weston-prove: stop (smoke-ok)`. The 09:49 run has the first line. The stop line is still `stop (timeout)` until the `SMOKE_OK_PAT` change is rerun. Fail is `thumbnail-smoke: miss <reason>`. The hand bar is a look at the overview after that pass.

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

### 2026-10-09 08:18 hold — screenshot and logs

User screenshot, panel clock Oct 9 08:18, window title `gsr-server`. Overview is up. Selected workspace tab has a small picture. Main workspace card is the wallpaper. Help's life ring is cut by the bottom edge of the dash.

Processes: Weston 237594, `nested-weston-hold.sh` 237638, `gsr-server` 237656, `gsr-client` 237687, `yelp` 237964. Still running at the read. No `JS ERROR`. No `client exited`.

`clicked` 08:18:18.461, `launch_desktop_file` id 19644, `set_pivot_point` id 19591, `set_scale` ids 19609 and 19610. `window_created` 08:18:19.522 `frame=0,0 0x0`. `preview_actor` id 21111 at 08:18:19.556. `WindowPreview` `realized` not writable from 08:18:23.424 (19 in the client log). Server 08:18:24 `unnamed [ClutterActor] is on because it needs an allocation`. First client `size-changed` is 08:19:22. Second launch id 47575 at 08:19:20, second `window_created` `frame=0,0 0x0` at 08:19:20.841. `preview_actor` count 76 by 08:19:51.

### 2026-10-09 hand report, logs already on disk

User: after the thumbnail changes, Weston crashes regularly. The top workspace tabs show a tiny thumbnail. The main window previews do not.

Read `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`, `mutter-rpc.debug.log`, `nested-weston-prove.tee.log` (all mtime 2026-10-08 10:42), and the end of `weston-autolaunch-prove.log` (3.2GB, same morning). No `thumbnail-smoke` line in any of them. `coredumpctl --since '2026-10-08 11:00'` is empty. Last autolaunch stop in that file is `nested-weston-prove: mutter exited ec=1 after 50s` at the 09:35 boot (`not connected` on `Clutter-Actor.get_first_child` / `get_n_children` / `set_reactive`), then later `weston-gsr-autolaunch: mode=session` restarts. Those files predate commit `305d443`. No new prove was started.

### 2026-10-09 proves (paused 09:51)

Command each time:

```bash
GI_META_SMOKE=thumbnail-smoke GI_META_SMOKE_CMD='gedit --new-window' \
GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 GSR_NESTED_TIMEOUT=70 \
./scripts/agent-nested-smoke-prove.sh
```

(`GSR_NESTED_TIMEOUT=90` or `150` on the earlier ones.) The 08:18 hold was cleared by the first of these.

Client `actor.allocate(box)` on the offstage stand-in called `Gsr-Clutter-Actor.allocate_public`. Server: `Spurious clutter_actor_allocate … isn't a descendent of the stage`. Smoke: `stand-in-allocated=false`, `miss allocation`, `stop (smoke-fail) after 11s`. Exit 137. `has_allocation()` is false whenever `parent == NULL`. That assertion was removed from the smoke.

Parenting the stand-in under the stage (`insert_child_below`, opacity 0) made `stand-in-allocated=true` and `phase1-ok`, then `stop (timeout) after 150s` with `miss phase2`. Reverted. The stand-in stays offstage.

`WindowPreviewLayout` then used a `Clutter.Actor` that copied `source.content` and called `set_size`. Smoke: `preview-paints=true`, preview `478×340`, `phase1-ok` at 09:14:29. Then `Clutter-Interval.set_final id=22916: unsupported bin value type 'ClutterActorBox'` and `Gsr-Clutter-Actor.allocate_public id=22917` unanswered until `disconnect abort`. `stop (timeout) after 90s`. Weston pid 286007 SIGSEGV at 09:23:42 in `desktop-shell.so` during `wl_client_destroy` (Xwayland client teardown). Exit 139.

Wrapping `set_size` in `save_easing_state` / `set_easing_duration(0)` still logged the ActorBox error (09:23:05 id 23313, then `allocate_public` id 23314 until 09:24:20). Dropping `set_size` and sizing the child from `buffer_rect` in `allocate_vfunc` still logged it (09:32:15 id 22940, `allocate_public` id 22941 until 09:33:10). `phase1-ok`, then `stop (timeout)`, `miss phase2`. The caller is `vendor/gnome-shell/js/ui/workspace.js` `windowInfo.currentTransition.get_interval().set_final(childBox)`.

One boot at 09:30 died in 4s: `thumbnail-smoke: miss TypeError: global.stage.context is null`, `mutter exited ec=133`. The next boot reached phase 1.

`Interval.set_final_value` / `set_initial_value` now send `ClutterActorBox` as `ay` bytes on `Gsr-Clutter-Interval.set_final_box` / `set_initial_box`. 09:49 run: `set_final_box` id 23496, `phase2 windows-normal=2`, both previews `254×180`, `thumbnail-smoke: ok` at 09:49:18.744, `done` at 09:49:18.745. Prove line: `stop (timeout) after 70s`. `SMOKE_OK_PAT` in `scripts/nested-weston-prove.sh` gained `thumbnail-smoke: ok` after that run. Not rerun.

Paused here. Hand look of the main card, the top tabs, and the life-ring zoom is still the 08:18 screenshot.
