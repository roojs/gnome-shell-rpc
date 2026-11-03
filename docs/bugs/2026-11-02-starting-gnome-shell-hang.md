# Mutter 18 deploy testing — shell does not stay up

**Status:** 2026-11-03 22:04. The original `Gjs::Function::invoke` abort is fixed and proven on the local Ubuntu 26.04 guest `alan@192.168.122.115`. Exporting the three `Meta.KeymapDescription` overrides under the stock Meta-18 GIR C symbols made the off-product fixed gate pass; the rebuilt real session entered `Gsr-Mutter-Keymap.new_from_rules` at RPC 3996 and continued through more than 6000 RPCs.

The shell still does not stay up. Its next named failure is `Failed to setup quick settings: TypeError: can't access property "connectObject", this._manager is null` in Shell-50 `brightness.js`. Shell-50 constructs `panel` before `brightnessManager`; stock relies on the quick-settings async setup remaining suspended until `_initializeUI` reaches the manager construction. The RPC run resumes that setup reentrantly during panel construction. This downstream ordering failure is now the active bug.

Client pid 47827 subsequently aborts while GJS reports an illegal `Gio.AsyncReadyCallback` during shutdown. That abort is secondary: GJS 1.88.0 `gjs_dumpstack_string()` executes `out.resize(MAX(out.size() - 2, 0))`; with no remaining contexts, unsigned `out.size() - 2` underflows and throws `std::length_error`. It masks the orderly shutdown after the brightness exception and is not the keymap fix regressing.

The keymap reproduction remains `meta-keymap-invoker-current` (expected abort) and `meta-keymap-invoker-fix` (pass) under `tests/call-sync-repro`. The next reproduction must isolate the quick-settings promise resuming inside a synchronous RPC callback before its enclosing initializer advances.

`GJS_DEBUG_OUTPUT` cannot name the call on Ubuntu's release GJS: the argument lines in `gi/function.cpp` use `gjs_debug_marshal`, which is compiled out when `GJS_VERBOSE_ENABLE_MARSHAL=0`. This explains the empty `JS G FUNC` topic in the 16:18 log. The Shell-50 call immediately after this startup phase is `Gio.DBus.system.call(... RegisterSession ...)`. The exact callback and promisified forms both pass under stock GJS 1.88 on `192.168.122.115`; they return GDM's expected `InvalidArgs` error and do not assert. That call is therefore not a standalone GJS 1.88 failure. The current guest/core is needed to identify the callable or prove that the gsr process state causes it.

`no rpc_lid on ShellEdgeDragGesture` and `ClutterPanGesture has no property called 'enabled'` are gone on the 16:16 and 16:18 runs. `add_action` for the edge-drag gesture no longer returns `-32602`. The abort is still there, at the same RPC.

Uncommitted, and copied onto that guest: `src/client/libshell-18/EdgeDragGesture.vala`, `src/server/libshell-18/namespace.vala`, `src/server/libshell-18/EdgeDragGesture.vala`, `src/client/libmutter-clutter-rpc-18/overrides/ClickGesture.override.vala`, `src/client/libmutter-clutter-rpc-18/overrides/PanGesture.override.vala`, and the `src/meson.build` split that compiles `server/libshell-18/` only when `mutter_api_version == '18'`. API 16 still compiles `server/libshell-16/namespace.vala` and does not see the gesture. The prove sets `GSR_TYPELIB_DIR` to `build/src`. The installed typelib dir is still the Nov 2 `Shell-18.typelib`. tty6 was unmasked and the console put back on the greeter.

This is the handoff for the Ubuntu 26.04 / Mutter 18 / Shell 50 deploy. Phase 1 of [`docs/plans/0.9-multi-shell-series.md`](../plans/0.9-multi-shell-series.md). The GitHub 26.04 package job has not been started. `debian/control` and the RPM spec still depend on mutter 16 / gnome-shell 48.

## Guest

The reachable guest is `alan@192.168.122.52`, hostname `alan-VirtualBox`, Ubuntu 26.04.1, GNOME Shell 50.1, mutter 50.1 (`libmutter-18`). Tree `/home/alan/gitlive/gnome-shell-rpc`. `192.168.122.115` (`ubuntu2604`) does not answer. Vendor checkout is gnome-shell 50.0. This host is Ubuntu 25.04 / mutter 16. A host `ninja` or a host Weston run is not the 18 proof.

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

`alan@192.168.122.52`, tty6, 2026-11-03 16:18. Same command as 11:57, binaries `build/src/gsr-server` and `build/src/gsr-client`, `GSR_TYPELIB_DIR=build/src`.

