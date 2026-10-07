# Window overview has no thumbnails

**Status:** ⏳ open. Picker clicks are [`done/2026-10-06-picker-click-get-time.md`](done/2026-10-06-picker-click-get-time.md).

**Working rule for this bug:** no status theatre — do not stop to narrate, summarise, or ask to continue. Keep proving until the bar moves or a real stop condition hits.

`alan@192.168.88.197`, session 6, 14:03. Help (`/usr/bin/yelp` 6040) and Terminal (`gnome-terminal-server` 6314) were running. The window overview drew no thumbnails.

Both windows were created with no title and no size. Server:

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

The same throw repeats at 14:03:38.082 from `_windowAdded`. GNOME Shell 48 `windowPreview.js` line 133 is `app.create_icon_texture`, and `app` is `Shell.WindowTracker.get_default().get_window_app(metaWindow)`.

The client log has `window-entered-monitor` and the custom `Window.created` notification. It never has `method=window-created`. `WindowTracker` listens for `display.signal_window_created` and only then puts the window in its map. `get_window_app` returned null, the preview constructor threw, and the workspace never got a clone.

`notify::title` on that window logs `property 'title' of object class 'MetaWindow' is not writable`. `focus-window` on `MetaDisplay` is the same. Those are not the line that drops the thumbnail.

## Fix

`WindowTracker.get_window_app` associates the window on the first ask when `window-created` has not arrived yet. The 2026-10-07 09:17 nest no longer logs `app is null`.

The preview still never gets a clone. `windowPreview.js` calls `metaWindow.get_compositor_private()` before `create_icon_texture`. Every call that morning returned `-32602` with an empty message (`Meta-Window.get_compositor_private`, ids 20002 onward). Typelib dispatch refuses the return because the GIR type is bare `GObject`, even when the live object is a window actor already aliased as `Meta-WindowActor`.

Returning the live window actor and cloning it killed Weston at 09:31 (Xwayland `Broken pipe`, session SIGKILL). That path is not coming back.

`get_compositor_private` returns one stand-in per window (`Meta.WindowActor` with `meta_window` set). The picture is painted into that actor by `Gsr-Mutter-Window.preview_actor`, and the overview clones the stand-in. The live window actor stays on the stage.

2026-10-07 10:20: the empty actor from the previous stand-in had no `meta_window`, so leaving the overview threw `TypeError: win is undefined` in `workspaceThumbnail.js` `_isMyWindow`. `preview_actor` ran once, in the same second the window was still `frame=0,0 0x0`, and `size-changed` was never subscribed, so the paint was not repeated after the window had a buffer.

## 2026-10-07 10:31

The overview no longer crashes. There is still no picture of the windows.

The bottom footer app select does not raise the window that was clicked. Help and Terminal were both open. Clicking Terminal in that footer left Help on top when the overview returned to the desktop.

## 2026-10-07 17:50 gedit

ℹ️ The window under test is gedit, one process on `wayland-mutter-gsr`. Not gnome-terminal, and not the host gedit (that one stays on `DISPLAY=:0`). The weston-terminal beside the stage is only the debug log.

✔️ Nested debug session, `gsr-server` 3116041, `gsr-client` 3116070. `READY=1` at 17:49:32. gedit 3116646 started 17:50:06 with `GDK_BACKEND=wayland`, `WAYLAND_DISPLAY=wayland-mutter-gsr`, and the nested session bus. `DISPLAY` was unset so it did not open on the host.

✔️ Server, 17:50:08.147: `window_created title=(null) frame=0,0 0x0`. One compositor window actor. Then `notify::title` twice, each `property 'title' of object class 'MetaWindow' is not writable`. Then `size-changed`, and `Gsr-Mutter-Window.preview_actor` at 17:50:08.156 and again at 17:50:08.230. No `preview_actor:` warning. No `app is null`.

✔️ Client order is still `window-entered-monitor`, then `Window.created`. No `method=window-created`.

✔️ Activities click at 17:51:55 hit `panelActivities`. `WindowPreview` measured `nat=1546` by `nat=1034`. `preview_actor` ran once more (id 29901). `Clutter-Grab.dismiss` followed in the same second. The stage stayed on the wallpaper. gedit's window was not drawn on it. The overview did not stay up.

## Repro (user, by hand)

Boot the nested debug session, open the app picker, type `gedit`, start it, gedit running, back to the app picker. No preview. That is the whole repro. Window under test is gedit, not a terminal.

## 2026-10-07 18:02 thumbnail-smoke.js (not yet run)

ℹ️ Repro script written: `tests/gjs-embed/thumbnail-smoke.js`. Boots product `main.start`, launches `gedit --new-window` on the nested display via Gio (same env shape as `wayland-launch-smoke`), waits for a Meta NORMAL window with a real frame, checks `get_window_app` non-null, shows the overview in-process, waits for the `preview_actor` repaint, then asserts the `get_compositor_private()` stand-in has non-null content and a non-zero `WindowPreview` exists. Pass is `thumbnail-smoke: ok`, fail is `thumbnail-smoke: miss <reason>`. No product code changes from that file. The fix that makes it pass is what gets ported into `src/`.

✔️ `build/src/gsr-smoke` exists, so `GI_META_SMOKE=thumbnail-smoke` resolves.

❌ The 18:02 session restart never booted: Weston failed with `failed to create egl surface` / `Enabling output "screen0" failed`, exit 1. The smoke has not printed a verdict yet. Next step is one thing only: rerun the session with the smoke and read the `miss` line.
