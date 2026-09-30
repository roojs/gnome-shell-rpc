# Overview: Terminal does not start from the icon

**User goal:** nested mutter-rpc + gnome-shell-rpc stays up and the boot overview matches stock WINDOW_PICKER, and clicking an app icon launches it. From [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md).

**Status:** ✔️ archived 2026-09-30. User: an icon click launches a program. Boot flicker, the highlighted picker button, and overview layout are [`../2026-09-30-overview-boot-flicker.md`](../2026-09-30-overview-boot-flicker.md). The table below is the old score, not the live one.

2026-09-29 15:58: a click launched GNOME Settings inside mutter (`Updating client: name='GNOME Settings'`). The shell then died:

```text
connection write error: Unregistered class type schema: MetaWindowWayland
Client.vala:702: Unexpected early end-of-stream
```

The Settings window stayed mapped in mutter. The shell process was gone, so later Terminal clicks left the starting spinner and never launched again. `Type.from_name("MetaWindowWayland")` does not load the class (`G_DEFINE_TYPE`), so the boot alias was skipped and the same write error returned at 16:25:06. `Server.start` calls `meta_window_wayland_get_type()` and aliases that to `Meta-Window`. Nested mutter is `--no-x11`.

Create carries the override list
([`done/2026-09-27-actor-created-before-overrides.md`](2026-09-27-actor-created-before-overrides.md)).

| # | What | Stock piece | Seen |
| - | ---- | ----------- | ---- |
| 1 | Desktop preview | Wallpaper inside the current-desktop frame | **Regressed 2026-09-28.** `set_allocation` was only a client cache, so the server actor never stored the box (`needs an allocation`). |
| 2 | Icon click | Dash icon → `AppIcon.vfunc_clicked` → `Shell.App.launch` | **Closed 2026-09-30.** User: an icon click launches a program. [`2026-09-27-clicked-signal-misses-vfunc.md`](2026-09-27-clicked-signal-misses-vfunc.md) |
| 3 | Stray rectangle | Unknown actor | Still open. Not this pass. |
| 4 | Bottom chooser | Dash | Still open. Not this pass. |

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Supersedes (archived 2026-09-24):**

- [`done/2026-09-16-chrome-panel-menus-overlay.md`](2026-09-16-chrome-panel-menus-overlay.md) — panel, menus, grey overlay, WINDOW_PICKER layout
- [`done/2026-09-22-search-result-click-no-launch.md`](2026-09-22-search-result-click-no-launch.md) — icon click does not spawn

**Archived with this board clear:** [`2026-09-22-style-changed-manual-subscription.md`](2026-09-22-style-changed-manual-subscription.md) — `local_emit_after` setter bridge. Taken off the board 2026-09-30. The bridge may still be in the tree.

Full logs and rejected edits stay in those files. This file is the old score.

---

## Seen (user, 2026-09-24)

Historical. The live score is the table at the top.

Stock `user` mode lands on WINDOW_PICKER after boot: search, workspace thumbnails, current-desktop pane, dash.

Re-confirmed unchanged by the user on 2026-09-25 16:08. Row 1 has since closed.

| # | What | Stock piece | Seen |
| - | ---- | ----------- | ---- |
| 1 | Desktop preview | Current-desktop pane: wallpaper plus window thumbnails (`WorkspacesDisplay` / `WorkspaceBackground`) | **Gone** on this date. Was visible 2026-09-17 ~16:37. Closed by the user on 2026-09-27. |
| 2 | Icon click | App icon → `AppIcon.vfunc_clicked` → `Shell.App.launch` | **Did not start the app.** Still the current row. |
| 3 | Stray rectangle | Unknown actor | Roughly square rectangle, mostly on the **right**, on top of the preview desktops. Small **red dot** at its top-left, just **below the search bar**. Same family as the old “grey square + red dot ~2/3 along.” |
| 4 | Bottom chooser | Dash | **Not visible.** Open question: row 3 **is** that dash in the wrong place, or the dash has not appeared. |

---

## Stock layout (carried)

