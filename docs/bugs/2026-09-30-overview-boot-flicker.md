# Overview flashes during boot, then the picker button lies

> **Do not stop** to narrate a prove, a dead end, or a rebuild. Update this bug and take the next phase. Stop only if you need the user, or if OPC is the problem (FAIL gate, then stop).

**Status:** ⏳ open. User 2026-09-30. Only UI bug. RPC flood: [`2026-09-30-rpc-call-volume.md`](2026-09-30-rpc-call-volume.md).

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

## Works

- Session starts. Black until the first frame is fine.
- Icon click launches a program.
- No apps running: desktop background in the middle.

## Boot

Overview stays on the picker. User 2026-09-30, after phase 2.

Log still busy after the picture settles. That is the RPC flood.

## Picker button

Highlighted while the overview is closed.

- First click: highlight off, or nothing.
- Next click: overview flashes, then hides.

## Layout (only when it stays up)

Shots 14:31. Left: our nest. Right: GNOME Shell.

| | Ours | GNOME Shell |
| --- | --- | --- |
| Search | Under the panel | Hidden behind a notification in that shot |
| Current workspace | Small, dark gap on the left | Large, icons and a window on it |
| Next workspace | Sliver on the right | Slice on the right |
| Dash | Icon row at the bottom | Icon row at the bottom |
| Extra | Orange dot under the search | |

## Phases

| Phase | Find out | Change |
| --- | --- | --- |
| 1 | Which call closes the overview on a hidden boot | No `hide()`. Grab ok. It is still shown. |
| 2 | Why the picture can look like the desktop while the log says shown | State transition interval peeked as 0, so the workspace got the full-screen hidden box. Mirror keeps the real 0→1. A stuck transition still lays out the picker. |
| 3 | Dash missing on the picker | Show-apps item preferred width was 0. Its layout manager said 48. The button now allocates 44×80. |
| 4 | Grey square over the dash | Workspace thumbnails. Asking for their own preferred size during allocate returned 0, so the scale went negative and the full-size thumbnail backgrounds painted over the dash. Preferred size during allocate now runs the size vfunc. Scale is positive. The icon row is visible. |
| 5 | Why the top-left button does not open and close the overview | Click proves 17:29–17:32. The click is the hot corner, not the button vfunc. Hide starts. `hide-done` is not reliable: absent for 5s, then present in 0.7s after a `stopped` subscribe, then absent again for 5s with that same subscribe. While `anim` stays true the next click is refused. Subscribe reverted. |

Phase 1 probe stays at `src/shell-js-probe/overview-boot/ui/overview.js`. Layout waits.

---

## LLM only — reading I don't give a crap about

Not the work list. Do not paste this above the line. Do not treat guesses as the next edit.

**Stock boot (GNOME Shell 48, installed `libshell-16.so`, same text in `vendor/gnome-shell`).** `user` mode `hasOverview: true`. `layout.js` `_startupAnimationSession` calls `Main.overview.runStartupAnimation()` and leaves the overview open. Ubuntu dock skips that only when `disable-overview-on-startup` is true. Schema default is false. This machine's value is false.

**`overview.js` `runStartupAnimation`.** Sets `_shown`, `showOverview()`, state `SHOWING`, awaits `ControlsManager.runStartupAnimation`. Two bails: state is no longer `SHOWING` (something called `hide()` during the fade; the comment is “Overview got hidden during startup animation”), or `_syncGrab()` fails and calls `hide()`. Grab fails when `global.display.is_grabbed()` or `grab.get_seat_state() !== Clutter.GrabState.ALL`.

**`ControlsManager.runStartupAnimation`.** Sets adjustment to `HIDDEN` and opacity 0 (comment: avoid a 1-frame flicker), then eases to `WINDOW_PICKER` and opacity 255. Search slides down, dash slides up. `showAppsButton.checked = false` (dash grid button, not Activities).

**`_relayout`.** Connected to `monitors-changed` in `Overview.init`, and called once from `init`. Always calls `hide()`. `hide()` returns immediately when `_shown` is false. A monitor change after `_shown = true` closes the overview. One before that does not. Matches “usually hidden, sometimes stays up”. `layout.js` connects `Meta.MonitorManager::monitors-changed` to `_monitorsChanged`, which emits `LayoutManager::monitors-changed`.

**Activities button.** `panel.js` adds pseudo-class `checked` on overview `showing`, removes it on `hiding`. A lit button with the picture already the desktop means `showing` fired and `hiding` did not. A finished `hide()` emits `hiding`.

**Click.** Activities runs `overview.toggle()`. If `_visible` is still true, the click hides. Next click shows, then the same bail can hide it again.

