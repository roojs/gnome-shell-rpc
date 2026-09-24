# Overview picker: desktop preview gone, stray rectangle, dash missing, icon click still dead

**User goal:** nested mutter-rpc + gnome-shell-rpc stays up and the boot overview matches stock WINDOW_PICKER, and clicking an app icon launches it. From [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md).

**Status:** ⏳ open — live look, 2026-09-24. No `src/` change until a smoke names the miss. Smokes cited below are **2026-09-16 / 2026-09-22** results. Code has moved. Re-prove before treating one as current.

**Plan:** [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Supersedes (archived 2026-09-24):**

- [`done/2026-09-16-chrome-panel-menus-overlay.md`](done/2026-09-16-chrome-panel-menus-overlay.md) — panel, menus, grey overlay, WINDOW_PICKER layout
- [`done/2026-09-22-search-result-click-no-launch.md`](done/2026-09-22-search-result-click-no-launch.md) — icon click does not spawn

**Still open, not this bug:** [`2026-09-22-style-changed-manual-subscription.md`](2026-09-22-style-changed-manual-subscription.md) — `local_emit_after` setter bridge. Do not remove it from the overview ticket.

Full logs and rejected edits stay in those files. This bug is the live score.

---

## Seen (user, 2026-09-24)

Stock `user` mode lands on WINDOW_PICKER after boot: search, workspace thumbnails, current-desktop pane, dash.

| # | What | Stock piece | Seen |
| - | ---- | ----------- | ---- |
| 1 | Desktop preview | Current-desktop pane: wallpaper plus window thumbnails (`WorkspacesDisplay` / `WorkspaceBackground`) | **Gone.** Was visible 2026-09-17 ~16:37. Gross regression. |
| 2 | Icon click | App icon → `AppIcon.vfunc_clicked` → `Shell.App.launch` | **Still does not start the app.** Signal work since 2026-09-22 did not clear the user click. |
| 3 | Stray rectangle | Unknown actor | Roughly square rectangle, mostly on the **right**, on top of the preview desktops. Small **red dot** at its top-left, just **below the search bar**. Same family as the old “grey square + red dot ~2/3 along.” |
| 4 | Bottom chooser | Dash | **Not visible.** Open question: row 3 **is** that dash in the wrong place, or the dash has not appeared. |

---

## Stock layout (carried)

Not a miss that the overview is showing. Nested session is stock `user`, `hasOverview: true`. Startup eases **HIDDEN → WINDOW_PICKER** (`state=1`), `showAppsButton.checked=false`, and drops the search entry from the top. The app grid is only when `state > WINDOW_PICKER`. Search fill (icons in results) is closed: [`done/2026-09-19-overview-app-search-empty.md`](done/2026-09-19-overview-app-search-empty.md).

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

**Does not work on a real click (user 20:25, and again 2026-09-24):** press/release produced client `notification method=clicked`. `AppIcon.vfunc_clicked` did not run. No `Helper-AppLaunch` from that click.

`AppIcon` overrides `vfunc_clicked`. It does not `connect('clicked')`. There is no fallback in `appDisplay.js`.

Rejected the same day: a generic `clicked` subscribe in `Actor.override.vala`, and a hand-written `clicked_vfunc` class handler in `Button.override.vala`. The isolated smoke passed. The integrated shell crashed. Removed. Do not restore it.

`signal_prefer` is why. Vala cannot declare a signal and a method with the same name, so the generator keeps the GObject signal and renames the class-struct field to `*_vfunc`. Nothing generated makes signal emission invoke that slot. RPC re-emits `clicked`; GJS `vfunc_clicked` does not run. The same split covers `style_changed`, `long_press`, `repaint`, `popup_menu`, Entry icon-press names, and the Clutter event/gesture list. Generation has to keep, for each GIR collision:

1. the stock signal name (`connect`, RPC);
2. the stock class-struct slot (GJS `vfunc_*`);
3. the class-closure from emission to that slot.

Namespace-wide `signal_prefer=` lists are not that mechanism. Gates before a generator change: RPC `clicked` runs a GJS `vfunc_clicked`; chain-up still works; `style_changed` and one Clutter event name use the same path; `class-struct-offset-gate` stays PASS; a search click launches without crashing. Related generator note: [`2026-09-23-prefix-generated-vala-signals.md`](2026-09-23-prefix-generated-vala-signals.md).

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

Menu close gate `captured-event-smoke` was **ok**. A later freed-event bug on `captured-event` is separate: [`done/2026-09-24-captured-event-freed-pointer.md`](done/2026-09-24-captured-event-freed-pointer.md).

---

## Do not

- Hand-bridge `clicked` or any other `signal_prefer` name in an override.
- Another launch Helper, `unset DISPLAY`, or `GDK_BACKEND=` inside `AppLaunch.vala`.
- Idle, vendor `js/`, client `layout_changed` → `queue_relayout`, Actor allocate Hook as the layout manager, `rpc_lid` on the GJS layout manager.
- Never-shrink `actor_allocation` globally. That crashed the clock menu and was reverted.
- `Bin.register("Shell-GLSLEffect")` on mutter. Alias is `Clutter-OffscreenEffect` ([`done/2026-09-21-shell-glsleffect-bin-alias.md`](done/2026-09-21-shell-glsleffect-bin-alias.md)).
- Score early snaps (`startingUp=true`, empty Quick Settings). Score `delayed15s` plus this live look.
- Treat stay-up as this screen being fixed.

---

## Next

1. Name the actor for rows 3 and 4 (dash vs the red-dot rectangle) on a stay-up snap.
2. Score row 1 against the 2026-09-17 wallpaper pane (allocate smoke had `inner=800x400`; the user no longer sees that pane).
3. Row 2 stays the `clicked` → `vfunc_clicked` class closure. Re-prove before another product edit. Generator gates are listed above.
