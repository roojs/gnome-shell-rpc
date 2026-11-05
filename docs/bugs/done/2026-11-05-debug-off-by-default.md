# Debug logging is enabled in every installed session

**Status:** ✔️ archived 2026-11-05. User asked to archive it. Landed. The binaries already default `--debug` off and expose an explicit `--debug` flag. The installed systemd unit and legacy application descriptor used to defeat that default by always starting `gsr-server --debug`; the server then starts `gsr-client --debug`. The normal GDM entry is quiet, GDM also registers `GNOME Shell RPC (Debug)`, and the quiet logger returns before timestamp formatting. The new session files are in the Meson install, the RPM `%files` list, and the Debian and RPM package-content checks.

## Current behaviour

`src/server/Main.vala` and `src/client/Application.vala` both initialize `opt_debug` to `false` and only set `Gsr.debug_on` from `--debug`.

The installed session is not quiet:

1. `data/systemd/org.gnome.ShellRpc@.service` and `data/applications/org.gnome.ShellRpc.desktop` unconditionally pass `--debug` to `gsr-server`.
2. `src/server/libmutter-18/SpawnClient.vala` and `src/server/rpc/SpawnClient.vala` pass `--debug` to the child whenever `Gsr.debug_on` is true.
3. `ApplicationInterface.debug_log()` writes and flushes every debug line to both stderr and a cache file. Even with debug off, it formats a timestamp before deciding to discard an ordinary debug message.
4. GDM registers only `GNOME Shell RPC`; there is no explicit debug session choice.

The latest local cache files are 1,200,263 bytes for the server and 882,325 bytes for the client. Their size alone is not a performance measurement, but the per-line file flush in the hot RPC path is avoidable installed-session I/O.

The crash screen already supports the required client-only override: `Restart with debug` calls `spawn_client(false, true)`. With a quiet server, that choice starts only the replacement client with `--debug`. An explicitly debugged server continues to propagate `--debug` to its client.

## Proposed result

- Normal installed sessions start both processes with debug off.
- GDM offers a separate `GNOME Shell RPC (Debug)` session that starts both processes with debug on.
- `gsr-server --debug` remains the explicit server flag and also enables its child client's debug log.
- `Restart with debug` enables debug only for the replacement client when the server was started quietly.
- Critical warnings remain visible when debug is off.
- Quiet processes do no timestamp or file work for ordinary debug messages.
- Weston and smoke scripts that explicitly request `--debug` are unchanged.

## Proposal

### 1. `data/systemd/org.gnome.ShellRpc@.service` — `ExecStart`: use the binary defaults

**Why:** The installed unit currently turns server debug on for every session; the server then turns client debug on as well.

**Where:** `[Service]`, the `ExecStart` line.

**Depends on:** none.

#### Remove
```systemd
ExecStart=/usr/bin/gsr-server --debug --wayland
```

#### Replace with
```systemd
ExecStart=/usr/bin/gsr-server --wayland
```

### 2. `data/applications/org.gnome.ShellRpc.desktop` — `Exec`: keep the legacy launch path quiet

**Why:** `X-GNOME-HiddenUnderSystemd=true` makes this a fallback on current GNOME, but it must have the same quiet default as the systemd unit.

**Where:** `[Desktop Entry]`, the `Exec` line.

**Depends on:** none.

#### Remove
```desktop
Exec=gsr-server --debug --wayland
```

#### Replace with
```desktop
Exec=gsr-server --wayland
```

### 3. `src/ApplicationInterface.vala` — `debug_log()`: discard quiet debug messages before formatting

**Why:** Removing `--debug` stops file output, but the shared handler still allocates and formats a timestamp for every discarded debug call. The early return makes debug-off cheap while preserving the existing critical-warning path.

**Where:** At the start of `debug_log()`, immediately after the recursion guard, replacing the timestamp and `should_output` setup.

**Depends on:** none.

