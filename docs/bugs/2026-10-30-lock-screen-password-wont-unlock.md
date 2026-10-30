# Lock screen opens, password does not unlock

**Status:** guest log read. The captured lock attempt never submitted a password. Weston password submit not run yet.

## Seen

User 2026-10-30, Ubuntu 25.04 guest `alan@192.168.122.52` (`alan-VirtualBox`): the lock screen opens, and typing the password does not unlock.

Boot `-1` (`8877c3dffbc941178c1be6f7423c189e`), 2026-10-30 14:45:38. Two key presses landed on `Gjs_ui_unlockDialog_UnlockDialog` (`type=1`, `hook=1`). Each one threw before the password page could take the character:

```text
JS ERROR: GLib.Error g-invoke-error-quark: Could not locate clutter_event_get_key_unicode:
  'clutter_event_get_key_unicode': /lib/x86_64-linux-gnu/libmutter-clutter-rpc-16.so:
  undefined symbol: clutter_event_get_key_unicode
```

That library on that boot did not export the symbol. The handler is `unlockDialog.js` `vfunc_key_press_event`. No `gdm-password` or verification line follows those keys.

Boot `0` installed `/usr/lib/x86_64-linux-gnu/libmutter-clutter-rpc-16.so` at 15:05, and that file exports `clutter_event_get_key_unicode`. This boot has no lock attempt. `gsr-client` pid 6775 aborted at 15:08:15 in `shell_polkit_authentication_agent_auth_request_initiate` while `do-release-upgrade` asked for `com.ubuntu.release-upgrader.release-upgrade`. That abort is the upgrade bug, not this one.

## Reproduction

Weston password submit not run yet.

---

## LLM efforts

**2026-10-30 15:07.** `ssh alan@192.168.122.52`. Host `alan-VirtualBox`, Ubuntu 25.04. Current boot started 14:49. Session login 15:07:12, `gsr-client` pid 6775. Client log has key-press and `St-Entry.get_text` at 15:07:25 and 15:07:37 during startup. No `unlock`, `shield`, or `AuthPrompt` line. At 15:08:15 pid 6775 SIGABRT: `gjs_value_from_array_and_length_values` `G_VALUE_HOLDS_POINTER(array_value)` from `shell_polkit_authentication_agent_auth_request_initiate`. polkitd: `com.ubuntu.release-upgrader.release-upgrade` failed to authenticate. `nm -D` on `libmutter-clutter-rpc-16.so` (mtime 15:05) shows `clutter_event_get_key_unicode`.

**2026-10-30 15:12.** Boot `-1` journal, 2026-10-30 14:45:31–14:45:38. Pointer motion on `UnlockDialog`, then two `type=1` key presses. Each key: `JS ERROR` `undefined symbol: clutter_event_get_key_unicode`. No verification line after that. That boot's library predates the 15:05 install.
