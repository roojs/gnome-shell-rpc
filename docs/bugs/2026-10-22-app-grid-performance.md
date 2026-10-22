# Show Applications blocks the next click

**Status:** ⏳ open. The icons do appear. The shell does not take another click until that load finishes.

**Next:** The main thread is inside synchronous RPC for the whole build and the layout that follows. The pass is a click that lands while the grid is still filling. This bug is not pagination, and it is not the construct switch.

Split from [`done/2026-10-12-applications-picker-not-working.md`](done/2026-10-12-applications-picker-not-working.md).

- Pagination: [`2026-10-22-app-grid-pagination.md`](2026-10-22-app-grid-pagination.md)
- Construct switch: [`2026-10-22-actor-construct-lease-switch.md`](2026-10-22-actor-construct-lease-switch.md)

```bash
GSR_WESTON_SOCKET=wayland-gsr-apppick \
GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-apppick \
GI_META_SMOKE=shell-boot/ui/init GSR_WESTON_PIXMAN=1 \
GSR_NESTED_TIMEOUT=90 ./scripts/agent-nested-smoke-prove.sh
```

Log: `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log`. Read `nested-weston-prove.tee.log` for the smoke. The autolaunch log is about 5GB.

**Where it stands:** Session `10:01:21`–`10:02:45` in that client log. `clicked` at `10:01:41`. Square-bin leases run through `10:01:49`, about 25 a second, about 49 calls each (`Gsr-St-SquareBin.new`, then box, label, signals, button, properties). Preferred size and allocate then run from `10:01:51` to `10:02:12`, about 700–1000 preferred-size calls a second. The next `clicked` is `10:02:15`. The whole log is about 40k `method=` lines, mostly `get_preferred_width`, `get_preferred_height`, `get_preferred_size`, and `allocate`.

## LLM efforts

### 2026-10-22 10:15 split from the picker bug

Counted from the `10:01` client log above. No new run.
