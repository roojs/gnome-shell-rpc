# Window overview has no thumbnails

**Status:** ⏳ open. Picker clicks are [`done/2026-10-06-picker-click-get-time.md`](done/2026-10-06-picker-click-get-time.md).

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

`Meta-Window.get_compositor_private` is now a hand method. It returns the compositor private object under the nearest registered type, so the overview can clone it. Not proven on a new login yet.