Server log: mutter 50.1, `wayland-0`, spawned client pid 221738. Last client RPC is id 3995 `Clutter-Actor.add_child` at 16:18:49.492. `SpawnClient.vala:169: client exited` at 16:18:50.012. `systemd-coredump`: pid 221738, signal 6. Stack is `abort` ← `g_assertion_message_cmpint` ← `libgjs.so.0` offset `0x703cd`, which is `Gjs::Function::invoke` in gjs 1.88 `gi/function.cpp` after the argument loop: `g_assert_cmpuint(ffi_arg_pos, ==, ffi_argc)`. That assert does not log the callable. The nearby string `Error invoking %s` is the path that returns when an argument has no marshaller. This abort is the count mismatch, so that string is not printed. `/tmp/gjs-prove.log` from `GJS_DEBUG_OUTPUT` has no `JS G FUNC` lines and no `Marshalling` lines (0 of each). The function name is still unknown.

`Gsr-Shell-EdgeDragGesture.create` runs (id 595). `Clutter-Actor.add_action` after it no longer warns. `ClutterPanGesture has no property called 'enabled'` is gone. Still logged, and not shown to be the abort: `property 'mapped' of object class 'Gjs_ui_dateMenu_DateMenuButton' is not writable`, `g_value_get_object` / `g_atomic_ref_count_dec` criticals, and after the client is gone `g_signal_handler_disconnect` plus `panelBox` allocate warnings.

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
- 2026-11-03 11:44. `192.168.122.115` has no route. The running 26.04 guest is `192.168.122.52` (`alan-VirtualBox`, Shell 50.1). Its trees were behind: OLLMchat `8d13588a`, gnome-shell-rpc `170c9ba` plus a dirty GIRepository copy. Stashed that copy, fast-forwarded both trees (`1cba1934`, `0366113`). `meson setup --reconfigure` and `ninja` rebuilt `libocrpc.so` (`libgirepository-2.0.so.0` only) and `ocrpc.vapi`. gsr reconfigured with `-Docrpc_libdir=/home/alan/gitlive/OLLMchat/build/libocrpc`. `gsr-client` links that library and not `libgirepository-1.0`.
- 2026-11-03 11:47. Stopped the Nov 2 `/usr/bin/gsr-server` on tty5. tty6, `build/src/gsr-server`. No `MetaBackend` line. Client died in `windowManager.js:909`: `EdgeDragGesture is not a constructor`. The class is `shell-edge-drag-gesture.c` in the 50.0 vendor tree and was not in our Shell typelib. The installed typelib `/usr/lib/x86_64-linux-gnu/mutter-rpc-18/Shell-18.typelib` (Nov 2) is what the client loaded.
- 2026-11-03 11:53. Added `Shell.EdgeDragGesture` (`name`, `enabled`, `side`) and compiled it into `libshell-18` on API 18. Without `GSR_TYPELIB_DIR` the old typelib was still first and the constructor error stayed. With `GSR_TYPELIB_DIR=build/src` the error became `No property name on ShellEdgeDragGesture`, then after `set construct` on `name` it became `No property enabled on ClutterClickGesture` at `popupMenu.js:106`.
- 2026-11-03 11:57. `ClickGesture.override.vala` adds `enabled`, same shape as `ClickAction.override.vala`. That throw is gone. Client log then has `no rpc_lid on ShellEdgeDragGesture` from `Clutter-Actor.add_action`, and a binding critical `ClutterPanGesture has no property called 'enabled'`. pid 18191 SIGABRT, `g_assertion_message_cmpint` in `libgjs`. `coredumpctl gdb 18191` reported no match. Unit stopped, tty6 unmasked, `chvt 1`.
- 2026-11-03 14:38. `Shell.EdgeDragGesture` mints a lease via `Gsr-Shell-EdgeDragGesture.create` (id 595). The server peer is a `Clutter.Gesture` subclass. `Clutter-Actor.add_action` id 602 then returns `-32602` with an empty message (`Gi2` rejects the argument unless `obj.get_type()` is in `gtype_to_alias`). `PanGesture.enabled` is no longer logged. pid 217839 SIGABRT, same `libgjs` offset `0x703cd`. Last RPC id 3995 `Clutter-Actor.add_child`. Unit stopped, tty6 unmasked, `chvt 1`.
- 2026-11-03 16:16. API 18 server namespace is `src/server/libshell-18/namespace.vala`. It registers the gesture. `src/server/libshell-16/namespace.vala` is the API 16 file and has no version check. `register_alias("Clutter-Gesture", typeof(EdgeDrag))` is in the peer's `rpc_register`. The add_action `-32602` line is gone. pid 219653 SIGABRT at the same RPC id 3995. `coredumpctl debug 217839` on the 14:38 core: frame in `libgjs` is `Gjs::Function::invoke`, comparison string `"=="`, no callable name on the stack dump.
- 2026-11-03 16:18. `GJS_DEBUG_OUTPUT=/tmp/gjs-prove.log` with every topic. The file is 789559 bytes and ends in `JS CTX: JS context destroyed`. It contains 0 `JS G FUNC` lines and 0 `Marshalling` lines. pid 221738 SIGABRT. Last RPC still id 3995. `client exited` at 16:18:50.012. An earlier core the same minute is pid 220982. Unit stopped, tty6 unmasked, `chvt 1`.
- 2026-11-03 19:00. Tried to resume from the 16:18 guest logs and cores with `ssh -o BatchMode=yes -o ConnectTimeout=5 alan@192.168.122.52`; `192.168.122.52` returned `No route to host`. No new prove was run.
- 2026-11-03 19:17. `192.168.122.115` answers again. It has no gsr-client cores. gnome-shell-rpc is at `3d7657e` with the earlier uncommitted GIRepository files; OLLMchat is at `1cba1934`. It is not the checkout or build that produced the current failure.
- 2026-11-03 19:24. Read GJS 1.88 `gi/function.cpp` and `util/log.h`. The only per-argument messages before the failing assertion are `gjs_debug_marshal`; Ubuntu's release build compiles those calls to no-ops because `GJS_VERBOSE_ENABLE_MARSHAL` defaults to 0. Setting every runtime debug topic cannot produce the callable name. On `192.168.122.115`, ran both callback and `Gio._promisify` forms of the Shell-50 `Gio.DBus.system.call(... RegisterSession ...)` sequence under GJS 1.88. Both completed without an assertion and reported only `org.freedesktop.DBus.Error.InvalidArgs` from GDM.
- 2026-11-03 19:52. User corrected the machine mapping: `192.168.122.115` is the guest on this machine. It has an active tty3 user session, gnome-shell-rpc at `3d7657e`, and the nine-file uncommitted GIRepository experiment recorded at 10:49. Bringing it to current `414df64` requires preserving or discarding that guest-only worktree before rebuilding the API-18 prove.
- 2026-11-03 19:59. With user approval, stashed the guest's old nine-file GIRepository worktree, transferred the local branch commits after the guest's GitHub SSH authentication failed, and fast-forwarded gnome-shell-rpc `3d7657e` → `414df64` and OLLMchat `1cba1934` → `9ce8da1a`. Reconfigured and rebuilt OLLMchat `ocrpc`, `gsr-server`, and `gsr-client`. `ldd` shows `libocrpc.so` and `gsr-client` use `libgirepository-2.0.so.0` and no 1.0 library. `gi-repository-method-gate: ok`.
- 2026-11-03 20:00. On tty3 after masking `getty@tty3` and `autovt@tty3`, ran the build-tree server under a 40-second systemd-run timeout with `GSR_TYPELIB_DIR=build/src`. Client pid 43648 reached and received the reply to RPC 3995 `Clutter-Actor.add_child`, then aborted at 20:00:00. `coredumpctl list gsr-client` has the 7.7 MB core. Server stayed up until the timeout; tty2 and both tty3 units were restored.
- 2026-11-03 20:04. Decoded core 43648 rather than relying on GJS debug logging. In `Gjs::Function::invoke`, `r12` is the function private and its `m_info` points to a `GIBaseInfo` at Meta typelib offset `0x8880`. The mapped typelib is `build/src/Meta-18.typelib`; its function blob names `KeymapDescription.new_from_rules`, C symbol `meta_keymap_description_new_from_rules`, and a six-argument signature. The invoker's `ffi_argc` saved on the stack is zero while `ffi_arg_pos` is six. `nm -D build/src/libmutter-rpc-18.so` shows only `gsr_meta_keymap_description_new_from_rules`; core mappings show no stock `libmutter-18.so`.
- 2026-11-03 21:42. Added the off-product `meta-keymap-invoker-current` / `meta-keymap-invoker-fix` fixture under `tests/call-sync-repro`. On GJS 1.88, the current fixture's GIR names a missing `meta_keymap_description_new_from_rules` while the library exports the private `gsr_` name; it exits on the same `ffi_arg_pos == ffi_argc` assertion `(6 == 0)`. The fixed fixture uses one name in both places and prints `meta-keymap-invoker-fixed: ok`. Meson reports one expected failure and one pass.
- 2026-11-03 21:57. Applied the proven minor change to `KeymapDescription.override.vala`, rebuilt the client, and reran the tty3 build-tree session. `nm` shows the stock `meta_keymap_description_*` symbols. The real client passed the old boundary: RPC 3996 is `Gsr-Mutter-Keymap.new_from_rules`, and startup continued through RPC 6028 before a different error. The original six-versus-zero abort is fixed.
- 2026-11-03 22:04. Read client pid 47827's journal and core. The first failure is `Failed to setup quick settings: TypeError: can't access property "connectObject", this._manager is null` at installed Shell-50 `brightness.js:52`. Installed `main.js` constructs `panel` at line 263 and `brightnessManager` at line 278; `QuickSettings._setupIndicators()` is intentionally async, but it resumed during the panel constructor in this RPC run. The later SIGABRT is GJS 1.88.0's illegal-callback diagnostic during shutdown: the callback metadata is stock `Gio.AsyncReadyCallback`, and `gjs_dumpstack_string()` underflows `out.size() - 2` when its context list is empty, throwing `std::length_error`. That secondary GJS bug is not the active product failure.
