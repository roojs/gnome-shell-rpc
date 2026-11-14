# Enabling extensions aborts the client while launching DING

**Status:** ✔️ archived 2026-11-14. Closed 2026-11-07 — `new_subprocess` abort fixed (`[CCode (cname = "meta_wayland_client_new_subprocess")]`).

`Meta.WaylandClient.new_subprocess` aborts `gsr-client` in
GJS `Function::invoke` (`function.cpp:1006`, `GError** argument number
mismatch`). The Meta-18 typelib asks for
`meta_wayland_client_new_subprocess`. Vala compiled the constructor as
`meta_wayland_client_new_new_subprocess`, so the stock symbol was
missing and the invoker never got a 4-argument cif (3 args plus
`GError**`). `cif.nargs` is 4 once that symbol exists, and the same
call returns a catchable `GLib.Error` instead of aborting.

Landed: `[CCode (cname = "meta_wayland_client_new_subprocess")]` on
`WaylandClient.new_subprocess` in
`src/client/libmutter-rpc-18/overrides/WaylandClient.override.vala`.

Reproduction, on `alan@192.168.122.115`, no compositor:

```bash
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libshell-18.so \
GI_TYPELIB_PATH=/usr/lib/x86_64-linux-gnu/mutter-rpc-18:/usr/lib/x86_64-linux-gnu/mutter-18 \
gjs /tmp/ding-new-subprocess.js
```

`/tmp/ding-new-subprocess.js` calls `Meta.create_context` then
`Meta.WaylandClient.new_subprocess`. Before the cname, that aborts with
the journal line. After, it must not. This host is mutter 16, so Weston
here never calls `new_subprocess`.

Seen originally on the Ubuntu 26.04 emulator (`ubuntu2604`, GNOME Shell
50.1, gjs 1.88.0). Quiet Wayland session. `gsr-server` pid 53226
started 20:02:48 HKT as `/usr/bin/gsr-server --wayland`. Binaries
stamped 20:02:23. User extensions on from Extension Manager. Both
clients aborted. Server stayed up.

Journal is `journalctl -b` for the two client pids. Cores:

```text
/var/lib/systemd/coredump/core.gsr-client.1000.51c41eec5a0d48d8a81aa1e22eb41b93.53472.1793880899000000.zst
/var/lib/systemd/coredump/core.gsr-client.1000.51c41eec5a0d48d8a81aa1e22eb41b93.55538.1793880921000000.zst
```

Both are signal 6 (ABRT).

## What the log shows

`gsr-client` pid 53472, the client from session start, at 20:14:59:

```text
Launching DING process
**
Gjs:ERROR:./obj-x86_64-linux-gnu/../gi/function.cpp:1006:bool Gjs::Function::invoke(JSContext*, const JS::CallArgs&, JS::HandleObject, GIArgument*): assertion failed: (ffi_arg_pos < ffi_argc && "GError** argument number mismatch")
Bail out! Gjs:ERROR:.../gi/function.cpp:1006:... assertion failed: (ffi_arg_pos < ffi_argc && "GError** argument number mismatch")
```

The server then spawned pid 55538 at 20:15:03, still without
`--debug`. That client reached `GNOME Shell started` at 20:15:13. At
20:15:16 enabling extensions logged a non-fatal error from
`ubuntu-appindicators@ubuntu.com`:

```text
Extension ubuntu-appindicators@ubuntu.com: TypeError: (intermediate value).TrayManager is not a constructor
_enable@file:///usr/share/gnome-shell/extensions/ubuntu-appindicators@ubuntu.com/trayIconsManager.js:67:22
_toggle@file:///usr/share/gnome-shell/extensions/ubuntu-appindicators@ubuntu.com/trayIconsManager.js:53:18
TrayIconsManager@file:///usr/share/gnome-shell/extensions/ubuntu-appindicators@ubuntu.com/trayIconsManager.js:48:14
initialize@file:///usr/share/gnome-shell/extensions/ubuntu-appindicators@ubuntu.com/trayIconsManager.js:31:32
enable@file:///usr/share/gnome-shell/extensions/ubuntu-appindicators@ubuntu.com/extension.js:60:43
_callExtensionEnable@resource:///org/gnome/shell/ui/extensionSystem.js:265:38
async*_onEnabledExtensionsChanged@resource:///org/gnome/shell/ui/extensionSystem.js:593:24
_onUserExtensionsEnabledChanged@resource:///org/gnome/shell/ui/extensionSystem.js:559:20
_loadExtensions/<@resource:///org/gnome/shell/ui/extensionSystem.js:695:18
set UserExtensionsEnabled@resource:///org/gnome/shell/ui/shellDBus.js:508:25
```

