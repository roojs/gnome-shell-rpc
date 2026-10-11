# Window overview has no thumbnails

**Status:** ⏳ open. On a normal desktop the window thumbnail shows gedit. Here it shows the mountain wallpaper.

## Steps

### 1. Before Activities, the gedit window is visible on the desktop

On a normal desktop the gedit window is visible on the desktop.

Here it works as expected.

### 2. The window thumbnail is of that same window

On a normal desktop the window thumbnail is of the gedit window that is visible on the desktop.

Here it works as expected.

### 3. Activities makes the gedit window no longer visible on the desktop

On a normal desktop the gedit window is no longer visible on the desktop. It stays in place, still 800 by 568.

Here it works as expected.

### 4. The window thumbnail is visible, and smaller than the window

On a normal desktop one window makes a thumbnail about 478 by 340. Two windows make thumbnails about 254 by 180. The window thumbnail is fully visible.

Here it works as expected.

### 5. The gedit window still holds its picture

On a normal desktop the gedit window still holds a picture of gedit, 800 by 568, and that picture is not blank.

Here it works as expected.

### 6.1 Clone the gedit window and allocate the thumbnail

On a normal desktop these calls build the window thumbnail from the gedit window, at the thumbnail size.

Here it works as expected.

- ✔️ Client `src/client/libshell-16/WindowPreviewLayout.vala` `window.get_compositor_private()`
  - RPC `Gsr-Mutter-Window.get_compositor_private`
    - Server `src/server/libmutter-16/Window.vala` `get_compositor_private`
      - Return window-actor lid
- ✔️ Client `new Clutter.Clone(source)`
  - RPC `Clutter-Clone.new`
    - Server GI `Clutter.Clone.new`
      - Return clone lid
- ✔️ Client `child.allocate(child_box)`
  - RPC `Clutter-Actor.allocate`
    - Server GI `clutter_actor_allocate`
      - Return empty

### 6.2 Surface size on that window actor

This is the first call in 6.1.

**Client** `src/client/libshell-16/WindowPreviewLayout.vala`

```vala
this.source = (Clutter.Actor) window.get_compositor_private();
```

**Client** `src/client/libmutter-rpc-16/overrides/Window.override.vala`

```vala
public GLib.Object? get_compositor_private()
{
    var response = Gsr.Client.Rpc.call_value(
        "Gsr-Mutter-Window.get_compositor_private", this);
    if (response.args.size < 1) {
        return null;
    }
    var actor_lid = response.args.get(0).get_uint64();
    if (actor_lid == 0) {
        return null;
    }
    if (Gsr.Client.Rpc.client.proxies.has_key((int) actor_lid)) {
        var existing = Gsr.Client.Rpc.client.proxies.get(
            (int) actor_lid) as WindowActor;
        if (existing != null) {
            if (existing.bound_meta_window == null) {
                existing.bound_meta_window = this;
            }
            return existing;
        }
    }
    var actor = new WindowActor();
    actor.rpc_lid = actor_lid;
    actor.bound_meta_window = this;
    Gsr.Client.Rpc.register_handle(actor);
    return actor;
}
```

**RPC** `Gsr-Mutter-Window.get_compositor_private`

**Server** `src/server/libmutter-16/Window.vala`

```vala
public void get_compositor_private(OLLMrpc.Request request)
{
    var window = (global::Meta.Window) request.connection.leases.get(
        (int) request.lease_id);
    var priv = window.get_compositor_private()
        as global::Meta.WindowActor; // the gedit window's actor. This is an object.
    uint64 lid = 0;
    if (priv != null) {
        lid = request.connection.export(priv);
        // First Clutter child of the window actor: the Wayland surface container.
        // The gedit surface is inside it. This function does not set its size.
        var child = priv.get_first_child();
        child != null ? child.width : -1
        child != null ? child.height : -1
    }
    request.reply(new OLLMrpc.Response() {
        id = request.id,
        args = OLLMrpc.args("t", lid),
    });
}
```

- ✔️ Return `t` lid. Client `Window.override.vala` reads that lid.
- 🚫 `child.width` and `child.height` are 0. `get_compositor_private` reads them. It does not set them.

