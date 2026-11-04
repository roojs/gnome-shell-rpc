# Application overview crashes and recovery page is unresponsive

**Status:** Reproduced on the Ubuntu 26.04 / GNOME Shell 50.1 guest `alan@192.168.122.115`. Selecting the application overview aborts `/usr/bin/gsr-client` pid 71584 at 23:19:15; `gsr-server` remains alive without a client, which explains the displayed but unresponsive recovery page.

The direct failure is GJS `Gjs::Function::invoke`: `ffi_arg_pos == ffi_argc` fails as `(2 == 0)` while handling the relayed `Clutter.Gesture::may-recognize` signal. The core's GI metadata identifies `Clutter.Gesture.get_point_event`, C symbol `clutter_gesture_get_point_event`, in the installed RPC `Clutter-18.typelib`. `Gesture.get_point_event` is a bare deny, so the client library does not export that stock symbol. This is the same missing-GI-symbol failure shape as the fixed keymap constructor, with two marshalled arguments rather than six.

The server already has API-18 helpers that pack the returned `Clutter.Event`, but their `rpc_register()` methods are not called from the Clutter namespace registration. No product fix has been applied yet.

The gesture fix now exports `clutter_gesture_get_point_event`, rebuilds the compact event from the server reply, and registers the existing server helper. It moved the manual Applications test through loading the app grid. Core 8368 then exposed a second missing stock symbol: `Clutter.Margin.copy` resolves `clutter_margin_copy`, while Vala had emitted only its private `clutter_margin_dup` helper. The direct Margin gate reproduced `(1 == 0)` and passes after exporting the stock copy function. Both fixes are installed; the client restarted as pid 10947.

## Reproduction

Start the installed GNOME Shell RPC session on the guest and select the application overview. Core 71584 and `journalctl -b _PID=71584` are the current proof. The client log ends after RPC 11278 and the relayed `may-recognize` notification; the server records `client exited manual-restart=false`.

## LLM efforts

- 2026-11-03 23:21. User reported that selecting the application overview crashes the session and leaves an unresponsive recovery page. Opened this report before investigation.
- 2026-11-03 23:22. Read the guest client/server logs, journal, and core 71584. The client abort is GJS's GI invoker assertion `(2 == 0)` during `Shell.Signals.emit("may-recognize")`; the server remains alive after `SpawnClient.vala:169: client exited`, accounting for the unresponsive recovery UI.
- 2026-11-03 23:24. Decoded the core's `Gjs::Function` and `GIBaseInfo`. The callable is `Clutter.Gesture.get_point_event`, symbol `clutter_gesture_get_point_event`, at blob offset `0x1b208` in `/usr/lib/x86_64-linux-gnu/mutter-rpc-18/Clutter-18.typelib`. The matching client deny is bare and `nm` confirms the RPC client library has no such symbol.
- 2026-11-04 08:19. Added `clutter-gesture-invoker-current` / `clutter-gesture-invoker-fix`; the missing-symbol fixture fails and the matching-symbol fixture passes. Added the stock-named client override and registered the existing `PressGesture` server event helper. A build-tree DBus `ShowApplications` request stayed alive through RPC 14309, but that request bypasses the physical button's gesture path.
- 2026-11-04 09:00. User clicked Applications and produced core 6729, but the core executable is `/usr/bin/gsr-client` timestamped before the candidate was installed. Its stack is another GJS argument-count assertion while draining relayed style signals; it is not evidence from the candidate build.
- 2026-11-04 09:01. Installed the rebuilt project and restarted `org.gnome.ShellRpc@wayland.service`. The running client is the new `/usr/bin/gsr-client`; `nm -D /lib/x86_64-linux-gnu/libmutter-clutter-rpc-18.so` now shows exported `clutter_gesture_get_point_event`. Awaiting the exact Applications-button retest.
- 2026-11-04 09:02. The installed gesture candidate loaded the Applications grid, then client pid 8368 aborted. The last log activity is app-grid allocation and `style-changed`, not `may-recognize`. Core decoding identifies `Clutter.Margin.copy`, stock C symbol `clutter_margin_copy`, in `Clutter-18.typelib`; the client library exported `clutter_margin_dup` but not the stock symbol. This is a new one-versus-zero invoker assertion after the gesture fix moved the bar.
- 2026-11-04 09:04. A standalone GJS gate using the RPC Clutter-18 typelib reproduced `margin.copy()` aborting `(1 == 0)`. Added the real stock `clutter_margin_copy` implementation; the same gate prints `clutter-margin-copy: ok` on both API 16 locally and API 18 on the guest.
- 2026-11-04 09:10. The formal `clutter-margin-copy` Meson gate passes on the guest. Installed the build and restarted the user service. `nm` confirms `/lib/x86_64-linux-gnu/libmutter-clutter-rpc-18.so` exports `clutter_margin_copy`; no core newer than 8368 exists before the next manual Applications test.