**Pictures (14:31).** Both shots are the window picker: current workspace plus the next one on the right. No row of four grey squares in either shot. Do not cite the old 190×30 thumbs probe as “they are there but small”.

**Row math (`workspacesView.js`, `FitMode.SINGLE`).** Width = `height * workarea.width / workarea.height` (`Workspace.vfunc_get_preferred_width`). Current box: `x += (viewWidth - width) / 2 - index * (width + spacing)` (`_getFirstFitSingleWorkspaceBox`). Next workspace is the same size, immediately to the right. Inactive scale 0.94. A too-small width is a dark gap on the left and the next workspace shoved to the right edge. Dash is not in this file. It is allocated at the bottom of `ControlsManagerLayout.vfunc_allocate`.

**Phase 1 result (2026-09-30 ~15:24–15:26).** `GSR_NESTED_STAYUP=1` `GSR_NESTED_TIMEOUT=18` `GI_RPC_JS_OVERRIDE_DIR=src/shell-js-probe/overview-boot`. Three boots. Overlay loaded (`js override overlay 1 files`). Each boot:

- `relayout` / `hide-skip` `shown=false` during `_initializeUI` (`main.js:276`). Not a close.
- `startup-enter` from `layout.js` `_startupAnimationSession`.
- `syncGrab-ok` `seat=3` (`Clutter.GrabState.ALL` is 3).
- `startup-shown` `state=SHOWN`.

No `hide`, no `startup-hidden-during`, no `syncGrab-grabbed`, no `syncGrab-seat`, no second `relayout`. Exit 137 on the prove script is Weston being SIGKILLed when the timeout ends, not a shell crash. A hidden boot was not caught. Do not invent a caller. Next log is opacity / adjustment while state stays `SHOWN`.

**Phase 2 result (2026-09-30 ~16:09).** Stuck transition `tp=1/0->1` `tr=true` still laid out `display=0,126 800x383`, the picker, not the full-screen hidden box. `set_to` / `add_transition` copy the interval endpoints into the client mirror that `peek_*` reads. Before that, both peeks were 0 and the workspace was given the HIDDEN box (`800x568`), which covers the dash and looks like the desktop. The activities button stays checked because `hide()` does not run.

**Phase 3 result (same boot).** `DashItemContainer` preferred width was `0/0` while `scale_x` was 1, the show-apps button was `48/48`, and `BinLayout` was `48/48`. The JS preferred-width vfunc scales the parent size; that parent call returned 0, so the item allocated `0x80` and the icon was `1x32`. The preferred-size relay now uses the layout manager when the vfunc result is 0 and the layout is not. After that: `item=240,0 48x80`, `btn=2,0 44x80`. `SquareBin` width is the server bin's height (`Helper-Actor.base_preferred_height`), because `get_preferred_height` returns 0 while a preferred-size hook is active. Base icon measured `44/44`.

The picker card stays `540x383` in the `800x568` work area. That is `ControlsManagerLayout` WINDOW_PICKER after search 55, thumbnails 28, and dash 80. The GNOME shot is the Ubuntu session (dock, desktop icons). This nest is the stock overview.

**Phase 4 result (2026-09-30 ~16:50).** Thumbnail scale was `-0.021` because preferred height during allocate returned 0. Full-size thumbnail backgrounds covered the dash. After the size-hook split, scale is `0.029` and the icon row is visible.

**Phase 5 click proves (2026-09-30 17:29–17:32).** Probe `pointer_click` at the Activities button center `(48,16)`. Each click enters `HotCorner._toggleOverview` (`layout.js:1277`). No `ActivitiesButton.vfunc_event`.

| Run | `stopped` subscribe | After the click |
| --- | --- | --- |
| 17:29 | no | `hide` at 17:29:18. `click-2` at 17:29:23 still `HIDING` `anim=true`. `should-toggle` `why=anim`. No `hide-done`. |
| 17:31 | yes | `hide` at 17:31:16. `hide-done` at 17:31:17 from `onStopped@overviewControls.js:748`. State `HIDDEN` `anim=false`. Second click did not call `toggle` (corner already entered). |
| 17:32 | yes | `hide` at 17:32:43. At 17:32:48 still `HIDING` `anim=true`. `should-toggle` `why=anim`. No `hide-done`. |

`Adjustment.ease` connects `stopped` after `add_transition`. `Actor.ease` subscribes in `get_transition`. The subscribe made `hide-done` arrive once and miss once. It is not the fix. Reverted. Do not put it back on this table.

**🚫** vendor `js/` as the ship path. **🚫** Idle. **🚫** layout.js ship hack. Overlay is a probe.
