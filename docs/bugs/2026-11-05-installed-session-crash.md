# `ScrollViewFade.fade_margins` getter crashes the installed client

**Status:** Fixed in this tree; not yet installed on
`alan@192.168.122.52`. The installed `gsr-client` crashed with SIGSEGV at
14:50:40 HKT. Core 17562 is:

```text
/var/lib/systemd/coredump/core.gsr-client.1000.c4f6d792369b4040b2720d4021538a99.17562.1793861440000000.zst
```

The fault is a C ABI mismatch in the generated RPC St library:

```text
#0 st_scroll_view_fade_get_fade_margins
   (self=0x64f9a66787f0, result=0x1)
   at src/St_generated.vala:2236
```

Stock St declares and implements:

```c
ClutterMargin *
st_scroll_view_fade_get_fade_margins (StScrollViewFade *self);
```

The crashing installed `libst-rpc-18.so` exports the same stock symbol name
with a different Vala struct-return ABI:

```c
void
st_scroll_view_fade_get_fade_margins (StScrollViewFade *self,
                                      ClutterMargin *result);
```

GJS calls the one-argument stock ABI. The generated function interprets the
unprovided second argument as `result=0x1` and faults while copying the
`ClutterMargin` to that address. This is why the crash/recovery window may be
visible but not respond: `gsr-client` is gone while `gsr-server` PID 17267
remains alive.

`ScrollViewFade.override.vala` now owns the client-local value. Its explicit
method exports the stock borrowed-pointer getter, while the GObject property
uses a separately named Vala struct getter. The generated header now declares:

```c
ClutterMargin *
st_scroll_view_fade_get_fade_margins (StScrollViewFade *self);
```

## Reproduction

On the installed session on `alan@192.168.122.52`, take a shell path that
reads `St.ScrollViewFade.fade_margins`; the observed crash occurred while
GNOME Characters was being opened. Inspect the current proof with:

```bash
coredumpctl info 17562
coredumpctl debug 17562
```

The build-time ABI gate guards the stock signature without booting the shell:

```bash
meson compile -C build st-scroll-view-fade-margins-abi-gate
```

## LLM efforts

- 2026-11-05 14:51 HKT. User reported a new crash while using the session on
  `192.168.122.52` and asked for the crash report to be checked. Opened this
  report before investigating.
- 2026-11-05 14:52 HKT. Read the remote coredump list, user journal, and
  client/server logs. The new record is `gsr-client` PID 17562, SIGSEGV at
  14:50:40; no new Apport file exists. The server remains alive.
- 2026-11-05 14:53 HKT. Decoded core 17562 in GDB. Frame zero has
  `result=0x1`; the faulting instruction writes the first half of the margin
  to `(%rcx)`, where `rcx` is that invalid result pointer.
- 2026-11-05 14:54 HKT. Compared the generated RPC header/C with stock Shell
  50 `st-scroll-view-fade.[ch]`. The exported symbol is stock-named but has
  Vala's two-argument struct-return ABI instead of stock St's one-argument
  borrowed-pointer ABI. This accounts directly for the core.
- 2026-11-05 15:39 HKT. Added
  `tests/call-sync-repro/st-scroll-view-fade-margins-abi-gate.c`. It assigns
  the generated getter to the stock function-pointer type and fails under
  `-Werror=incompatible-pointer-types`: generated
  `void (StScrollViewFade *, ClutterMargin *)` versus stock
  `ClutterMargin * (StScrollViewFade *)`.
- 2026-11-05 15:42 HKT. Replaced the `local=1` auto-property with
  `ScrollViewFade.override.vala`. The generated stock symbol now returns
  `ClutterMargin *`; the separately named property getter retains Vala's
  struct-out ABI. `st-scroll-view-fade-margins-abi` and
  `clutter-margin-copy` pass.
- 2026-11-05 15:44 HKT. Ran
  `GI_META_SMOKE=app-search-smoke GSR_NESTED_TIMEOUT=60
  ./scripts/weston-gsr-prove.sh`. The nested API 16 session did not reach the
  fade-margin observation: mutter exited with code 133 and the smoke reported
  the separate startup failure `global.stage.context is null`. No
  `st_scroll_view_fade_get_fade_margins` crash occurred.
