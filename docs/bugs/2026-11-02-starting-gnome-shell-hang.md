# Mutter 18 deploy testing — shell does not stay up

**Status:** `Gi.repository()` is in the running libocrpc. 2026-11-03 10:49. The server stays up and spawns the client. The client dies in `ui/init.js` on `cannot register existing type 'MetaBackend'`.

This is the handoff for the Ubuntu 26.04 / Mutter 18 / Shell 50 deploy. Phase 1 of [`docs/plans/0.9-multi-shell-series.md`](../plans/0.9-multi-shell-series.md). The GitHub 26.04 package job has not been started. `debian/control` and the RPM spec still depend on mutter 16 / gnome-shell 48.

## Guest

This run is `alan@192.168.122.115`, hostname `ubuntu2604`, Ubuntu 26.04.1, GNOME Shell 50.1, mutter 50.1 (`libmutter-18`). Tree `/home/alan/gitlive/gnome-shell-rpc`. The earlier logs in this file are from `alan@192.168.122.52` (`alan-VirtualBox`). Vendor checkout is gnome-shell 50.0. This host is Ubuntu 25.04 / mutter 16. A host `ninja` or a host Weston run is not the 18 proof.

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

On `ubuntu2604` (`192.168.122.115`) tty2 is the stock GNOME session. The prove used tty3. Mask and stop both `getty@tty3` and `autovt@tty3` before `chvt 3`. `autovt@tty3` starts on the switch when only getty is masked. Put the session back with `sudo chvt 2` and unmask both units.

If a gsr login is already up, the user unit is the restart:

```
sudo chvt 5
sudo -u alan XDG_RUNTIME_DIR=/run/user/1000 \
  systemctl --user restart org.gnome.ShellRpc@wayland.service
```

VT 5 was that login on this boot. Read `loginctl` before assuming the number.

Weston (`./scripts/weston-gsr-prove.sh`) is the nested prove on a machine that already has an X display and is the build under test. It is not a substitute for this guest, and this host's Weston only runs the mutter 16 build.

## Current failure

Guest `alan@192.168.122.115` (`ubuntu2604`), 2026-11-03 10:49. OLLMchat `1cba1934`. `Gi.repository()` assigns `dup_default()` on first use. `gi-repository-method-gate` prints `gi-repository-method-gate: ok`.

`build/src/gsr-server` gets past `Gi.vfunc_offset`. Log: mutter 50.1, `wayland-1`, `listening`, spawned `gsr-client` pid 40374. The client log then says `Typelib file for namespace 'Gsr', version '1.0' not found` at `Application.vala:110`, and `cannot register existing type 'MetaBackend'`, then `ui/init.js` throws `Unsupported type (null), deriving from fundamental (null)` at `environment.js:36`. `SpawnClient.vala:169: client exited`. The server was still running. Unit stopped, tty2 restored.

`build/src/Gsr-1.0.typelib` is on disk. `prepare_host` requires it before Clutter and Shell, and that require throws, so those two requires do not run.

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
- 2026-11-03. User: do not keep both GIRepository libraries alive in this process. libocrpc binds 2.0 when that is the library GJS uses. Filed OLLMchat `docs/bugs/2026-11-03-girepository-2.md`. `Gi.repository()` caches `gi_repository_dup_default` (transfer full, since 2.86). `GIRepository-2.0.gir` on 26.04 still describes `libgirepository-1.0.so.1`. `vapigen` 0.56 cannot consume `g-ir-generate` of `GIRepository-3.0.typelib` (GIR 1.0, then `<type name="any"/>`). This tree stays on the fail gate. OLLMchat product code was not edited.
- 2026-11-03. Guest `192.168.122.115`. OLLMchat `4720779f` built; `libocrpc.so` links only `libgirepository-2.0.so.0`. gsr configured with `-Docrpc_libdir=/home/alan/gitlive/OLLMchat/build/libocrpc`. `ninja` built `build/src/gsr-server` and `gsr-client`. tty3 after masking `getty@tty3` and `autovt@tty3`. Server log 09:55: mutter 50.1, `wayland-1`, then `GI_IS_REPOSITORY` criticals and `Gi2.vala:258: Gi.vfunc_offset: no object Clutter.Actor`. Core 37578 SIGABRT in `oll_mrpc_gi_vfunc_offset`. Gate `gi-class-init-gate-fail` exit 1 with those criticals. `gi-class-init-gate-fix` exit 0. Recorded in OLLMchat `docs/bugs/2026-11-03-gi2-repository-null.md`.
- 2026-11-03 10:49. Guest fast-forwarded to OLLMchat `1cba1934` (`Gi.repository()`). Rebuilt `libocrpc.so`. `gi-repository-method-gate` printed ok. tty3 server stayed up: listening, spawned client pid 40374. Client log: `Gsr` 1.0 typelib not found at `Application.vala:110`, then `cannot register existing type 'MetaBackend'`, then `ui/init.js` threw. Unit stopped, `chvt 2`.
