# A crash abort never reaches the journal

**Status:** ✅ closed 2026-10-07. User: assume fixed. The 11:02 `alan2` greeter login aborted in glib and left no message. [`2026-10-04-greeter-crash-screen.md`](2026-10-04-greeter-crash-screen.md).

## Seen

`gsr-client` 185375 and 186077 each hit `int3` in `libglib-2.0.so.0.8400.1` at offset `0x73e0f`. That is `GLib.error` / a fatal log. The journal has the criticals from just before, and not the abort string.

`ApplicationInterface.debug_log` (`src/ApplicationInterface.vala`) writes stderr only when `--debug` is on, or the level is `LEVEL_CRITICAL`. `GLib.error` is `LEVEL_ERROR`. The greeter does not pass `--debug`, so the handler returns without printing. glib then traps. `abort` does not flush stdio, so a line that was only sitting in the stderr buffer would be lost as well.

The cache file `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` is opened only when `--debug` is on, and it is truncated on open. For this login it would be under `/home/alan2`, which this account cannot read. The journal is the log that is readable from the other seat.

`/var/crash/_usr_bin_gsr-client.1002.crash` is mode 640, owner `alan2`. This run did not replace the 09:42 file. A core would name the frame. We do not have one.

## Crash screen

The greeter server is not started with `--debug`, so the client stays quiet and `LEVEL_ERROR` is dropped. The crash notice in `SpawnClient.on_crash` grows a **Restart with debug** choice, which spawns `gsr-client --debug`. **Restart without extensions** always passes `--debug` as well. A plain **Restart** stays quiet.

With `--debug`, `debug_log` already writes `LEVEL_ERROR` to stderr. That write is flushed before the handler returns, because `abort` does not flush stdio. The next debug boot's abort string lands in the journal.

## What would make the next crash readable

1. **Always write `LEVEL_ERROR` to stderr, then flush.** No `--debug` required. `gsr-client` and `gsr-server` both use this handler, and systemd already collects that stderr into the user journal. The 11:02 abort string would have been the next line after the `QuickSettings` critical.

2. **On `LEVEL_ERROR`, print a stack before returning.** `GLib.on_error_stack_trace` from the handler, then flush. The string says which `GLib.error` fired. The stack says where. The 09:42 core was the only reason that morning's abort was `Unexpected early end-of-stream` in `poll_drain_readable`.

3. **Do not treat the cache file as the crash log.** It is off for a greeter session, it lives in the crashing user's home, and `"w"` drops the previous run. The fatal line belongs on stderr. The cache file can stay the `--debug` trace.

4. **A core remains useful and stays hard to read.** Apport's file is mode 640 for uid 1002. The journal line from (1) and (2) is what the other account can see without copying that file across. If a core is still wanted, `alan2` (or root) has to copy `/var/crash/_usr_bin_gsr-client.1002.crash`.
