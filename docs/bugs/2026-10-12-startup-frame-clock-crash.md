# Startup notice, then gsr-server crashes

**Status:** ⏳ open. The nested `MainContext.iteration` in `begin` was the crash. The 14:12 guest build then hung on the notice: inhibit ran inside `after-update`, still in frame dispatch, so the clock never presented another frame after `startup notice removed`. Clocks are now inhibited from `ClutterStage::presented`, and `release` calls `schedule_update`. Not on the guest yet. Weston 14:40:26 `startup notice painted`, same millisecond `startup clocks inhibited`, 14:40:29 `startup notice removed`, alive until the timeout (`EXIT:124`), no new core.

```bash
GSR_WESTON_PIXMAN=1 timeout --foreground -k 5 30 ./scripts/weston-gsr-session.sh --debug
```

The crash is in our process. QEMU's missing 3D still drew the notice (`startup notice painted`), and `Clutter-Stage.schedule_update` completed twice before the death.

Guest `alan@192.168.122.52`, hostname `alan-VirtualBox`, boot 13:45. Installed `/usr/bin/gsr-server` and `/usr/bin/gsr-client` timestamped 13:44. Core: `/var/lib/systemd/coredump/core.gsr-server.1000.d4182d8538cb4d5c8a49e802f72d3163.4736.1791783929000000.zst` (pid 4736). Same fault on the 11:56 core (pid 2485) and the 12:49 core (pid 2481): `segfault at b00000023` in `g_source_set_ready_time` (`libglib-2.0.so.0` offset `0x59fbd`).

13:45:24 `startup notice painted`. 13:45:27 `startup notice removed`. 13:45:29, during client `Clutter-Actor.add_child`, `clutter_frame_clock_schedule_update` warns `next_update_time_us != -1` (`clutter-frame-clock.c:1239`) and calls `g_source_set_ready_time` with source `0xb0000000b` and ready time `-1`. The stage view's frame-clock pointer does not point at a `ClutterFrameClock` (first word is `0x40`).

## Reproduction

```bash
GSR_WESTON_PIXMAN=1 timeout --foreground -k 5 70 ./scripts/weston-gsr-session.sh --debug
```

Failure line: `gsr-server: segfault` about one second after `startup notice removed`.

## LLM efforts

### 2026-10-12 guest logs

`journalctl -b` on `alan@192.168.122.52` and `coredumpctl debug 4736`. Kernel: `[drm] features: -virgl +edid`. Mutter: `falling back to kms_swrast`, `Created gbm renderer`. Notice painted and was removed. Crash stack: `clutter_actor_add_child` → `clutter_stage_schedule_update` → `clutter_frame_clock_schedule_update` → `g_source_set_ready_time`. `rdi` = `0xb0000000b`, `rsi` = `-1`.

### 2026-10-12 Weston

`GSR_WESTON_PIXMAN=1 timeout --foreground -k 5 70 ./scripts/weston-gsr-session.sh --debug` on this host. Pixman Weston, nested `build/src/gsr-server`. Notice painted, then removed, then pid 1072397 segfaulted in `clutter_frame_clock_schedule_update` while computing the next update time (`prev_dispatch` is `0x38d`). Stack is an input event, not `add_child`. Same moment as the guest (just after the notice comes down), different field of the bad clock. Timeout then stopped Weston (`EXIT:124`).

### 2026-10-12 drop the nested iteration

`begin` was pumping `MainContext.iteration` while still inside the startup RPC. Removed that wait. First rebuild (inhibit immediately): notice removed at 14:09:09, no core, alive until the 30s timeout. Second rebuild (inhibit from `after_update`, so the notice still paints): painted 14:10:51, removed 14:10:54, no core, alive until 14:11:19.

### 2026-10-12 guest hang, then presented

The 14:12 guest binaries are that second rebuild. Log: 14:12:56 `startup notice painted`, 14:13:00 `READY=1` and `startup notice removed`, client still handling RPC at 14:14. The scanout stayed on the title. `clutter_frame_clock_inhibit` during `DISPATCHED_ONE` does not set `pending_reschedule`, and it sets the source ready time to `-1`. `after-update` is inside that dispatch. An idle was the wrong place to move the inhibit. `presented` runs from the frame callback before `clutter_frame_clock_notify_presented` returns the clock to idle. `release` schedules an update after uninhibit.

`GSR_WESTON_PIXMAN=1 timeout --foreground -k 5 15 ./scripts/weston-gsr-session.sh --debug`. Painted 14:40:26.306, `startup clocks inhibited` 14:40:26.307, removed 14:40:29.195. RPC still running at 14:40:40 when the timeout stopped Weston (`EXIT:124`). Newest `gsr-server` core is still the 14:00:59 segfault from the nested-iteration build.