That TypeError did not abort the process. At 20:15:21 pid 55538 printed
`Launching DING process` and aborted on the same `function.cpp:1006`
`GError** argument number mismatch` assertion.

`gsettings get org.gnome.shell disable-user-extensions` is now `false`.
`enabled-extensions` is `@as []`. DING and the appindicators extension
are session-mode extensions; they load once user extensions are allowed.
`extension-manager` is still running under the server cgroup.

## Where it aborts

`Launching DING process` is
`/usr/share/gnome-shell/extensions/ding@rastersoft.com/extension.js:445`,
`LaunchSubprocess.spawnv`. On a Wayland compositor that function calls
`Meta.WaylandClient.new_subprocess(global.context, launcher, argv)` when
that constructor exists, then `get_subprocess()`. The GJS assertion is
inside `Gjs::Function::invoke` for a throwing call. `new_subprocess` is
the throwing call on that path. `get_subprocess()` does not throw, and
the `catch` in `spawnv` never logged `Error while trying to launch DING
process`, so the process died inside the invoke rather than returning a
JS exception.

The stack in both cores is `abort` ← `g_assertion_message_expr` ←
`libgjs.so.0`, then a JS call from a GLib callback, with
`gjs_context_eval_module_file` still on the stack under
`gsr_client_application_real_command_line`. The callable name is not in
the coredumpctl frames.

## LLM efforts

- 2026-11-05 20:18 HKT. User enabled extensions on the Wayland emulator
  session and it crashed; asked for a bug. Local
  `~/.cache/gnome-shell-rpc/` logs are from 2026-11-04 10:10.
  `alan@192.168.122.115` (`ubuntu2604`) is the live session: server pid
  53226 since 20:02:48, no `--debug`, binaries 20:02:23. No `gsr-client`
  left. Cores for pid 53472 (20:14:59) and pid 55538 (20:15:21), both
  ABRT. Journal for both ends at `Launching DING process` and the
  `function.cpp:1006` `GError**` assertion. Pid 55538 also logged the
  appindicators `TrayManager is not a constructor` TypeError at 20:15:16
  via `UserExtensionsEnabled`, and kept running until the DING line.
  Confirmed the log string and `new_subprocess` call in the guest's
  `ding@rastersoft.com/extension.js`. Did not edit `src/`.
- 2026-11-06. Guest still has both cores and the journal lines.
  gjs 1.88.0, mutter 50.1. Local Weston logs are mutter 16 (`spawnv
  returned null`); they do not contain `function.cpp:1006`. Stock and
  rpc Meta-18 GIR for `new_subprocess` match: constructor, throws,
  zero-terminated `argv`. `gjs` with `LD_PRELOAD=libshell-18.so` and
  `Meta.create_context("ding-repro")` then `new_subprocess` aborts on
  the same assertion (`/tmp/ding-new-subprocess.js`). `cif` prep fails
  with `undefined symbol: meta_wayland_client_new_subprocess`. The
  library exports `meta_wayland_client_new_new_subprocess` (4 args,
  including `GError**`). A wrapper that exports the stock name and
  calls the Vala symbol makes `gi_function_info_prep_invoker` report
  `cif.nargs 4`, and the gjs script catches
  `Client: disconnected` instead of aborting. Vala check: a constructor
  named `new_subprocess` emits `*_new_new_subprocess` unless
  `[CCode (cname = "...")]` is set; `KeymapDescription.new_from_rules`
  already uses that and its symbol matches the GIR. Copied that cname
  onto `WaylandClient.new_subprocess`.
- 2026-11-14. User: archive old desktop cube / icons / DING bugs. Moved to `docs/bugs/done/`.