**`meta_window_actor_sync_actor_geometry`** in `meta-window-actor.c`. `actor` is the window actor, the same object as `priv` above. It is not `child`.

```c
meta_window_get_buffer_rect (priv->window, &actor_rect);
if (changes & META_WINDOW_ACTOR_CHANGE_SIZE)
  clutter_actor_set_size (actor, actor_rect.width, actor_rect.height);
META_WINDOW_ACTOR_GET_CLASS (self)->sync_geometry (self);
```

On a normal desktop this sets the window actor from the gedit window's buffer rect, 800 by 568.

Here it works as expected.

**`clutter_actor_real_queue_relayout`** in `clutter-actor.c`

```c
priv->needs_allocation = TRUE;
```

**`clutter_stage_maybe_relayout`** in `clutter-stage.c`

```c
clutter_actor_allocate_preferred_size (queued_actor, x, y);
```

**`clutter_actor_allocate`** in `clutter-actor.c`

```c
if (!CLUTTER_ACTOR_IS_TOPLEVEL (self) &&
    !clutter_actor_is_mapped (self) &&
    !clutter_actor_has_mapped_clones (self))
  return;
```

On a normal desktop a mapped actor is given a box.

Here it does not work as expected. The window actor and the surface container are unmapped, so this return runs and no box is stored.

**`clutter_actor_get_width`** in `clutter-actor.c`

```c
if (priv->needs_allocation)
  {
    gfloat natural_width = 0;

    if (priv->request_mode == CLUTTER_REQUEST_HEIGHT_FOR_WIDTH)
      clutter_actor_get_preferred_width (self, -1, NULL, &natural_width);
    else if (priv->request_mode == CLUTTER_REQUEST_WIDTH_FOR_HEIGHT)
      {
        gfloat natural_height = 0;

        clutter_actor_get_preferred_height (self, -1, NULL, &natural_height);
        clutter_actor_get_preferred_width (self, natural_height,
                                           NULL, &natural_width);
      }
    else if (priv->request_mode == CLUTTER_REQUEST_CONTENT_SIZE &&
             priv->content != NULL)
      clutter_content_get_preferred_size (priv->content, &natural_width, NULL);

    return natural_width;
  }
else
  return priv->allocation.x2 - priv->allocation.x1;
```

On a normal desktop `needs_allocation` is clear and this returns the stored box.

Here it does not work as expected. `needs_allocation` is set, so this returns `natural_width`, which is 0.

**`clutter_actor_real_allocate`** in `clutter-actor.c`

```c
clutter_actor_set_allocation_internal (self, box);
if (priv->n_children != 0 &&
    priv->layout_manager != NULL)
  clutter_layout_manager_allocate (priv->layout_manager, self, &children_box);
```

On a normal desktop a layout manager allocates the children.

Here it does not work as expected. The window actor has no layout manager, so `child` is not given `box`.

**`do_sync_geometry`** in `meta-window-actor-wayland.c`

```c
if (!clutter_actor_is_mapped (CLUTTER_ACTOR (actor)))
  return FALSE;
clutter_actor_set_position (surface_container,
                            (child_actor_width - surfaces_width) / 2,
                            (child_actor_height - surfaces_height) / 2);
```

On a normal desktop the window actor is mapped, and this sets the container's position.

Here it does not work as expected. The window actor is unmapped, so this returns before `set_position`. `set_position` does not set the container's size.

### 7. The orange outline on the selected workspace tab

```js
const thumbnailFullHeight = Math.round(portholeHeight * this._scale);
const thumbnailWidth = Math.round(thumbnailFullHeight * ratio);
const thumbnailHeight = thumbnailFullHeight * this._expandFraction;
```

```js
childBox.x1 = indicatorX1 - indicatorLeftFullBorder;
childBox.x2 = indicatorX2 + indicatorRightFullBorder;
childBox.y1 -= indicatorTopFullBorder;
childBox.y2 += indicatorBottomFullBorder;
this._indicator.allocate(childBox);
```