Not a miss that the overview is showing. Nested session is stock `user`, `hasOverview: true`. Startup eases **HIDDEN → WINDOW_PICKER** (`state=1`), `showAppsButton.checked=false`, and drops the search entry from the top. The app grid is only when `state > WINDOW_PICKER`. Search fill (icons in results) is closed: [`done/2026-09-19-overview-app-search-empty.md`](2026-09-19-overview-app-search-empty.md).

Top to bottom on real nested Shell:

1. Search bar (“Type to search”), below the panel.
2. Workspace thumbnail row (`ThumbnailsBox`).
3. Current desktop — wallpaper, plus window clones once apps are running. At a fresh boot that pane is wallpaper only.
4. Dash along the bottom.

Esc hides to idle. Hiding the overview after startup is a product deviation. **🚫** vendor `js/` hide, Idle, layout.js.

`overviewControls.js`: `startY = work.y - mon.y`. Search, thumbs, and the wallpaper pane originate at `startY`. That `startY` is the panel strut (`panelBox` `addChrome({affectsStruts: true})` → `Meta.Strut` TOP → `get_work_area_for_monitor`).

---

## Carried — picker layout

Last user score before today (2026-09-17 ~16:37): wallpaper / app thumbnails **showed**. Search and desktop panes **too high** (panel not in the workarea). Thumbnail row **still not visible**. Grey square + red dot ~2/3 along. User: not taking the menu bar into account.

Probe that day (`delayed15s` 15:51:16), actors existed, wallpaper child had been 0×0:

| Actor | Geom |
| ----- | ---- |
| search entryBin | `215,0 370x55` (`startY=0`) |
| thumbs | `shouldShow=true` mapped `305,62 190x30` (`nWorkspaces=4`) |
| workspaces pane | mapped `0,97 800x395` · ws0 `121,97 557x395` |

Thumbs at boot have **no** BackgroundManager (stock JS) — empty CSS frames until windows exist. A mapped thumbs actor can still look absent.

Gates from that week (re-prove):

| Gate | Then |
| ---- | ---- |
| `workarea-panel-inset-smoke` | **PASS** `startY=32` — strut → workarea on Meta |
| `workarea-panel-chrome-smoke` | **A/B PASS**, **FAIL C** `workareasHits=0`. `Display::workareas-changed` never reached GJS, so `ControlsManagerLayout._workAreaBox` stayed at construct `startY=0` |
| `workspace-background-allocate-smoke` | **PASS** `inner=800x400` after owned `Shell.WorkspaceBackground.allocate_vfunc` (was `inner=0x0`) |

Grey fill on the big pane was SystemBackground `#282828`, not `_coverPane` (opacity 0). Do not destroy `_coverPane` or force `_startingUp=false`.

Workspace selectors on the panel are closed (`workspace-dot-align-smoke` **C**, `buttonbox-hpadding-smoke`).

---

## Carried — icon click

Bar is still the session: overview → click an icon (Terminal) → the app opens. `app-search-launch-smoke: ok` does not close that.

**Works when called directly (2026-09-22):** `AppIcon.activate()` / `Shell.App.launch()` → compositor `Helper-AppLaunch.launch_desktop_file`. Gio reports success. `Helper-AppLaunch.make_launch_context()` unsets only the private `WAYLAND_SOCKET`. It does not unset `DISPLAY` or force `GDK_BACKEND`. After that, `app-launch-boundary-smoke` mapped `org.gtk.Demo4` on mutter (`ok target=mutter`). Terminal’s server can activate on the private nested bus and map NORMAL windows. Do not add a second launch Helper.

**Does not work on a real click (user 20:25, and again 2026-09-24, and again 2026-09-28 09:00):** press/release produced client `notification method=clicked`. `AppIcon.vfunc_clicked` did not run. No `Helper-AppLaunch` from that click. Three presses in `org.gnome.ShellRpc.debug.log` (09:00:49.968, 09:00:51.177, 09:00:51.329). Detail: [`2026-09-27-clicked-signal-misses-vfunc.md`](2026-09-27-clicked-signal-misses-vfunc.md).