#### Remove
```vala
			// Generate timestamp for logging
			var timestamp = (new GLib.DateTime.now_local()).format("%H:%M:%S.%f");

			// Only output if debug is enabled, or if it's a critical warning
			bool should_output = debug_on
				|| (level & GLib.LogLevelFlags.LEVEL_CRITICAL) != 0;
```

#### Replace with
```vala
			var is_critical = (level & GLib.LogLevelFlags.LEVEL_CRITICAL) != 0;
			if (!debug_on && !is_critical) {
				return;
			}

			// Generate timestamp only for messages that will be logged.
			var timestamp = (new GLib.DateTime.now_local()).format("%H:%M:%S.%f");
			bool should_output = debug_on || is_critical;
```

In the same function, reuse that classification at the `debug_critical_enabled` check below stderr output.

#### Remove
```vala
			if ((level & GLib.LogLevelFlags.LEVEL_CRITICAL) != 0
				&& debug_critical_enabled) {
```

#### Replace with
```vala
			if (is_critical && debug_critical_enabled) {
```

### 4. `data/gsr-debug-session` — new GDM session launcher

**Why:** The debug GDM entry needs a distinct GNOME session name; direct invocations also need an explicit debug launcher.

**Where:** Add the executable file.

**Depends on:** proposals 6 and 11.

#### Add
```sh
#!/bin/sh
# --wayland below is Mutter's flag, not a gsr-server option. Nested
# tests add --nested.
if [ -n "$GDMSESSION" ]; then
	exec gnome-session --session=gsr-debug
fi
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
	exec dbus-run-session -- gsr-server --debug --wayland
fi
exec gsr-server --debug --wayland
```

### 5. `data/wayland-sessions/gsr-debug.desktop` — register the debug choice with GDM

**Why:** Users need an explicit debug session at login instead of debug being forced on in the normal session.

**Where:** Add the desktop entry.

**Depends on:** proposal 4.

#### Add
```desktop
[Desktop Entry]
Name=GNOME Shell RPC (Debug)
Comment=GNOME Shell RPC with debug logging
Exec=gsr-debug-session
TryExec=gsr-server
Type=Application
DesktopNames=GNOME
X-GDM-SessionRegisters=true
```

### 6. `data/gnome-session/sessions/gsr-debug.session` — define the debug GNOME session

**Why:** `gnome-session --session=gsr-debug` needs a registered session definition with a distinct shell component.

**Where:** Add the session file.

**Depends on:** proposal 7.

#### Add
```ini
[GNOME Session]
Name=GNOME Shell RPC (Debug)
RequiredComponents=org.gnome.ShellRpcDebug;org.gnome.SettingsDaemon.A11ySettings;org.gnome.SettingsDaemon.Color;org.gnome.SettingsDaemon.Datetime;org.gnome.SettingsDaemon.Housekeeping;org.gnome.SettingsDaemon.Keyboard;org.gnome.SettingsDaemon.MediaKeys;org.gnome.SettingsDaemon.Power;org.gnome.SettingsDaemon.PrintNotifications;org.gnome.SettingsDaemon.Rfkill;org.gnome.SettingsDaemon.ScreensaverProxy;org.gnome.SettingsDaemon.Sharing;org.gnome.SettingsDaemon.Smartcard;org.gnome.SettingsDaemon.Sound;org.gnome.SettingsDaemon.UsbProtection;org.gnome.SettingsDaemon.Wacom;org.gnome.SettingsDaemon.XSettings;
```

### 7. `data/applications/org.gnome.ShellRpcDebug.desktop` — define the debug shell component

**Why:** The debug GNOME session needs a separate required component for both systemd and legacy gnome-session startup.

**Where:** Add the desktop entry.

**Depends on:** proposal 8.

