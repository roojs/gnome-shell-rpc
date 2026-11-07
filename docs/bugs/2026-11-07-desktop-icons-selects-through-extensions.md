# Desktop icons steals the pointer when extensions start

**Status:** Fixed on the local mutter 16 nest. The Ubuntu emulator
is still the 12:07 binaries, so that session is unchanged.

Desktop Icons only lowers its Gtk window from `Shell.WM::map`.
The server plugin showed the actor and called `map_completed`
itself, and nothing emitted that signal. The window stayed a
normal window over the session, so clicks drew a selection
rectangle and the extension manager never took the click. The
extension's 3 second timer then `force_exit`s the process and
relaunches it.

`Plugin.map` now writes `Shell-WM.map` with the window lease.
`Shell.WM` emits `map`. `owns_window` is
`Gsr-Mutter-WaylandClient.owns_window` on the mutter 16 and 18
servers, and the client overrides call that. The generated
`Meta-WaylandClient.owns_window` is denied so it does not clash.

Seen on `alan@192.168.122.115` (`ubuntu2604`), session started
12:08:02 HKT. `gsr-server` 137537, `gsr-client` 137789, binaries
12:07. `enabled-extensions` includes `ding@rastersoft.com`.
Journal is `journalctl -b` for those pids. From 12:08:14,
`Launching DING process` repeated (47 times by 12:14) with no
`Received notification for window`.

Reproduction, and the bar that passed:

```bash
GSR_NESTED_TIMEOUT=30 GI_META_SMOKE=desktop-icons-select \
  ./scripts/agent-nested-smoke-prove.sh
```

`nested-weston-prove: stop (smoke-ok) after 2s`. Client log
`desktop-icons-select: map maps=1`, `lower ok`,
`desktop-icons-select: ok`. Before the server and `Shell.WM`
edit, the same command was `stop (smoke-fail)` with
`desktop-icons-select: miss map-not-emitted` and
`windows-normal after=1 maps=0`.

## LLM efforts

- 2026-11-07 12:13 HKT. User: with desktop icons on, starting
  extensions on the Ubuntu emulator leaves only a screen
  selection. The extension manager behaves as if it is invisible.
  Guest `ubuntu2604` is up. Session 12:08, server 137537, client
  137789. `ding.js` relaunches about every 3 seconds.
  `Launching DING process` 47 times. No `Received notification
  for window` and no `owns_window` exception. DING's
  `emulateX11WindowType.js` claims the window only from
  `global.window_manager` `map`, then `set_type(DESKTOP)` and
  `lower`. The 3 second timer `force_exit`s when that claim
  never arrives. `src/server/Plugin.vala` `map` shows the actor
  and calls `map_completed`. Nothing emits `Shell.WM.map`.
  Did not edit `src/` yet.
- 2026-11-07. `GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=desktop-icons-select ./scripts/agent-nested-smoke-prove.sh`
  with `Gio.AppInfo.launch` of `gtk4-demo`. `launch returned true`,
  `windows-normal after=0 maps=0`, `miss no-window`. Gtk logged
  `Failed to open display` (inherited `DISPLAY` is Weston's
  Xwayland; mutter is `--no-x11`).
- 2026-11-07. Same command after `Shell.App.launch` of
  `org.gtk.Demo4.desktop`. `stop (smoke-fail)`.
  `windows-normal after=1 maps=0`,
  `desktop-icons-select: miss map-not-emitted`.
- 2026-11-07. `Plugin.map` writes `Shell-WM.map`. `Shell.WM`
  emits `map` and calls `get_compositor_private`. Server
  `owns_window` added on the 16 and 18 WaylandClient rows.
  Client overrides call `Gsr-Mutter-WaylandClient.owns_window`.
  Denied the generated `WaylandClient.owns_window`.
  `ninja -C build src/server/gsr-server src/gsr-smoke src/client/libmutter-rpc-16/libmutter-rpc-16.so`
  succeeded. Same prove command: `stop (smoke-ok) after 2s`,
  `map maps=1`, `Shell.WM map lid=18`, `ok`.
- 2026-11-07. Same prove, smoke also calls `window.lower()` from
  the map handler. `lower ok`, `map maps=1`, `ok`.
- 2026-11-07. `Shell.WM` map handler no longer uses a ternary or a
  separate method. `proxies.get` runs only after `has_key`. Rebuilt
  `gsr-smoke`. Same prove: `map maps=1`, `lower ok`, `ok`.