`AppIcon` overrides `vfunc_clicked`. It does not `connect('clicked')`. There is no fallback in `appDisplay.js`.

Rejected the same day: a generic `clicked` subscribe in `Actor.override.vala`, and a hand-written `clicked_vfunc` class handler in `Button.override.vala`. The isolated smoke passed. The integrated shell crashed. Removed. Do not restore it.

The slot and the signal are separate on purpose. A virtual signal would sit at the end of the class and move `allocate`. The generator emits a plain virtual `clicked_vfunc` at the typelib byte, and a non-virtual `signal_clicked`. GJS writes `vfunc_clicked` into that byte. Emitting the signal does not load that byte, which is why the notification arrived and the app did not start. Nothing generated makes that emission call the slot. A `clicked`-only connect in the generator was tried and removed: Vala allows one `construct` per class, and it is a special case, not the class closure.

`Meta.Display.list_all_windows()` can fail RPC `-32602` while the compositor log has `Window.created`. `Shell.App.get_n_windows()` can stay 0 for that window. Do not treat `windows-normal=0` alone as “nothing mapped.”

Hypotheses the 2026-09-22 smokes already narrowed (click vs launch vs window):

| Id | Idea | Where it stood |
| -- | ---- | -------------- |
| A | Pick misses the icon (inset / coords) | Still possible on a live click. Search and panes were too high. |
| B | Press never becomes `vfunc_clicked` | The 20:25 retest. `clicked` notification, no vfunc. |
| C | `activate()` throws on a bad Event | Direct `AppIcon.activate()` did not throw. |
| D′ | Child opens on Weston X, not mutter | Real for a child that inherits the shell `WAYLAND_SOCKET`. Unset-socket correction landed. Do not also unset `DISPLAY` or force `GDK_BACKEND` in `AppLaunch.vala`. |
| D″ | Spawn from the shell process instead of mutter | `Helper-AppLaunch` is the compositor-side path. Do not invent `Meta.Display.launch`. |

---

## Carried — `style-changed`

Owned by [`2026-09-22-style-changed-manual-subscription.md`](2026-09-22-style-changed-manual-subscription.md). The post-mint `Clutter.Actor` block that called `ensure_signal_subscribe(..., "style-changed")` is **removed**. It existed so `BaseIcon.vfunc_style_changed` built icon textures. Subscribing from `St.Widget` construction nested an RPC while a reply was parsing. Do not put that subscribe back.

Forwarding the server signal, or firing it from a synchronous vfunc hook, enters `StWidgetClass.style_changed` while `call_poll()` is still inside GJS and crashes in libgjs.

Current startup bridge: generated `St.Widget.style` and `style_class` setters call `signal_style_changed()` only after the RPC reply returns (`local_emit_after` in `St.overrides`). That passed `buttonbox-hpadding-smoke` (`nat=12 min=6`) and reached `READY=1`. It is not the delivery path for a GJS `connect('style-changed')` on a Helper-Actor relay (that log had no `style-changed` notification). Remove the bridge when notifications can dispatch outside the active GJS→RPC frame, via the same generated class-closure as `clicked`. Do not copy the bridge onto `clicked`, `repaint`, or icon-press.

---

## Still on this screen, not the four rows

| Surface | Last score |
| ------- | ---------- |
| Clock / system menus | Open and close. Buttons inside a popdown do not. Compact Event coords were `0,0` / `222,1`, so `get_event_actor` often returned the stage. Enough to close; not enough to hit a child. |
| Quick Settings volume / preferred `-12` | Deferred. `quicksettings-layout-neg-smoke` **FAIL** `min=-12 nat=-12` on an unmapped grid. Not the live bar. |
| `messageTray` / date-menu BoxPointer | Allocation still odd (stage-wide preferred on the popover). |

Menu close gate `captured-event-smoke` was **ok**. A later freed-event bug on `captured-event` is separate: [`done/2026-09-24-captured-event-freed-pointer.md`](2026-09-24-captured-event-freed-pointer.md).

