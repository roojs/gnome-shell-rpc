# Drawing-area repaint reenters and kills mutter-rpc

**Status:** Fixed in `src/`. `Gsr-St-DrawingArea.queue_repaint` that arrives while a repaint emission is still on the stack is ignored. The draw already running reads the current value. Stock `st_drawing_area_queue_repaint` emits `repaint` before it returns and drops the mapped cairo buffer first, so a nested call cleared `in_repaint` under the outer hook and `DrawingArea.paint` dereferenced the NULL from `get_context` (SIGSEGV, exit 139).

Reproduction:

```bash
GI_META_SMOKE=drawing-area-reenter-smoke ./scripts/weston-gsr-prove.sh
```

2026-10-09 15:22: `drawing-area-reenter-smoke: ok depth=1 entered=3 surface=480x64`, `quit (ok)`. The nested `queue_repaint` logged `repaint already running, skipped`. No `in_repaint` assertion and no `cogl_buffer_dispose` mapped assertion. Wrapper exit 137 is `stop_tree` after smoke-ok.

The 14:30 hold is the same failure on a volume-slider button release. Restart the nested session onto this `gsr-server` to pick it up.

Logs: `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log` and `org.gnome.ShellRpc.debug.log`, session started 14:30 by `./scripts/weston-gsr-session.sh --debug` (hold, not prove). Last server line:

```text
14:30:54.021271: G_LOG_LEVEL_CRITICAL : st_drawing_area_get_context: assertion 'priv->in_repaint' failed
```

That line is inside `Gsr-St-DrawingArea.paint` id=18909. The client records the socket close on that call at 14:30:54.763 (`Client.vala:1109: socket closed`). `nested-weston-hold` is a hold, so this is not a prove `stop (…)` SIGKILL. `coredumpctl` has no dump. `journalctl -k` for that minute is empty.

The `JS ERROR: TypeError: this.label.clutter_text is null` in `iconGrid.js` is after the socket was already dead.

## What the log shows

Button release at 14:30:53.984, then `St-DrawingArea.queue_repaint` id=18857, which has no reply before the socket closes. The sync hook `id=1564` enters as reply 3397 and does not reply until the client is already disconnected.

While 3397 is open the client delivers the button release (`captured-event`, hook 832, `Gsr-Clutter-Actor.deliver_event` id=18864). The server logs `cogl_buffer_dispose: assertion '!(buffer->flags & COGL_BUFFER_FLAG_MAPPED)' failed` on that delivery. Then the same hook enters again as reply 3399, paints (`Gsr-St-DrawingArea.paint` id=18876, no assertion), and replies at 14:30:54.002. After that reply, `in_repaint` is clear. The outer hook continues: `get_surface_size` id=18900, 18904, and 18906 each log `st_drawing_area_get_surface_size: assertion 'priv->in_repaint' failed`, then paint id=18909 hits `get_context` and the process is gone.

`DrawingArea.paint` (`src/server/libst-16/DrawingArea.vala`) does `area.get_context()` and calls `cr.set_source_surface` on the result. The stock check returns NULL when `in_repaint` is false.

Same `get_surface_size` assertion earlier in this hold (14:30:39, :47, :48, :51, :52) did not kill the process. Those calls never reached `get_context`.

## LLM efforts

2026-10-09 14:31. Read the hold that the user had just run. Processes: Weston pid 33730 and `weston-gsr-log-term.sh` still up; no `gsr-server` / `gnome-shell-rpc`. Logs all mtime 14:30.

Server criticals at the end of `mutter-rpc.debug.log`: `cogl_buffer_dispose` mapped, three `get_surface_size` `in_repaint` failures, then `get_context` `in_repaint` on paint 18909. File ends there (line 55250).

Client: `socket closed` at 14:30:54.763 with paint 18909 and `queue_repaint` 18857 still pending. Outer hook reply 3397 then errors `not connected`. The `clutter_text is null` JS error follows that. `journalctl -k` and `journalctl --user` for 14:30:40–14:31:10 have no entries. `coredumpctl list` empty. `/var/crash` has nothing from 14:30. `src/` not changed.

2026-10-09 14:44. Stage 3. `GI_META_SMOKE=drawing-area-reenter-smoke ./scripts/weston-gsr-prove.sh`. Same failure. Client `enter depth=1`, then `queue_repaint`, server `cogl_buffer_dispose` mapped, `enter depth=2`, inner paint `480x64`, `queue_repaint returned depth=1`, outer `get_surface_size` `in_repaint` twice, `drew depth=1 surface=0x0`, `get_context` `in_repaint`, socket closed. `nested-weston-prove: mutter exited ec=139 after 2s`. `src/` still unchanged.

2026-10-09 15:01. Landed a deferral that used `GLib.Idle.add` after the hook returned. Same command: `repaint already running, deferred`, `running deferred repaint`, `drawing-area-reenter-smoke: ok depth=1 entered=3 surface=480x64`. That idle is banned (`docs/bugs/done/2026-09-16-allocate-follow-reference.md`, `docs/bugs/done/2026-09-23-prefix-generated-vala-signals.md`).

2026-10-09 15:22. Removed the idle and the again-flag. `queue_repaint` during the emission replies and returns. The draw already on the stack continues. Same command: `repaint already running, skipped`, `drew depth=1 surface=480x64`, `drawing-area-reenter-smoke: ok depth=1 entered=3 surface=480x64`, `quit (ok)`. No `in_repaint` assertion, no `cogl_buffer_dispose` mapped assertion. Wrapper exit 137 is `stop_tree` after smoke-ok.