#### Add
```desktop
[Desktop Entry]
Type=Application
Name=GNOME Shell RPC (Debug)
# --wayland is Mutter's flag, passed through to Meta.Context. Not a
# gsr-server option. It selects the Wayland compositor. Nested tests
# add --nested.
Exec=gsr-server --debug --wayland
OnlyShowIn=GNOME;
NoDisplay=true
X-GNOME-Autostart-Phase=DisplayServer
X-GNOME-Provides=panel;windowmanager;
X-GNOME-Autostart-Notify=true
X-GNOME-AutoRestart=false
X-GNOME-HiddenUnderSystemd=true
```

### 8. `data/systemd/org.gnome.ShellRpcDebug.service` — start the debug server

**Why:** Current GNOME sessions use the systemd user manager, so the debug session needs an explicit service whose command line contains `--debug`.

**Where:** Add the user service.

**Depends on:** none.

#### Add
```systemd
[Unit]
Description=GNOME Shell RPC with debug logging on Wayland
After=gnome-session-manager.target
Requisite=gnome-session-initialized.target
PartOf=gnome-session-initialized.target
Before=gnome-session-initialized.target
ConditionEnvironment=XDG_SESSION_TYPE=wayland

[Service]
Slice=session.slice
Type=simple
# --wayland is Mutter's flag, passed through to Meta.Context.
ExecStart=/usr/bin/gsr-server --debug --wayland
Restart=no
TimeoutStopSec=5
```

### 9. `data/systemd/org.gnome.ShellRpcDebug.target` — group the debug shell service

**Why:** The debug GNOME session target needs a shell target parallel to `org.gnome.ShellRpc.target`.

**Where:** Add the user target.

**Depends on:** proposal 8.

#### Add
```systemd
[Unit]
Description=GNOME Shell RPC with debug logging
DefaultDependencies=no
Requisite=gnome-session-initialized.target
PartOf=gnome-session-initialized.target
Before=gnome-session-initialized.target
Wants=org.gnome.ShellRpcDebug.service
```

### 10. `data/systemd/gnome-session@gsr-debug.target.d/gsr.session.conf` — attach services to the debug session

**Why:** Selecting `gsr-debug` must start the normal GNOME settings services and the debug shell target, without starting the quiet shell target.

**Where:** Add the target drop-in.

**Depends on:** proposal 9.

#### Add
```systemd
[Unit]
Wants=org.gnome.SettingsDaemon.A11ySettings.target
Wants=org.gnome.SettingsDaemon.Color.target
Wants=org.gnome.SettingsDaemon.Datetime.target
Wants=org.gnome.SettingsDaemon.Housekeeping.target
Wants=org.gnome.SettingsDaemon.Keyboard.target
Wants=org.gnome.SettingsDaemon.MediaKeys.target
Wants=org.gnome.SettingsDaemon.Power.target
Wants=org.gnome.SettingsDaemon.PrintNotifications.target
Wants=org.gnome.SettingsDaemon.Rfkill.target
Wants=org.gnome.SettingsDaemon.ScreensaverProxy.target
Wants=org.gnome.SettingsDaemon.Sharing.target
Wants=org.gnome.SettingsDaemon.Smartcard.target
Wants=org.gnome.SettingsDaemon.Sound.target
Wants=org.gnome.SettingsDaemon.UsbProtection.target
Wants=org.gnome.SettingsDaemon.Wacom.target
Wants=org.gnome.SettingsDaemon.XSettings.target
Requires=org.gnome.ShellRpcDebug.target
```

### 11. `src/meson.build` — session-data installation: install both GDM variants

**Why:** Every new launcher, session descriptor, desktop entry, and user unit must be present in the installed session.

**Where:** The `session_data` installation block near the end of the file.

**Depends on:** proposals 4–10.

#### Remove
```meson
install_data(
  session_data / 'gsr-session',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)
```

#### Replace with
```meson
install_data(
  session_data / 'gsr-session',
  session_data / 'gsr-debug-session',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)
```

