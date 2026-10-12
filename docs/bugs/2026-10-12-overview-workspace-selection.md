# Overview workspace selection does not switch workspace

**Status:** ⏳ open, fix in tree. In the overview, one click on the workspace sitting to the right should slide that workspace into the middle and leave the overview open. The 11:50 log showed `Meta.Workspace.activate` and `active-workspace-changed`, and no `switch-workspace`, so the scroll adjustment stayed put. A second click then hid the overview onto that desktop.

The client now subscribes to `Meta.WorkspaceManager::workspace-switched` and re-emits `Shell.WM::switch-workspace`, which is what `WorkspacesDisplay` eases. `workspace-select-smoke` passed: `before=0 after=1 target=1 switch=true active=1` (`workspace-select-smoke: ok` at 12:15:14 in `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`).

The 11:50 nested log names it. `org.gnome.ShellRpc.debug.log` line `11:50:46.170496` is `Meta-Workspace.activate` after `Clutter-ClickAction.get_button` (the `Workspace` click in `workspace.js`, not the thumbnail strip). `active-workspace-changed` follows. There is no `switch-workspace` notification and no `St.Adjustment` `notify::value` until the next click at `11:50:48.443802`. That second `activate` does not emit `active-workspace-changed` (the workspace is already active). `notify::value` starts at `11:50:49.140777`, which is the overview closing.

`Gsr.Server.Plugin` does not implement `switch_workspace`. Mutter therefore finishes the switch inside `activate` and never emits `Shell.WM::switch-workspace`. `WorkspacesDisplay._activeWorkspaceChanged` is what eases the scroll adjustment, and it never runs. The first click changes the active workspace with the old one still in the middle. The second click takes the `metaWorkspace.active` path and calls `Main.overview.hide()`.

## Reproduction

Hand test, nested session, log `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` (11:50). Open Activities, click the workspace on the right once: the middle view stays. Click it again: the overview closes onto that workspace.

```bash
GSR_NESTED_TIMEOUT=70 GI_META_SMOKE=workspace-select-smoke \
  ./scripts/agent-nested-smoke-prove.sh
```

Pass line: `workspace-select-smoke: ok`. Latest prove: `nested-weston-prove: stop (smoke-ok) after 8s` at 12:17, with `before=0 after=1 target=1 switch=true active=1`.

## Debug-code cleanup ledger

- `tests/gjs-embed/workspace-select-smoke.js` — reproduction. Product change is `Shell.Global` re-emitting `switch-workspace`, and `Shell.WM.completed_switch_workspace` not forwarding to the leased plugin.

## LLM efforts

### 2026-10-12 09:39 report created

Created as a separate bug from thumbnail rendering and window dragging. No product code or reproduction code has been changed for this failure.

### 2026-10-12 09:41 installed-session logs stop before workspace activation

The server received the hand test's primary-button press and release events and the client replied to the event callbacks. Across the 09:36 test there is no `Meta.Workspace.activate` RPC. The failure is therefore before the compositor workspace switch: either the thumbnails-box click action does not emit `clicked`, or `_activateThumbnailAtPoint()` does not resolve the clicked preview.

### 2026-10-12 11:51 nested log — activate runs, the middle view does not move

Read `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` and `mutter-rpc.debug.log` from the 11:50 session (client 6.6M, mutter 6.8M).

Two `clicked` notifications call `Clutter-ClickAction.get_button` then `Meta-Workspace.activate`: `11:50:46.170496` (id 21465) and `11:50:48.447375` (id 25023). Mutter recv matches those ids. `get_button` is `workspace.js` `Workspace`, not `ThumbnailsBox` (`get_coords`).

The 11:50:46 call emits `active-workspace-changed`. No `switch-workspace` line exists anywhere in the client log. No `St.Adjustment.set_value` / `notify::value` until `11:50:49.140777`, after the second click. The second `activate` has no `active-workspace-changed`.

`src/server/Plugin.vala` implements map/minimize/destroy and completes them locally. It does not implement `switch_workspace`. `meta_plugin_manager_switch_workspace` returns false when that vfunc is unset, and `meta_compositor_switch_workspace` then calls `meta_finish_workspace_switch` immediately. `global.window_manager` is `Shell.WM` (`shell_global_get_window_manager`). `WorkspacesDisplay` eases `_scrollAdjustment` only from `switch-workspace`. That signal is never emitted, so the overview keeps the previous workspace in the middle. The second click sees `metaWorkspace.active` in `_shouldLeaveOverview` and hides the overview.

### 2026-10-12 12:08 smoke miss, then 12:15 pass

`GSR_NESTED_TIMEOUT=70 GI_META_SMOKE=workspace-select-smoke ./scripts/agent-nested-smoke-prove.sh`

Before the client change: `before=0 after=0 target=1 switch=false active=1` and `workspace-select-smoke: miss Error: miss switch-workspace (signal never emitted)`. `stop (smoke-fail) after 10s`.

`Shell.Global` now connects `workspace-switched` and calls `Shell.Signals.connect` so the peer actually delivers it, then emits `Shell.WM.switch_workspace`. `completed_switch_workspace` does not RPC the leased plugin.

After that rebuild: `before=0 after=1 target=1 switch=true active=1` and `workspace-select-smoke: ok` at 12:15:14. The prove script's ok pattern did not list this smoke, so that run waited out `stop (timeout) after 70s`. The pattern now includes `workspace-select-smoke: ok`.

### 2026-10-12 12:17 prove stops on ok

Same command with `GSR_NESTED_TIMEOUT=40`. `before=0 after=1 target=1 switch=true active=1`, `workspace-select-smoke: ok`, then `nested-weston-prove: stop (smoke-ok) after 8s`.
