# GNOME Terminal launch is slow

**Status:** ✅ closed 2026-10-05. User: terminal launch is performing.

**Plan:** none yet. [`../../plans/done/1.2-teardown-and-restart.md`](../../plans/done/1.2-teardown-and-restart.md) is done. This is not part of it.

Separate from [`2026-09-30-rpc-call-volume.md`](2026-09-30-rpc-call-volume.md). That one counted the calls. The timings below are from it. This bug is why a Terminal click takes so long. Also separate from [`2026-10-03-frames-stop-after-shell-started.md`](2026-10-03-frames-stop-after-shell-started.md): frames stopping after boot would freeze the overview-hide animation, but that is not yet shown to be this delay.

## Launch path

Click on an app icon in `vendor/gnome-shell/js/ui/appDisplay.js` `AppIcon.activate()`:

1. `Shell.App.activate()` → `launch()` for a stopped app.
2. Sync RPC `Gsr-Mutter-AppLaunch.launch_desktop_file` (`src/client/libshell-16/App.vala`).
3. Compositor `Gsr.Server.Meta.AppLaunch.launch_desktop_file` (`src/server/libmutter-16/AppLaunch.vala`): mutter `create_launcher()`, unset `WAYLAND_SOCKET` only, `DesktopAppInfo.launch`.
4. `Main.overview.hide()`.

`/usr/share/applications/org.gnome.Terminal.desktop` is `Exec=gnome-terminal`, `StartupNotify=true`, and has no `DBusActivatable`. Gio spawns `/usr/bin/gnome-terminal`. That client asks the session bus to activate `org.gnome.Terminal`.

The nested bus is `scripts/prepare-nested-dbus.sh`, used by `scripts/nested-weston-hold.sh` and `scripts/nested-weston-prove.sh`. The distro unit is `SystemdService=gnome-terminal-server.service` (host user systemd, host display). The nested override is a direct `Exec=/usr/libexec/gnome-terminal-server` and is installed ahead of the system service dir.

After the window exists, `vendor/gnome-shell/js/ui/windowManager.js` `_mapWindow` for a normal window sets scale `0.01` / `0.05` and opacity `0`, waits for overview `hidden`, then a **150ms** ease (`SHOW_WINDOW_ANIMATION_TIME`). Overview leave is **250ms** (`Overview.ANIMATION_TIME` in `overview.js`, driven by `overviewControls.js` `animateFromOverview`). The window stays invisible until that ease runs. `completed_map` runs in `onStopped`.

`Shell.App.state` is `RUNNING` only when a window is already tracked, otherwise `STOPPED`. It never stays in `STARTING`. `WindowTracker` declares `startup_sequence_changed` and does not connect it to `Meta.StartupNotification`. A second click while the first Terminal is still coming up calls `launch()` again.

## Seen

### 2026-10-04 10:20 — the wait is 25s for `org.freedesktop.secrets`

Stay-up nest, no overview. `tests/gjs-embed/terminal-launch-timing-smoke.js` calls `Shell.App.launch` for `org.gnome.Terminal.desktop` and polls. Log: `~/.cache/gnome-shell-rpc/nested-weston-prove.tee.log`.

| Time | What |
| --- | --- |
| 10:20:03.458 | `launch begin` |
| 10:20:03.477 | `launch returned true` (**21ms**) |
| 10:20:03.637 | `gnome-terminal-server` is up (`Gtk-WARNING` theme parse) |
| 10:20:04 | portal Desktop, gnome backend, and gtk backend are activated |
| 10:20:28.926 | `name-owned ms=25468` |
| 10:20:29.159 | portal: `StartServiceByName` for `org.freedesktop.secrets` timed out |
| 10:20:33.699 | still `normal=0`. Then `client not ready after 30s, killing it` |

`Shell.App.launch` is not the wait. The Terminal server process is running about 160ms after the click. It asks for `org.freedesktop.portal.Desktop` before it owns `org.gnome.Terminal`. The portal asks for `org.freedesktop.secrets`. `gnome-keyring-daemon` prints `discover_other_daemon: 1` and `GNOME_KEYRING_CONTROL=/run/user/1000/keyring` — the host keyring — and never owns `org.freedesktop.secrets` on this private bus.

The portal’s `StartServiceByName` then sits for the GDBus default **25s** and gives up. `org.gnome.Terminal` is owned in that same second (25.5s after `launch`). The `gnome-terminal` client has already logged `Error calling StartServiceByName for org.gnome.Terminal: Timeout was reached`, so it never asks the factory for a window. No `NORMAL` window mapped in the 4.5s after the name was owned.

Not a broken host keyring. `gnome-keyring-daemon --start` is “start a daemon or initialize an already running daemon.” `/run/user/1000/keyring` is the host session’s control socket, and it is healthy. The nested activation finds it, initializes that daemon, and does not own `org.freedesktop.secrets` on the private bus. Restarting or reinstalling the host keyring does not fix this.