---

## Do not

- Hand-bridge `clicked` or any other `signal_prefer` name in an override.
- Another launch Helper, `unset DISPLAY`, or `GDK_BACKEND=` inside `AppLaunch.vala`.
- Idle, vendor `js/`, client `layout_changed` → `queue_relayout`, Actor allocate Hook as the layout manager, `rpc_lid` on the GJS layout manager.
- Never-shrink `actor_allocation` globally. That crashed the clock menu and was reverted.
- `Bin.register("Shell-GLSLEffect")` on mutter. Alias is `Clutter-OffscreenEffect` ([`done/2026-09-21-shell-glsleffect-bin-alias.md`](2026-09-21-shell-glsleffect-bin-alias.md)).
- Score early snaps (`startingUp=true`, empty Quick Settings). Score `delayed15s` plus this live look.
- Treat stay-up as this screen being fixed.

---

## What the screen is actually doing

Measured 2026-09-27 09:06, about 20 seconds after the overview had opened. The screen is the window picker (search, desktops, bottom bar), not the app grid. The nested screen is 800×600.

The desktop preview looks gone because the **picture inside it has no size**. The box that should show the current desktop is on screen, about 540×383, fully opaque, under the search bar. The wallpaper inside that box is **0×0**. The two containers around the wallpaper are 0×0 as well. Same for the next desktop, which sits to the right and hangs off the screen. An empty box with no picture is what “the preview disappeared” looks like.

The theme area inside the frame is 540×383, and the picture is the frame’s first child. Nothing is scaling it down to nothing. The allocation really is 0×0.

The function that is supposed to give that picture a size did not run once in a full boot. Layout did size the frame: twice to 540×383 and twice to 800×568. Each of those calls had no link to the sizing function, so the ordinary widget layout ran instead and left the picture at its default 0×0.

On 2026-09-17 that inner picture had a real size and the wallpaper showed. A direct test of the same function now also leaves the picture at 0×0. The function is in the class. The hook reads a different field and finds an ordinary widget there. How that read works, and why the field is the real library's field, is [Virtual functions](../vfuncs.md).

An earlier boot aborted when this function first ran (the connection dropped, then “not connected”). The user has since confirmed the background is on screen, so that abort is not the live bug.

| Piece | Where it is | What you would see |
| ----- | ----------- | ------------------ |
| Search | 215,32 — 370×55 | On screen, just under the top bar |
| Small desktop row | 121,94 — 558×28, 14 children | The row exists. Whether it looks like anything is still open. |
| Current desktop frame | 130,126 — 540×383 | The frame is there |
| Wallpaper inside it | 0×0 | Nothing. This is the missing preview. |
| Next desktop, to the right | 709,138 — 508×360, picture also 0×0 | Hangs off the right edge. Candidate for the stray rectangle. Not confirmed as the red dot. |
| Bottom bar | 0,520 — 800×80, fully opaque | The bar’s box is on screen. Icon contents not measured yet, so this does not clear “dash not visible”. |

There are 12 workspaces, and dynamic workspaces are off. That is a lot of desktops to lay out across one monitor.

The shell still reports that startup has not finished, 20 seconds in. The overview has nevertheless opened and the boxes above have sizes.

## How we failed to see this at first

The debug copy of the shell script was not the copy the shell ran. The stock script stayed in front of it. A one-line change in the shell client fixes that order. After that, the measurement above is from the debug script.

A snapshot taken in the first seconds of boot is useless here: nothing has been given a size yet. The date-menu part of that debug script also stalled the boot, so it now stops after recording the overview.

## Next

Click Terminal. The notification `clicked` must run `AppIcon.vfunc_clicked`, which calls `Shell.App.launch`. Direct launch already maps a window.

Why the emit misses the method, and whether pointing the signal at that method afterwards is a design fix or a workaround, is [`2026-09-27-clicked-signal-misses-vfunc.md`](2026-09-27-clicked-signal-misses-vfunc.md).