On a normal desktop the outline is the size of the workspace tab, and the tab shows a tiny gedit.

Here it does not work as expected. The inside of the tab is blank. While `_scale` is still 0 the outline is only the border, which is the dot from the early looks. In the 20:58 picture the outline is 29 by 22 pixels.

**Reproduction:**

```bash
GI_META_SMOKE=thumbnail-smoke \
GI_META_SMOKE_CMD='gedit --new-window' \
GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
GSR_NESTED_TIMEOUT=40 \
./scripts/agent-nested-smoke-prove.sh
```

The script printing `thumbnail-smoke: ok` only means the window thumbnail was built. It does not mean the window thumbnail shows gedit. The check is looking at the window thumbnail.

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

### 2026-10-10 live actor clone

`get_compositor_private` returns the live actor. `WindowPreviewLayout` clones it. `preview_actor` is gone.

10:03, `GSR_NESTED_TIMEOUT=70`: `compositor-private=live 800x568`, `preview-clone … same-source=0 source-other=1 clone-allocated=1 other=800x568 "Untitled Document 1 - gedit" hit=true`, `phase1-ok`, `phase2` two previews, `thumbnail-smoke: ok`. Weston stayed up until the prove kill.

10:36, same command with timeout 40, smoke now logs `clone-size`. `clone-size=800x568`, preview widget `478.2×339.5`, then phase 2 `254×180` each. `thumbnail-smoke: ok`.

10:47, `GLib.debug` in `WindowPreviewLayout.allocate_vfunc`: `preview-allocate box 800.0x568.0 bound 800.0x568.0 scale 1.000 1.000 nat 800.0x568.0 out 800.0x568.0` (twice). The layout never scaled. The container's allocation was the window size. Stock `shell_window_preview_allocate` clamps children with `clutter_actor_allocate_available_size`. This `WindowPreview` had no `allocate_vfunc`, so `St.Widget` gave the container its preferred size.

`WindowPreview.allocate_vfunc` now does that clamp (height-for-width) and `set_allocation` when the child's layout manager is client-local.

11:03 two proves: `thumbnail-smoke: miss TypeError: global.stage.context is null` at `main.js` (`global.stage.context.get_backend()`), before any preview. Same miss as 09:30. Exit 0 after about 4s. A hold from 11:04 (`nested-weston-hold.sh`, weston pid 373374) reached `READY=1` at 11:04:47 with this library.

Hand look after that hold: Weston stayed up, two apps started, top tabs showed pictures, big cards still wrong. Client and mutter debug logs were truncated at 11:32 (`Failed to setup: Unable to open display ':3'`). No `preview-allocate` from that look survived.

