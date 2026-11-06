# Typing in the overview search crashes the installed shell

**Status:** ✅ closed 2026-11-06. User: this is not an active bug. Overview
search in this tree reads `fade_margins` and stays up. 2026-11-06 08:57 HKT:
`fade-margins-search/ui/init: text="ter" fade=St_ScrollViewFade top=0`,
then `ok`, and `nested-weston-prove: stop (smoke-ok) after 7s`. The same
search activated `org.gnome.Characters`. The installed client that crashed
has not been updated. The getter ABI fix is already in this tree.

On the installed session the user typed in the overview search. The shell
activated search providers, including `org.gnome.Characters`, and selected a
result. Stock `search.js` `_setSelected` calls
`ensureActorVisibleInScrollView`, which reads
`scrollView.get_effect('fade').fade_margins.top`. That read killed
`gsr-client` with SIGSEGV at 14:50:40 HKT. Core 17562 is:

```text
/var/lib/systemd/coredump/core.gsr-client.1000.c4f6d792369b4040b2720d4021538a99.17562.1793861440000000.zst
```

Characters was the search provider the shell woke. It was not a separate
application the user launched.

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

Type in the overview search and let it select a result. That is the path
that reads `fade_margins`:

```bash
GSR_NESTED_TIMEOUT=60 GI_META_SMOKE=fade-margins-search/ui/init \
  ./scripts/agent-nested-smoke-prove.sh
```

Pass is `fade-margins-search/ui/init: ok` with a numeric `top=`. A dead
client before that line is the installed failure. The `ui/init.js` path
is required so gsr-smoke takes the shell startup lock.

The 14:50 core is on `alan@192.168.122.52`, which does not answer from here.
The same search, on the guest that does answer (`alan@192.168.122.115`,
boot `51c41eec5a0d48d8a81aa1e22eb41b93`), is the 20:14:31 journal line
`Activating service name='org.gnome.Characters' requested by gsr-client`.
Inspect the original core on that machine with:

```bash
coredumpctl info 17562
coredumpctl debug 17562
```

The build-time ABI gate only checks the C signature. It does not type in
the overview:

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
- 2026-11-06 08:35 HKT. User: the report says fixed, and the headline is the
  crash, not the action that produced it. Read the guest that answers,
  `alan@192.168.122.115` boot `51c41eec5a0d48d8a81aa1e22eb41b93`. At 20:14:31
  `gsr-client` activated `org.gnome.Characters` together with Settings,
  Calculator, clocks, and seahorse. That is overview search, not launching
  the Characters application. `192.168.122.52` does not answer, so core
  17562 was not re-read. Local `weston-autolaunch-prove.log` ends
  `stop (picker-up)`; that run did not search. Rewrote the top of this
  file around the search. Added
  `tests/gjs-embed/fade-margins-search-smoke.js`.
- 2026-11-06 08:46 HKT. Ran
  `GSR_NESTED_TIMEOUT=60 GI_META_SMOKE=fade-margins-search-smoke
  ./scripts/agent-nested-smoke-prove.sh`. Prove killed Weston (ec=137).
  `nested-weston-prove.tee.log`:
  `fade-margins-search-smoke.js missing at
  build/src/server/../../tests/gjs-embed/… — skip client spawn`.
  The server binary is `build/src/server/gsr-server`, so two `..` segments
  land in `build/tests`, not the source tree. No search ran.
  `SpawnClient` now walks three parents. Rebuilt `gsr-server`.
- 2026-11-06 08:49 HKT. Same command after the path fix. Smoke loaded.
  `fade-margins-search-smoke: FAIL start TypeError: global.stage.context is null`
  at `keyboard.js:1063` during `main.start`. Before that,
  `ClutterBoxLayout child unnamed minimum height: -12` and
  `socket closed` during `Clutter-Actor.allocate`. The script path did not
  end in `ui/init.js`, so `begin_shell_startup` did not run. No search.
- 2026-11-06 08:55 HKT.
  `GI_META_SMOKE=fade-margins-search/ui/init`. `begin_shell_startup` ran.
  `GNOME Shell started`. Search text `ter` activated
  `org.gnome.Characters`, same as the installed journal. Then
  `fade-margins-search/ui/init: miss no-selection text="ter"`. The entry
  was not key-focused, so `highlightDefault` stayed false and
  `fade_margins` was not read. Typing does focus the entry.
- 2026-11-06 08:57 HKT. Same command after `grab_key_focus()` before the
  text. `text="ter" fade=St_ScrollViewFade top=0` then
  `fade-margins-search/ui/init: ok`.
  `nested-weston-prove: stop (smoke-ok) after 7s`. Prove exit 0. The
  selected result read `fade_margins.top` and the client stayed up.
- 2026-11-06 08:58 HKT. User: close it, it is not an active bug. Moved to
  `docs/bugs/done/`.