#### Remove
```meson
install_data(
  session_data / 'wayland-sessions' / 'gsr.desktop',
  install_dir: get_option('datadir') / 'wayland-sessions',
)
install_data(
  session_data / 'gnome-session' / 'sessions' / 'gsr.session',
  install_dir: get_option('datadir') / 'gnome-session' / 'sessions',
)
install_data(
  session_data / 'applications' / 'org.gnome.ShellRpc.desktop',
  install_dir: get_option('datadir') / 'applications',
)
```

#### Replace with
```meson
install_data(
  session_data / 'wayland-sessions' / 'gsr.desktop',
  session_data / 'wayland-sessions' / 'gsr-debug.desktop',
  install_dir: get_option('datadir') / 'wayland-sessions',
)
install_data(
  session_data / 'gnome-session' / 'sessions' / 'gsr.session',
  session_data / 'gnome-session' / 'sessions' / 'gsr-debug.session',
  install_dir: get_option('datadir') / 'gnome-session' / 'sessions',
)
install_data(
  session_data / 'applications' / 'org.gnome.ShellRpc.desktop',
  session_data / 'applications' / 'org.gnome.ShellRpcDebug.desktop',
  install_dir: get_option('datadir') / 'applications',
)
```

#### Remove
```meson
install_data(
  session_data / 'systemd' / 'org.gnome.ShellRpc.target',
  session_data / 'systemd' / 'org.gnome.ShellRpc@.service',
  install_dir: systemduserunitdir,
)
```

#### Replace with
```meson
install_data(
  session_data / 'systemd' / 'org.gnome.ShellRpc.target',
  session_data / 'systemd' / 'org.gnome.ShellRpc@.service',
  session_data / 'systemd' / 'org.gnome.ShellRpcDebug.target',
  session_data / 'systemd' / 'org.gnome.ShellRpcDebug.service',
  install_dir: systemduserunitdir,
)
```

After the existing `gnome-session@gsr.target.d` installation, add:

#### Add
```meson
install_data(
  session_data / 'systemd' / 'gnome-session@gsr-debug.target.d' / 'gsr.session.conf',
  install_dir: systemduserunitdir / 'gnome-session@gsr-debug.target.d',
)
```

## Verification

1. Install the session data and confirm GDM lists both `GNOME Shell RPC` and `GNOME Shell RPC (Debug)`.
2. Log into `GNOME Shell RPC`. Confirm the server command line is `gsr-server --wayland`, the client command line has no `--debug`, and the two existing cache-log mtimes do not advance.
3. Log into `GNOME Shell RPC (Debug)`. Confirm the server and client command lines contain `--debug` and both cache logs advance.
4. Start the server without debug, trigger the crash screen, and choose `Restart with debug`. Confirm the server remains quiet and only the new client log advances.
5. Emit a critical warning with debug off and confirm it still reaches stderr.

## LLM efforts

- 2026-11-05. Read both process option parsers, the shared log handler, both client spawn implementations, the installed systemd unit, and the nested scripts. Confirmed the binaries already default debug off; the installed unit is the default-on source. Confirmed server debug is deliberately inherited by the child and the crash screen already has a client-only `force_debug` path. No product code changed.
- 2026-11-05. User requested a distinct debug choice at GDM login. Extended the proposal with parallel GDM, gnome-session, application-component, and systemd registrations so the normal entry is quiet and `GNOME Shell RPC (Debug)` explicitly starts both processes with debug enabled.
- 2026-11-05. Landed the session files, the quiet `ExecStart`/`Exec`, the early return in `debug_log()`, and the Meson install. The same paths are listed in `packaging/rpm/gnome-shell-rpc.spec` and in the Debian and RPM package-content checks. Debian has no separate file list; `debian/rules` installs the Meson destroot.
- 2026-11-05. User asked to archive. Confirmed the quiet `ExecStart`/`Exec`, the `debug_log()` early return, the debug session files, the Meson install, and the RPM `%files` list are in the tree. Moved to `docs/bugs/done/`.
