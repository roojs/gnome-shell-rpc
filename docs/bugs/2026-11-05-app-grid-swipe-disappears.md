# App grid disappears on an upward mouse swipe

**Status:** Seen on the Ubuntu 26.04 emulator `alan@192.168.122.115`
(`ubuntu2604`, GNOME Shell 50.1). Session started 20:02:48 HKT:
`gsr-server` pid 53226, `gsr-client` pid 53472. This client was not
started with `--debug`, so the cache debug log is still the previous
session. The trace is `journalctl -b _PID=53472`. `src/` has not been
changed. No gate yet.

A mouse press in the app grid, below the icons, dragged upward, makes
the grid disappear. The swipe tracker is updating from a `NaN` position.

## What the log shows

`gsr-client` pid 53472, 126 times from 20:03:14 to 20:03:16:

```text
Invalid position NaN
_findPreviousPoint@resource:///org/gnome/shell/ui/swipeTracker.js:531:17
_getBounds@resource:///org/gnome/shell/ui/swipeTracker.js:557:25
_updateGesture@resource:///org/gnome/shell/ui/swipeTracker.js:573:61
_updatePanGesture@resource:///org/gnome/shell/ui/swipeTracker.js:584:14
@resource:///org/gnome/shell/ui/init.js:20:20
```

Shell 50.1 `vendor/gnome-shell` on that guest. Line 531 is

```javascript
console.trace(`Invalid position ${pos}`);
```

inside `_findPreviousPoint`. Line 573 calls `_getBounds(this._initialProgress)`,
so the `NaN` is `_initialProgress`. `_updatePanGesture` is the mouse-drag
path (`Clutter.PanGesture` `pan-update`).

## Where that NaN is stored

`confirmSwipe` is the only writer of `_initialProgress` after reset:

```javascript
this._initialProgress = currentProgress;
this._progress = currentProgress;
```

The app grid is the swipe tracker that allows a one-point mouse drag.
It is attached to the grid's scroll view (`appDisplay.js`,
`AppDisplay swipe tracker`). On `begin` it does:

```javascript
const progress = adjustment.value / adjustment.page_size;
tracker.confirmSwipe(size, points, progress, Math.round(progress));
```

`adjustment` is `this._scrollView.hadjustment`. `value / page_size` is
`NaN` when the page size is `0` and the value is `0`, or when either
side is already `NaN`. That `NaN` is what `_findPreviousPoint` prints on
every motion event of the drag.

Each update then does:

```javascript
adjustment.value = progress * adjustment.page_size;
```

The progress clamped from a `NaN` initial position stays `NaN`, so the
scroll adjustment is set to `NaN` and the grid leaves the screen.

The overview's own swipe tracker is vertical, which matches an upward
drag, but it is created with `allowDrag: false` (three fingers) and its
`confirmSwipe` progress is the overview state value. The app grid is on
screen, so that state value is a real snap point (`APP_GRID`), not the
`NaN` in this log.

## LLM efforts

- 2026-11-05 20:04 HKT. User: on the app picker, a mouse press below the
  icon grid and a swipe upward makes the whole grid disappear. The new
  session's `gsr-client` is pid 53472, started 20:02:48 without
  `--debug`. `journalctl -b _PID=53472` has 126 `Invalid position NaN`
  traces from `_updatePanGesture` between 20:03:14 and 20:03:16. Read
  `swipeTracker.js`, `appDisplay.js` `_swipeBegin`, and
  `overviewControls.js` `gestureBegin` on the guest's Shell 50.1 tree.
  The logged position is `_initialProgress`, set from
  `hadjustment.value / page_size` on the app-grid tracker. Did not edit
  `src/`.
