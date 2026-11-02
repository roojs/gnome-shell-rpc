# Starting GNOME Shell hangs on the 26.04 guest

**Status:** client require fixed locally. Not installed on the guest. 2026-11-02.

The splash stays up for 30 seconds after the client has already died. Do not wait it out. Read `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` on `alan@192.168.122.52`. The 15:27 login says:

`Application.vala:99: uncaught error: Typelib file for namespace 'Clutter', version '16' not found`

`gsr-client` requires `Clutter` and `Shell` at `"16"` before any JavaScript. The installed typelibs are version 18. The server side of the same miss was fixed earlier (`Server.vala` now registers `MUTTER_API_VERSION`). The 15:27 server log gets as far as `listening` and `spawned`, then `client not ready after 30s`.

Before the next login, on that machine after install:

```
GI_TYPELIB_PATH=/usr/lib/x86_64-linux-gnu/mutter-rpc-18:/usr/lib/x86_64-linux-gnu/mutter-18:/usr/lib/gnome-shell \
  ./scripts/check-startup-typelibs.sh 18
```

`typelibs 18 ok` means this class of hang is gone. A `typelib not found` line is the splash, without logging in. Shell JavaScript then uses `Config.LIBMUTTER_API_VERSION`, which the gresource already sets from the same configure value.

## LLM efforts

- Read `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log` and `journalctl -b _PID=28107` on `alan@192.168.122.52`. Last critical line is the Meta 16 typelib miss. Process list has `gsr-server` and no `gsr-client`. Shell debug log was last written 11:00, before this login.
- `python3` `gi.require_version` for Meta, Clutter, and St: version 16 raises `Namespace … not available for version 16`; version 18 prints `ok`. Same typelib path the server prepends.
- `ninja -C build src/gsr-server` on the guest after `MUTTER_API_VERSION` was set to `18` in `build/src/Config.vala`. Linked `build/src/gsr-server`. Installed over `/usr/bin/gsr-server` (`prefix` `/usr`). The running pid 28107 is still the 15:03 binary.
- 15:27 login, new server. `mutter-rpc.debug.log` reaches `listening` and `spawned /usr/bin/gsr-client`. `org.gnome.ShellRpc.debug.log` is 788 bytes: `Application.vala:99` Clutter version 16 not found, then the server's 30s `client not ready` kill. `gi.require_version` against `mutter-rpc-18:mutter-18:gnome-shell` fails for Meta, Clutter, St, Shell, and Cogl at 16 and succeeds at 18. Client requires in `Application.vala` now use `MUTTER_API_VERSION`. Not copied or installed onto the guest.
