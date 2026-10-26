# App grid pages do not change

**Status:** ⏳ open. Show Applications opens and the icons are visible. Changing page does not.

**Next:** The page controls are the stock ones: the page dots and the scroll. The pass is a second page of icons after that control. This bug is not the wait, and it is not the construct switch.

Split from [`done/2026-10-12-applications-picker-not-working.md`](done/2026-10-12-applications-picker-not-working.md).

- Performance: [`2026-10-22-app-grid-performance.md`](2026-10-22-app-grid-performance.md)
- Construct switch: [`done/2026-10-22-actor-construct-lease-switch.md`](done/2026-10-22-actor-construct-lease-switch.md)

```bash
GSR_WESTON_SOCKET=wayland-gsr-apppick \
GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-apppick \
GI_META_SMOKE=shell-boot/ui/init GSR_WESTON_PIXMAN=1 \
GSR_NESTED_TIMEOUT=90 ./scripts/agent-nested-smoke-prove.sh
```

Read `nested-weston-prove.tee.log`. The autolaunch log is about 5GB.

**Where it stands:** The grid is on screen after the click. The page size has been `800x299` with 147 items. Paging that grid is the failure. Nothing in the smoke changes page.

## LLM efforts

### 2026-10-22 10:15 split from the picker bug

The picker archive is the record of the grid becoming visible. Pagination was not a pass there.
