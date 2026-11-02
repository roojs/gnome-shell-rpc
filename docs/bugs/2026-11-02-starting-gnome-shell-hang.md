# Starting GNOME Shell hangs on the 26.04 guest

**Status:** landed, not re-logged. 2026-11-02.

The splash in `StartupFrameLock` stays up because `Server.start` never spawns `gsr-client`. The installed session log is `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log` on `alan@192.168.122.52` (pid 28107, 15:03:33):

`Server.vala:40: uncaught error: Typelib file for namespace 'Meta', version '16' not found`

`Gi.register` throws, so the rest of `start` does not run. No `gsr-client` process. The same call for `Clutter` and `St` is hardcoded `"16"`. On that guest only version 18 loads (`GI_TYPELIB_PATH=/usr/lib/x86_64-linux-gnu/mutter-18:/usr/lib/gnome-shell`). Register those three namespaces with `MUTTER_API_VERSION` from the configure that found mutter. A 16 build still registers 16.

Weston on the 25.04 host cannot show this. That host has the 16 typelibs. The guest frame clock is inhibited, so a nested window there was not started.

## LLM efforts

- Read `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log` and `journalctl -b _PID=28107` on `alan@192.168.122.52`. Last critical line is the Meta 16 typelib miss. Process list has `gsr-server` and no `gsr-client`. Shell debug log was last written 11:00, before this login.
- `python3` `gi.require_version` for Meta, Clutter, and St: version 16 raises `Namespace … not available for version 16`; version 18 prints `ok`. Same typelib path the server prepends.
- `ninja -C build src/gsr-server` on the guest after `MUTTER_API_VERSION` was set to `18` in `build/src/Config.vala`. Linked `build/src/gsr-server`. Installed over `/usr/bin/gsr-server` (`prefix` `/usr`). The running pid 28107 is still the 15:03 binary.