**Fix:** `scripts/prepare-nested-dbus.sh` now ships `org.freedesktop.secrets` as `Exec=/bin/false`, same place as the Terminal service override. Activation fails at once instead of sitting on the host socket. Each nested session rebuilds that bus config, so the next nest picks it up. Nothing to change on the host keyring.

2026-10-04 10:28, same smoke, after that override:

| Time | What |
| --- | --- |
| 10:28:39.599 | `launch returned true` (22ms) |
| 10:28:40.254 | `org.freedesktop.secrets` failed at once: process exited with status 1 |
| 10:28:40.359 | `name-owned ms=781` |
| 10:28:40.613 | `window-normal=1 ms=1032`, then `ok` |

### RPC returns in about 30ms. The server process is up immediately. The bus name is not.

`~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`, `app-search-launch-smoke`, one L1 launch:

| Time | What |
| --- | --- |
| 20:06:34.943 | `recv` `Helper-AppLaunch.launch_desktop_file` id=19185 |
| 20:06:34.973 | `replied` id=19185 |
| just after | dbus `Activating service name='org.gnome.Terminal'` requested by `/usr/bin/gnome-terminal` |
| 20:06:35.148 | `(org.gnome.Terminal): Gtk-WARNING` theme parse. The server process is running. |
| 20:06:39.034 | second `launch_desktop_file` id=20514, also replied in ~20ms |
| 20:06:49.684 | `Lost connection to Wayland compositor` / `Broken pipe` |
| ~20:07:00 | `Successfully activated service 'org.gnome.Terminal'`, same second as `org.freedesktop.portal.Desktop` and `org.freedesktop.impl.portal.desktop.gnome` |

Also in that teardown: `Error calling StartServiceByName for org.freedesktop.secrets: Timeout was reached`, and `Error constructing proxy for org.gnome.Terminal:/org/gnome/Terminal/Factory0: Error calling StartServiceByName for org.gnome.Terminal: Timeout was reached`.

This sample is a dying nest (prove kill, broken Wayland). It is not a clean “how long does a stayed-up launch take”. It does show the shape: spawn RPC is not the wait; the Terminal server is in the process list long before dbus reports the name owned; the name lands with the desktop portal.

`tests/gjs-embed/app-search-launch-smoke.js` waits `TERMINAL_ACTIVATION_WAIT_MS = 30000` after L1 before it looks for a window.

### Click to a visible window was about half a minute on 2026-09-30

[`2026-09-30-rpc-call-volume.md`](2026-09-30-rpc-call-volume.md), one `Helper-AppLaunch.launch_desktop_file`, opening a terminal:

| When | Calls | What |
| --- | ---: | --- |
| 18:49:11–18:49:13 | 61 | Click |
| 18:49:14–18:49:25 | 12,116 | Second actor tree (~11s). 350 `Helper-Actor.create` |
| 18:49:26–18:49:39 | 0 | Quiet (~14s) |
| 18:49:40–18:49:43 | 2,165 | Window animation (~4s) |

The show ease is 150ms. The log spent ~4s in that animation: per frame `St-Adjustment.get_value` / `set_value`, `St-ThemeContext.get_for_stage`, `get_scale_factor`, `layout_changed`. The 14s with no RPC is still unexplained on a stayed-up run. Candidates are in “Not measured”.

### Private-bus services that can block a new GTK process

`prepare-nested-dbus.sh` copies `/usr/share/dbus-1/session.conf`. That file sets `service_start_timeout` to **120000** ms. Only `org.gnome.Terminal` is overridden. These still have `SystemdService=` and are started through the host user systemd, which does not own the name on the private bus:

| Name | Unit |
| --- | --- |
| `org.freedesktop.portal.Desktop` | `xdg-desktop-portal.service` |
| `org.freedesktop.impl.portal.desktop.gtk` | `xdg-desktop-portal-gtk.service` |
| `org.freedesktop.impl.portal.desktop.gnome` | `xdg-desktop-portal-gnome.service` |
| `ca.desrt.dconf` | `dconf.service` (also has `Exec=/usr/libexec/dconf-service`) |

A name that never appears on the private bus sits until `service_start_timeout`. GTK init in `gnome-terminal-server` runs before the process owns `org.gnome.Terminal`. If init waits on one of these, the client’s `StartServiceByName` waits with it.

### Not a measurement

2026-10-04 09:53. Private bus, no display, `WAYLAND_DISPLAY=wayland-gsr-no-such-socket`. `/usr/bin/gnome-terminal` exited in ~18ms: `Cannot open display`. Useless for the nested timing. `gdbus introspect` on that name also triggered activation.

2026-10-04 09:30 prove (`org.gnome.ShellRpc.debug.log`) has no `launch_desktop_file`. Last launches in the prove log are the smoke runs above.

## Not measured

This run did not start `ui/init.js`, so it does not time overview hide, the 11s actor tree, or the 150ms show ease. Those are still the 2026-09-30 counts.

A second `launch` after the name is owned (the server is already up; the first client has given up) is not timed. The smoke was killed at 30s because it never marks the client ready (`Server.vala` `client not ready after 30s`).
