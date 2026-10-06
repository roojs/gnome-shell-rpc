# Apport dialog on the shell and the compositor

**Status:** ✅ closed 2026-10-06. User: assume fixed.

Split from [`../2026-10-05-boot-crash-and-logout-hang.md`](../2026-10-05-boot-crash-and-logout-hang.md). The GTK dialog interrupted restart and logout. Apport 2.32 wrote `/var/crash/_usr_bin_gsr-client.1000.crash`.

## Required

- Never show the dialog for `/usr/bin/gsr-client` (session shell) or `/usr/bin/gsr-server` (compositor).
- Permanent. A rebuild must not bring the dialog back.
- These crashes are the crash screen and these notes, not an Apport report.
- A dump must still be written.
- `gsr-smoke` is a different executable. Left out.

## This machine

- `systemd-coredump` 257.4 is installed. `systemd-coredump.socket` is active.
- `core_pattern` is `|/usr/lib/systemd/systemd-coredump %P %u %g %s %t %c %h %d %F`.
- That program stores the core first (`Storage=external`, `/var/lib/systemd/coredump/`).
- On success, `apport-coredump-hook@.service` runs `apport --from-systemd-coredump`.
- That calls `process_crash()`, which hits `check_ignored()` before it writes `/var/crash/*.crash`.
- The dialog and the Ubuntu upload come from that crash file. The core is already stored.
- A listed path in `/etc/apport/report-ignore/` makes `check_ignored()` true. Exact path.
- `apport --start` would point `core_pattern` back at Apport. This package does not ship `apport.service`.

## Installed

`meson install` writes `report-ignore/gnome-shell-rpc` under `sysconfdir` (`/etc` when prefix is `/usr`). The two lines are `bindir/gsr-client` and `bindir/gsr-server`. A `/usr` install lists:

- `/usr/bin/gsr-client`
- `/usr/bin/gsr-server`

No dump program. No class on `gsr-client` or `gsr-server`. The kernel delivers the core to `systemd-coredump`.

- No dialog. The hook returns before it writes the crash file.
- No upload to errors.ubuntu.com.
- The core stays in systemd's store. `coredumpctl` reads it.
- Survives a rebuild. Match is the path, not the mtime.
- Other programs still get an Apport report.
- Exact path only. A copy outside `/usr/bin` still shows the dialog.
- The core is systemd's file, not `/var/crash/*.crash`. `apport-retrace` has no crash file.
- `coredump.conf` can still drop a core that is too large.
- If `core_pattern` is pointed back at `/usr/share/apport/apport`, the same denylist drops the core, because Apport is then the only reader.

## Crash screen

- `on_crash()` in `src/server/rpc/SpawnClient.vala` checks `/usr/lib/systemd/systemd-coredump`.
- Missing: the notice adds "systemd-coredump is not installed. Core dumps are not available."
- [`docs/build.md`](../../build.md) recommends the `systemd-coredump` package. The build succeeds without it.
