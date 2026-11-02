# Mutter 18 deploy testing — shell does not stay up

**Status:** blocked on `cannot register existing type 'GIRepository'`. 2026-11-02. Product code in this tree still uses libgirepository-1.0. A 2.0-only client was installed on the guest and reverted here after it coredumped.

This is the handoff for the Ubuntu 26.04 / Mutter 18 / Shell 50 deploy. Phase 1 of [`docs/plans/0.9-multi-shell-series.md`](../plans/0.9-multi-shell-series.md). The GitHub 26.04 package job has not been started. `debian/control` and the RPM spec still depend on mutter 16 / gnome-shell 48.

## Guest

`alan@192.168.122.52`, hostname `alan-VirtualBox`, Ubuntu 26.04.1, GNOME Shell 50.1, mutter 50.1 (`libmutter-18`). Tree `/home/alan/gitlive/gnome-shell-rpc`. Vendor checkout on that machine is gnome-shell 50.0. This host is Ubuntu 25.04 / mutter 16. A host `ninja` or a host Weston run is not the 18 proof.

Do not rsync this tree onto the guest. It dirties `git pull` there. A few files were copied onto that checkout on this date (see the last effort). Those copies can disagree with this tree.

Logs, both accounts:

- `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` (client)
- `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log` (server)

The splash stays up for 30 seconds after the client has already died (`SpawnClient.vala`: `client not ready after 30s, killing it`). Do not wait it out. `scripts/check-startup-typelibs.sh` only checks that the typelib files exist. It does not catch this crash.

## What already ran

Guest `ninja -C build` completed after the Shell 50 keymap, idle-watch, and drag-gesture work. `/usr/bin/gsr-server` was installed at 15:07 from that API-18 build (`prefix` `/usr`). On a later start it logs mutter 50.1, takes `/dev/dri/card1` (virtio_gpu), listens on `/run/user/1000/mutter-rpc.sock`, and spawns `/usr/bin/gsr-client`.

The 15:27 login died in `Application.vala` because the client required Clutter and Shell at version 16. This tree now requires `MUTTER_API_VERSION`. Logins after that get past it. The 15:27 line is not the current failure.

## How to start it without a greeter login

The greeter path is `gdm-wayland-session gsr-session` → `gnome-session@gsr` → `org.gnome.ShellRpc@wayland.service` (`/usr/bin/gsr-server --debug --wayland`).

From SSH, a free VT works if getty is not allowed to take it:

```
sudo systemctl mask --runtime getty@tty2.service
sudo systemctl stop getty@tty2.service
sudo chvt 2
sudo systemd-run --collect --unit=gsr-cli-prove --uid=alan --gid=alan \
  -p PAMName=login -p TTYPath=/dev/tty2 \
  -p StandardInput=tty -p StandardOutput=journal -p StandardError=journal \
  -p WorkingDirectory=/home/alan \
  /usr/bin/dbus-run-session -- /usr/bin/gsr-server --debug --wayland
```

Without the mask, `getty@tty2` starts on the switch and the unit exits at once. An SSH shell with no VT cannot take the DRM device. Unmask getty when finished: `sudo systemctl unmask --runtime getty@tty2.service`.

If a gsr login is already up, the user unit is the restart:

```
sudo chvt 5
sudo -u alan XDG_RUNTIME_DIR=/run/user/1000 \
  systemctl --user restart org.gnome.ShellRpc@wayland.service
```

VT 5 was that login on this boot. Read `loginctl` before assuming the number.

Weston (`./scripts/weston-gsr-prove.sh`) is the nested prove on a machine that already has an X display and is the build under test. It is not a substitute for this guest, and this host's Weston only runs the mutter 16 build.

## Current failure

15:41 (text VT) and 16:00 (greeter login) match. The client connects, finishes RPC ids 1–16 (stage and theme), logs `Application.vala:179: gnome-shell-rpc: disable-user-extensions`, then:

`cannot register existing type 'GIRepository'`

followed by `g_once_init_leave` / `g_object_new_with_properties`. The server has `wayland-0` by then. The client never reaches `GNOME Shell started at`.

`gsr-client` links both `libgirepository-1.0.so.1` and, through `libgjs.so.0`, `libgirepository-2.0.so.0`. Both register a GType named `GIRepository`. `prepare_host` calls `GI.Repository` (the 1.0 library, `g_irepository_*`) before `Gjs.Context` is created. GJS then registers the 2.0 type and that critical fires.

`libocrpc` is the other 1.0 caller. `OLLMrpc.Gi.vfunc_offset` (`OLLMchat/libocrpc/Gi.vala`) calls `GI.Repository.get_default().find_by_name`. `Shell.Global.bind_display` calls it for `Clutter.Actor.event`.

Switching only the client require to `gi_repository_*` (2.0) was tried and installed as `/usr/bin/gsr-client` at 16:08. The 16:10 restart still logged the critical, then dumped core. The stack is `g_irepository_find_by_name` in `libgirepository-1.0.so.1`, from `oll_mrpc_gi_vfunc_offset`, from `shell_global_bind_display`, from `gsr_client_application_prepare_host`. Client pid 8925. That binary is still what the guest will spawn until something installs a different `gsr-client`. This tree's `Application.vala` is back on `GI.Repository` (1.0). Do not treat the guest checkout or `/usr/bin/gsr-client` as a copy of this tree.

