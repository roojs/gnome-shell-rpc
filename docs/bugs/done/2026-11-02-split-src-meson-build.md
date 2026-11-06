# Split `src/meson.build`

**Status:** ✅ closed 2026-11-06. User: this is done. Each directory that builds a program or a library has its own `meson.build`. Nested prove reached the overview (`prove ec=0`). `alan@192.168.122.115` (`ubuntu2604`, mutter 50.1) compiled `libshell-18/Screenshot.vala` and the build finished.

A directory that builds a program or a library gets its own `meson.build`. The parent file only calls `subdir()`, in the order one library needs the previous one. No extra `src/meson/` folders.

`src/shared/` and `src/boxed/` are source used by those programs. They do not get their own file. The version directories (`libmutter-rpc-18`, `libshell-18`, and the other `-18` folders) are the same: the `-16` file picks those sources when the build is API 18.

## Where the big files are

`src/meson.build` is 1672 lines. It builds the server, the client, and every library. That is the file to split.

The root `meson.build` calls `subdir()` and still builds `gsr-nested-place`. The four test programs now live in their test folders.

`tests/meson.build` is six lines. It already calls each test folder. The long test file is `tests/call-sync-repro/meson.build` (1470 lines), and it is already in that folder.

## The files

`src/meson.build` becomes:

```text
subdir('generator')    # gi-stub-gen
subdir('client')       # libraries, then gsr-client and gsr-smoke
subdir('server')       # gsr-server
```

`src/client/meson.build` becomes:

```text
subdir('rpc')                        # libgsr-rpc-16.so
subdir('libmutter-clutter-rpc-16')   # Clutter library, boxed, headers
subdir('libmutter-rpc-16')           # Meta library
subdir('libst-rpc-16')               # St library
subdir('libshell-16')                # Shell library
subdir('gresource')                  # already has a meson.build
```

Then `gsr-client` and `gsr-smoke`, which live in `src/client/`.

`src/server/meson.build` builds `gsr-server` and the server sources under `src/server/`. One file for the server, not one per `libmutter-16` folder.

These test folders get a `meson.build`, and the root file stops building them:

```text
tests/ollm-demo-client/    # rpc-client
tests/gjs-embed/           # gjs-embed
tests/gi-rpc-mock/         # gi-rpc-mock
tests/fake-shell/          # fake-shell
tests/gi-rpc-echo/         # gi-rpc-echo, today inside src/meson.build
tests/gi-rpc-smoke/        # the legacy smoke library, same
```

`data/meson.build`, called from the root file, installs the session, the desktop file, the systemd units, and the apport ignore. That install is in `src/meson.build` today and is not part of the server.

## The uninstalled nest

The prove script opens `build/src/gsr-server` and loads the typelibs from that same folder. A program built by `src/server/meson.build` is saved at `build/src/server/gsr-server`.

Leave the real file there. Add a link `build/src/gsr-server` pointing at it, and the same for `Meta-16.typelib`, `Clutter-16.typelib`, `St-16.typelib`, `Shell-16.typelib`, and `Gsr-1.0.typelib`. The link is a build step, so it updates when the real file changes. The prove script keeps its current path.

## How to do it

One phase at a time. Each phase moves one directory, then `meson compile`, then the nested prove. A single commit that moves all 1672 lines leaves you with one failure and no way to see which move caused it.

Leave the nest's programs until last. The early phases do not change `build/src/gsr-server`.

1. ✔️ `data/` — session install only. The nest does not open these files. `data/meson.build` is called from the root file. The apport snippet is written to `build/data/gnome-shell-rpc`.
2. ✔️ The four test programs are in their test folders: `rpc-client`, `gjs-embed`, `gi-rpc-mock`, `fake-shell`. `gsr-shared` and `gsr-server-rpc` are static libraries in `src/meson.build` so a second `namespace.vala` or `Window.vala` is not compiled in the test folder. Vala’s `--basedir` is that folder, and two files of the same name would both be written as `namespace.c`.
3. ✔️ `gi-rpc-echo` is `tests/gi-rpc-echo/meson.build`. The smoke library is `tests/gi-rpc-smoke/meson.build`. Both are behind `legacy_gi_rpc_smoke`, which stays off. With that option on, `gi-rpc-echo` compiles. `libgirpcsmoke.so` still fails in `tests/meta-mini/Display.vala`: `Clutter.InputDevice` has no `rpc_lid`. Same sources and Vala flags as before the move.
4. ✔️ `src/generator/meson.build` builds `gi-stub-gen`. The program is `build/src/generator/gi-stub-gen`. Emit steps still call that target.
5. ✔️ The client libraries, in the order they already build: `rpc`, Clutter, Meta, St, Shell. `src/client/meson.build` calls those five. Typelibs stay declared in `src/meson.build`, so `Meta-16.typelib`, `Clutter-16.typelib`, `St-16.typelib`, `Shell-16.typelib`, and `Gsr-1.0.typelib` are still written to `build/src`. No link. `clutter-include` is still `build/src/clutter-include`. The `.so` and `.vapi` files are in each library's build directory. `gsr-client`, `gsr-smoke`, and `gsr-server` still build from `src/meson.build` and look in those directories. `gresource` stays called from `src/meson.build`, so `build/src/shell-js` does not move. `Gsr.Shared` is a static library inside the rpc build: valac names a source from outside the directory by its filename, and `shared/namespace.vala` would overwrite `rpc/namespace.vala`.
6. ✔️ `gsr-client` and `gsr-smoke` are built by `src/client/meson.build`, after `subdir('gresource')`. The programs are `build/src/client/gsr-client` and `build/src/client/gsr-smoke`. `build/src/gsr-client` and `build/src/gsr-smoke` are links, so `scripts/gi-rpc-smoke.sh` keeps its path. Typelibs stay in `build/src`. `gsr-server` is still the real file at `build/src/gsr-server`.
7. ✔️ `src/server/meson.build` builds `gsr-server` and the `gsr-server-rpc` static library. The program is `build/src/server/gsr-server`. `build/src/gsr-server` is a link to `server/gsr-server`. Typelibs stay real files in `build/src`, so the prove script's typelib directory is still that folder. `Gsr.Shared` is the `gsr-shared` static library: compiling `shared/namespace.vala` in the server target would overwrite `server/namespace.vala`. `gi-rpc-mock` and `gi-rpc-echo` add `-I` of the server build dir for `gsr-server-rpc.h`. SpawnClient reads `/proc/self/exe`, which is the real binary, so `build/src/server/gsr-client` and `build/src/server/gsr-smoke` are links to `../client/`. Nested prove reached the overview (`prove ec=0`).

## Shell versions

✔️ `src/client/libshell-16/meson.build` chooses the Shell sources. API 18 compiles `libshell-18/Screenshot.vala`, `Signals.vala`, and `EdgeDragGesture.vala`. API 16 compiles `libshell-16/Screenshot.vala` and `Signals.vala`. `--define=MUTTER_18` is gone. The 18 `paint_to_buffer` call passes a null `Clutter.ColorState`. This machine has mutter 48.1, so the local compile is the API 16 file. `alan@192.168.122.115` (`ubuntu2604`, mutter 50.1) compiled `libshell-18/Screenshot.vala` and the build finished.
