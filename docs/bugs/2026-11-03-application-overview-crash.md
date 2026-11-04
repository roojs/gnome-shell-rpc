# Application overview crashes and recovery page is unresponsive

**Status:** Reproduced on the Ubuntu 26.04 / GNOME Shell 50.1 guest `alan@192.168.122.115`. Selecting the application overview aborts `/usr/bin/gsr-client` pid 71584 at 23:19:15; `gsr-server` remains alive without a client, which explains the displayed but unresponsive recovery page.

The direct failure is GJS `Gjs::Function::invoke`: `ffi_arg_pos == ffi_argc` fails as `(2 == 0)` while handling the relayed `Clutter.Gesture::may-recognize` signal. The core's GI metadata identifies `Clutter.Gesture.get_point_event`, C symbol `clutter_gesture_get_point_event`, in the installed RPC `Clutter-18.typelib`. `Gesture.get_point_event` is a bare deny, so the client library does not export that stock symbol. This is the same missing-GI-symbol failure shape as the fixed keymap constructor, with two marshalled arguments rather than six.

The server already has API-18 helpers that pack the returned `Clutter.Event`, but their `rpc_register()` methods are not called from the Clutter namespace registration. No product fix has been applied yet.

## Reproduction

Start the installed GNOME Shell RPC session on the guest and select the application overview. Core 71584 and `journalctl -b _PID=71584` are the current proof. The client log ends after RPC 11278 and the relayed `may-recognize` notification; the server records `client exited manual-restart=false`.

## LLM efforts

- 2026-11-03 23:21. User reported that selecting the application overview crashes the session and leaves an unresponsive recovery page. Opened this report before investigation.
- 2026-11-03 23:22. Read the guest client/server logs, journal, and core 71584. The client abort is GJS's GI invoker assertion `(2 == 0)` during `Shell.Signals.emit("may-recognize")`; the server remains alive after `SpawnClient.vala:169: client exited`, accounting for the unresponsive recovery UI.
- 2026-11-03 23:24. Decoded the core's `Gjs::Function` and `GIBaseInfo`. The callable is `Clutter.Gesture.get_point_event`, symbol `clutter_gesture_get_point_event`, at blob offset `0x1b208` in `/usr/lib/x86_64-linux-gnu/mutter-rpc-18/Clutter-18.typelib`. The matching client deny is bare and `nm` confirms the RPC client library has no such symbol.