A throwaway program on the guest (`/tmp/gi-repository-gate.c`, same as `tests/call-sync-repro/gi-repository-gate.c`):

- 1.0 `g_irepository_require("Gio")` then `gjs_context_new` prints the critical and exits 1 (`gi-repository-gate: miss`).
- 2.0 `gi_repository_require("Gio")` then `gjs_context_new`, not calling 1.0, prints `gi-repository-gate: ok`.
- Linking `libgirepository-1.0` but not calling it also printed ok.

So the two libraries can sit in one process. The second one to register `GIRepository` is what dies. The client has to call 1.0 (`libocrpc` vfunc offsets and the current require) and then has to create a GJS context. That is the block. The in-tree targets are `gi-repository-gate-fail` and `gi-repository-gate-fix` (`-DGATE_GI2`). The fix target is a meson test. The fail target is not: it is the crash.

Do not edit OLLMchat from this tree. A 2.0 port of `OLLMrpc.Gi` would be that tree's change. Doing the require in 2.0 while `vfunc_offset` stays on 1.0 is the 16:10 coredump.

## Left as it was

- Keymap signals `keymap-changed`, `keymap-layout-group-changed`, and `reset-keymap-description` are not relayed.
- `ColorStateIcc.get_file`, `Stage.foreach_sprite`, and `Sprite.sequence` stay denied.
- Three mutter-16 gates are not built on API 18 (`logout-text-pointer-gate`, `clutter-event-frame-order-gate`, `clutter-drag-leave-gate`).
- `python3` was removed from Debian Build-Depends and the RPM BuildRequires. The runtime package still says mutter 16.

## LLM efforts

- Read `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log` and `journalctl -b _PID=28107` on `alan@192.168.122.52`. Last critical line is the Meta 16 typelib miss. Process list has `gsr-server` and no `gsr-client`. Shell debug log was last written 11:00, before this login.
- `python3` `gi.require_version` for Meta, Clutter, and St: version 16 raises `Namespace … not available for version 16`; version 18 prints `ok`. Same typelib path the server prepends.
- `ninja -C build src/gsr-server` on the guest after `MUTTER_API_VERSION` was set to `18` in `build/src/Config.vala`. Linked `build/src/gsr-server`. Installed over `/usr/bin/gsr-server` (`prefix` `/usr`). The running pid 28107 is still the 15:03 binary.
- 15:27 login, new server. `mutter-rpc.debug.log` reaches `listening` and `spawned /usr/bin/gsr-client`. `org.gnome.ShellRpc.debug.log` is 788 bytes: `Application.vala:99` Clutter version 16 not found, then the server's 30s `client not ready` kill. `gi.require_version` against `mutter-rpc-18:mutter-18:gnome-shell` fails for Meta, Clutter, St, Shell, and Cogl at 16 and succeeds at 18. Client requires in `Application.vala` now use `MUTTER_API_VERSION`. Not copied or installed onto the guest.
- 15:41, after the guest reboot. No GDM login. `getty@tty2` masked, `chvt 2`, then `systemd-run --uid=alan -p PAMName=login -p TTYPath=/dev/tty2` of `dbus-run-session -- gsr-server --debug --wayland`. Server log: mutter 50.1, virtio_gpu, `listening`, spawned client pid 3003. Client log completes RPC 1–16, then `Application.vala:179` and `cannot register existing type 'GIRepository'` plus the `g_once_init_leave` / `g_object_new_with_properties` assertions. Unit stopped, getty unmasked, `fgconsole` back on 3. A first attempt without masking getty exited at once because `getty@tty2` took the VT.
- 16:00 greeter login, same critical at `Application.vala:179`. Server at 16:01:14: `client not ready after 30s, killing it`. `gsr-server` left running on VT 5.
- 16:04 guest compile of `tests/call-sync-repro/gi-repository-gate.c`. 1.0 require then `gjs_context_new` prints the same critical. 2.0 require then `gjs_context_new` prints `gi-repository-gate: ok` (exit 0). Linking 1.0 without calling it also prints ok.
- 16:08 `ninja -C build src/gsr-client` on the guest after `prepare_host` was pointed at `gi_repository_*`, and that binary was copied to `/usr/bin/gsr-client`. `ldd` still shows both `libgirepository-2.0` and `libgirepository-1.0` (the 1.0 soname comes in through `libocrpc`). Generated `Application.c` calls `gi_repository_require` only.
- 16:10 `systemctl --user start org.gnome.ShellRpc@wayland.service` on the existing VT 5 login. Client reaches `St-ThemeContext.set_scale_factor`, then the same critical, then `systemd-coredump` for pid 8925. Stack: `g_irepository_find_by_name` (`libgirepository-1.0`) ← `oll_mrpc_gi_vfunc_offset` ← `shell_global_bind_display` ← `gsr_client_application_prepare_host`. Server logs `client exited`. `Application.vala` in this tree was put back on `GI.Repository`. The guest `/usr/bin/gsr-client` was left as the 16:08 binary. Copies of the 2.0 `Application.vala`, `src/meson.build`, `tests/gjs-embed/Application.vala`, `vapi/girepository-2.0.vapi`, and the gate were placed in the guest checkout; the vapi is not part of this tree.