11:38 prove, same smoke command: `preview-slot` content `478×340`, `preview-allocate … scale 0.598 … out 0.0,0.0 478.0x340.0`, smoke `clone-size=478x340`. Phase 2: slot and clone `254×180`, `thumbnail-smoke: ok`. `realized` is not writable on `Gjs_ui_windowPreview_WindowPreview` at 11:38:00.419 (and again as the second window's card appears).

16:55 capture of the Weston window during overview: the main card is the mountain wallpaper. 17:16, once the clone exists: `clone-opacity=255 clone-mapped=true source-realized=true source-mapped=false`. 18:05 server: `Window.vala` `compositor-private mapped=no realized=yes`. `clutter_actor_paint` returns on an unmapped actor, so the clone is empty.

### 2026-10-10 18:28 map effect

`Plugin.map` calls `actor.show()`. The actor is created with `show-on-set-parent` false, so it starts hidden. 18:28:21 `plugin-map after visible=yes mapped=yes` with the parent mapped. 18:28:22 `compositor-private visible=yes mapped=yes realized=yes parent-mapped=yes children=1`. Overview then hides the window group. 18:28:23 `visible=yes mapped=no parent-mapped=no`. `preview-allocate out 0.0,0.0 478.0x340.0`. `clutter_clone_paint` maps an unmapped source for the paint via `enable_paint_unmapped`. The unmapped flag is not why that paint returns. `clutter_clone_allocate` scales the source into the clone box.

19:38 and 19:42: mutter `g_error` in `clutter-box-layout.c` on minimum height `-12`, `mutter exited ec=133` during `main.start`, no preview. Same abort as [`done/2026-09-25-box-layout-negative-min-height.md`](done/2026-09-25-box-layout-negative-min-height.md). The `context is null` miss is the client after that abort.

20:04 capture (`/tmp/gsr-overview.png`, Weston window `90177541`): overview is up, the main card is the mountain wallpaper, the top tab is an orange mark, gedit has a dash dot. `plugin-map after visible=yes mapped=yes` at 20:04:24, `compositor-private … mapped=yes … children=1` at 20:04:26, then `mapped=no parent-mapped=no` at 20:04:28 when the overview hid the window group. `preview-allocate out 0.0,0.0 713.0x535.0`.

### 2026-10-10 20:58 clone is the card, paint unread

`meta_shaped_texture_get_clip_region` is not in the public header and not in `libmutter-16.so`, so the clip was not logged. `Clutter-Actor.get_width` / `is_mapped` / `has_allocation` on the clone after `allocate`: `preview-clone-geom server 478.0x340.0 mapped=yes has-alloc=yes`, then `254.0x180.0`. `get_source` lids match. `buffer=yes` after unmap. Preview `opacity=255 mapped=yes`. Same run's Weston window is the wallpaper card. The blank is not a missing clone, a zero box, an unmapped clone, or a missing buffer.

### 2026-10-10 21:20 the image is blank

`get_compositor_private` calls `Meta.WindowActor.get_image`. 21:20:45, window still mapped: `image=800x568 blank`, `child-opacity=255`, `child-visible=yes`, `buffer=yes`. The next 14 reads, including after the overview unmapped the window group, are the same blank `800×568`. `meta_shaped_texture_get_image` copies the texture with `cogl_texture_get_data` and ignores the byte count it returns, so a failed read is also a zero surface. The copy we got is zero.

### 2026-10-11 08:43 the texture has the pixels

Direct `cogl_texture_get_data` on plane 0, overview up, actor unmapped: `planes=1 readable=yes 800x568 bytes=1817600 pixels`, `child-opacity=255 child-visible=yes child=800x568`. `1817600` is `800×568×4`. The zero surface from `get_image` is that helper ignoring the byte count, not an empty texture. The card is still the wallpaper. The draw in `meta_shaped_texture_paint_content` is the step that does not show.

### 2026-10-11 10:48 baseline before paint/stacking probe

Command:

```bash
GI_META_SMOKE=thumbnail-smoke GI_META_SMOKE_CMD='gedit --new-window' \
GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 GSR_NESTED_TIMEOUT=70 \
./scripts/agent-nested-smoke-prove.sh
```

The existing structural gate passed: phase 1 clone `478×340`, phase 2 two
clones `254×180`, `thumbnail-smoke: ok`, and prove `stop (smoke-ok) after
17s`. This still does not test rendered pixels. Next reproduction-only probe
will capture the overview before and after hiding its workspace background,
and log that workspace's child order. No product file changed.

### 2026-10-11 11:12 stacking probe did not reach the reproduction

The same command with the reproduction-only capture/hide probe failed during
`main.start`: `thumbnail-smoke: miss TypeError: global.stage.context is null`.
This is the already-recorded startup abort symptom, before any window or
overview probe. It says nothing about stacking; retry required.

### 2026-10-11 11:13 stacking/occlusion refuted

Retry reached the probe. The active Workspace peer reports
`workspace-stack background=0 container=1 children=2`, matching stock order:
background below the preview container. Stage captures are
`/tmp/thumbnail-overview-before.png` and
`/tmp/thumbnail-overview-no-background.png`.

The first capture shows the mountain wallpaper in the main card. The second
hides that workspace's background and shows only the shell's dark overview
behind the same empty card area. Gedit does not appear. Therefore the preview
is transparent, not painted underneath the workspace background. The run
continued through phase 2 and printed `thumbnail-smoke: ok`; this confirms
again that `ok` is structural, not a pixel verdict.

### 2026-10-11 11:18 source-depth probe did not reach the reproduction

First run of the reproduction-only clone-source depth probe failed during
`main.start` with `global.stage.context is null`, before window creation.
This is another instance of the separate startup abort and gives no
source-paint result.

### 2026-10-11 11:18 window actor subtree is also transparent

Retry captured the same allocated overview clone while changing its source
from the live `Meta.WindowActor` to each of its first two descendants. Both
descendants report `800×568`, visible, and unmapped. Captures:

- `/tmp/thumbnail-overview-source-depth-1.png`
- `/tmp/thumbnail-overview-source-depth-2.png`

Both remain fully transparent with the workspace background hidden. The
failure is therefore not confined to the `Meta.WindowActor` wrapper's own
paint method; cloning the surface-container path also fails. The structural
smoke still reached `ok`.

### 2026-10-11 11:19 known-good panel source is also transparent

With the workspace background hidden, the reproduction changed the same
allocated preview clone's source to `main.panel`, waited 500 ms, and captured
`/tmp/thumbnail-overview-panel-source.png`. The real panel remains visible at
the top of the frame, but no panel image appears in the clone's card.

This refutes a window-texture-specific failure: the existing preview
`Clutter.Clone` does not show a known-painted St source either. Next probe
places an independent panel clone directly on the stage to separate a general
`Clutter.Clone` paint failure from the preview tree or its clipping.

### 2026-10-11 11:25 independent stage clone paints

`/tmp/thumbnail-overview-stage-clone.png` shows a separately constructed
`Clutter.Clone` of `main.panel`, sized `400×200` and parented directly to the
stage. It visibly paints the panel (stretched, as expected). Therefore
`Clutter.Clone` construction and paint work generally. The same panel source
is transparent through the existing preview clone, narrowing the failure to
that clone or its preview ancestry/allocation/clip path.

Next probe uses the live window actor as a direct stage-clone source. That
separates a window-source paint failure from the preview ancestry.

### 2026-10-11 11:26 stage-window probe did not reach the reproduction

The first run again hit the separate `global.stage.context is null` startup
abort before creating a window. No stage-window clone result; retry required.

### 2026-10-11 11:35 live window paints through a stage clone

Retry capture `/tmp/thumbnail-overview-stage-window-clone.png` visibly shows
gedit's file chooser through an independent clone of the exact live
`Meta.WindowActor`, parented directly to the stage. This refutes both a
window-source paint failure and a general clone failure.

The failure is now bounded to the overview preview scene path: the same live
window source paints from a stage clone, while the stock preview clone remains
transparent. Next probe places a solid actor in the same
`window_container`; that tests whether the preview subtree itself is clipped
or misplaced, independent of cloning.

### 2026-10-11 11:47 solid preview child is also invisible

The reproduction added an opaque red `Clutter.Actor` (`400×284`) to the
affected `WindowPreview.window_container` and captured
`/tmp/thumbnail-overview-solid-child.png` with the workspace background
hidden. No red pixels appear. In the same run both direct stage clones still
paint.

This refutes the clone as the immediate failing actor. The whole preview
subtree is not reaching the visible frame, despite the preview and clone
reporting mapped allocations. Next probe records the preview-to-stage ancestor
chain, including paint opacity and transformed geometry.

### 2026-10-11 11:49 ancestor probe did not reach the reproduction

The first ancestor-chain run hit the separate
`global.stage.context is null` startup abort before window creation. No
ancestor result; retry required.

Second ancestor-chain attempt at 11:50 hit the same startup abort, also before
window creation. Retry still required.

Third attempt at 11:51 hit the same startup abort before window creation.
Fourth attempt at 11:56 hit it again. The ancestor probe remains unrun.

### 2026-10-11 11:56 ancestor chain with pixman parent

Running the same reproduction with `GSR_WESTON_PIXMAN=1` avoided the startup
abort. From `WindowPreview` through its Workspace, WorkspacesView,
WorkspacesDisplay, ControlsManager, OverviewActor, overview group, and
`UiActor`, every ancestor is visible, mapped, effective paint opacity 255, and
has nonzero transformed geometry. The preview itself is transformed to
`160.375,126.398 478.203×339.527`, inside the `800×600` overview.

`MetaStage.get_transformed_size()` alone reported `70.695×53.019` despite
stage `width×height=800×600`; direct stage clones paint, so that anomalous
getter does not explain only the preview subtree. There is no zero-sized or
transparent ancestor. Next probe starts the same chain at the clone, adding
its `window_container` transform to the evidence.

### 2026-10-11 11:59 clone-chain probe missed the window

The first pixman-parent clone-chain run reached launch but no Meta NORMAL
window appeared before the smoke deadline: `miss window`. It did not reach
the overview; retry required.

The 13:04 retry with a 15-second window deadline hit the separate
`global.stage.context is null` startup abort before launch.

### 2026-10-11 13:09 first bad transform found

Pixman-parent retry reached the clone chain. `WindowPreview` is sane at
`160.375,126.398 478.203×339.527`. Its immediate child
`window_container` reports nonzero `800×568`, mapped and paint opacity 255,
but `get_transformed_position()` and `get_transformed_size()` both return
`NaN`. The clone below it is likewise `NaN`. Every ancestor above the
`WindowPreview` remains finite.

This is the first property that directly explains the invisible subtree:
Clutter cannot place or cull descendants whose model-view transform contains
NaN. Setting `WindowPreview.offscreen_redirect` from
`AUTOMATIC_FOR_OPACITY` (`1`) to `NEVER` did not change the blank capture
(`/tmp/thumbnail-overview-no-offscreen.png`), so offscreen redirect is
refuted.

The likely source is now the `windowContainer` transform inputs, especially
its construct-time pivot point or scale. Next reproduction-only probe rewrites
those stock values and checks whether the transform and picture become finite.

### 2026-10-11 13:21 transform-reset probe did not reach reproduction

The first pivot/scale reset run hit `global.stage.context is null` during
startup. It produced no transform result; retry required.

### 2026-10-11 13:50 invalid allocation relay is the cause

Successful retry reports `window_container pivot=0.5,0 scale=1,1`. Rewriting
the pivot to `0.5,0.5`, then forcing scale through `0.999` back to `1`, leaves
the container and clone transforms `NaN`; both captures remain blank. Pivot,
scale, and offscreen redirect are not the cause.

The same run's mutter log names the failure:

```text
Clutter-Actor.set_allocation
The clutter_actor_set_allocation() function can only be called from within
the implementation of the ClutterActor::allocate() virtual function.
```

This is `WindowPreview.allocate_vfunc` calling `child.relay_allocation()` for
the client-local `WindowPreviewLayout`. The nested
`window_container` is not inside its own server-side allocate vfunc, so Clutter
rejects the allocation. Then client `Actor.allocate()` sees the local layout
manager and runs only `layout.allocate_vfunc()`; it never invokes the
container's server allocate path. The container retains its full-window
`800×600` allocation while its clone has the card allocation, and its
model-view transform becomes `NaN`.

Next reproduction-only trial temporarily detaches the local layout manager,
uses the cached intended box through the real server allocate path, and checks
whether the transform and gedit pixels appear. Product code remains unchanged.

### 2026-10-11 13:56 real server allocation makes gedit visible

The reproduction-only trial detached `WindowPreviewLayout`, called the
container's real server allocate path, and captured
`/tmp/thumbnail-overview-after-server-allocate.png`.

After that call, the clone transform becomes finite:
`160.375,126.398 478×340`, and the capture visibly shows gedit in the main
overview card. Before the call, the same clone and source were `NaN` and
transparent. This proves allocation—not texture capture or cloning—is the
remaining cause.

The cached test box happened to be zero, so the container reports `0×0`, but
the already allocated clone still paints because the container does not clip.
The product landing must send the actual `child_box` through the server
`Clutter-Actor.allocate` call while the server-side proxy layout manager is
still attached; that sets the container allocation and relays child allocation
normally. This is a minor change in `WindowPreview.allocate_vfunc`.
