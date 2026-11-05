# Split `src/meson.build`

**Status:** investigation. 2026-11-02. No build change.

`src/meson.build` is 1615 lines. The root `meson.build` is 226 and `gnome-shell/meson.build` is 213. The unwieldy file is the `src` one. It is one straight-line script: source lists, four client libraries, the Shell facade, typelibs, `gsr-client`, `gsr-smoke`, `gsr-server`, pkg-config, and the session install.

Splitting it is possible. Meson will not load a sibling file such as `clutter.build` from the same directory. The supported cut is a folder of subdirectories, each entered once with `subdir()`, each containing a file named `meson.build`.

## What Meson will do

`subdir('name')` runs `name/meson.build` and then returns. Documented in the [subdir()](https://mesonbuild.com/Reference-manual_functions_subdir.html) reference:

- The argument is a directory relative to the current file. It cannot contain `..`.
- That directory's build file runs once per project. A second `subdir()` of the same directory errors.
- Variables are one scope for the whole project. A name set in a fragment is visible afterwards, including back in `src/meson.build` and, after `subdir('src')` returns, in the root file. There is no per-file scope. Names must stay unique, and `subdir()` order is the dependency order.
- `files()` remembers the directory it was called from, so a source list built in a fragment can be compiled by a target declared in the parent. Paths may use `..` as long as they stay inside the source tree. From `src/meson/clutter/meson.build` a source is `files('../../client/libmutter-clutter-rpc-16/namespace.vala')`.
- `meson.current_source_dir()` and `meson.current_build_dir()` change for the fragment. A `library()`, `executable()`, `custom_target()`, or `configure_file()` declared in the fragment writes its output under that fragment's build directory (`build/src/meson/clutter/`, and so on). There is no argument to send the output back up to `build/src/`.

An `include()` that would pull in `src/meson/clutter.build` and keep the current directory was proposed in [mesonbuild/meson#5209](https://github.com/mesonbuild/meson/pull/5209) and closed unmerged in 2021. The project asks for Meson `>= 0.59`. Nothing since then adds that include. A folder of `*.build` files is not a Meson feature we can use.

## Why the output directory matters here

Today every product target in this file is declared in `src/meson.build`, so the build tree has one directory:

- `build/src/gsr-server`, `build/src/gsr-client`, `build/src/gsr-smoke`
- `build/src/libmutter-rpc-16.so`, `libmutter-clutter-rpc-16.so`, `libst-rpc-16.so`, `libshell-16.so`, `libgsr-rpc-16.so`, and their `.vapi` files
- `build/src/Meta-16.typelib`, `Clutter-16.typelib`, `St-16.typelib`, `Shell-16.typelib`, `Gsr-1.0.typelib`
- `build/src/clutter-include/`
- `build/src/libmutter-rpc-16.pc` and the clutter pc, which the file itself documents as `PKG_CONFIG_PATH=build/src`

The nested launch scripts take the typelib directory from the server binary's directory (`GSR_TYPELIB_DIR="$(dirname "$MUTTER_RPC")"` in `scripts/nested-weston-prove.sh` and `scripts/nested-weston-hold.sh`). `src/client/Application.vala` passes that variable to `GI.Repository.prepend_search_path` as one path. It does not split on `:`. Typelibs for Meta, Clutter, St, Shell, and Gsr have to keep sharing one directory, or the client has to learn a path list.

Scripts that look up `build/src` by name:

| Script | Path |
| --- | --- |
| `scripts/nested-weston-prove.sh` | `build/src/gsr-server`, else `build/src/mutter-rpc` |
| `scripts/nested-weston-hold.sh` | same |
| `scripts/nested-init-prove.sh` | `build/src/mutter-rpc` |
| `scripts/mutter-rpc-catchsegv.sh` | `build/src/mutter-rpc` |
| `scripts/gi-rpc-smoke.sh` | `BINDIR=$BUILD/src`, then `gsr-client`, `gsr-smoke`, `gi-rpc-mock` |
| `scripts/compare-clutter-headers.sh` | `build/src/clutter-include/clutter` |
| `scripts/prepare-js-override.sh` | `build/src/shell-js/misc/config.js` |

`prepare-js-override.sh` follows `subdir('client/gresource')`, which already lives under `src/`. That call has to stay in a build file that can see `client/gresource` as a downward relative path. A fragment in `src/meson/` cannot `subdir('../../client/gresource')`.

The root file, after `subdir('src')`, uses `gjs_embed_config`, `gjs_shell_deps`, `gjs_shell_vala_args`, `rpc_config`, and `gtk4_dep`. Those names have to still be assigned when `src/meson.build` returns. `gtk4_dep` is only there for `fake-shell` in the root file.

## How the 1615 lines break up

The sections already follow the libraries. They are interleaved because each later library compiles against the previous one.

| Lines | What it is | Depends on |
| --- | --- | --- |
| 1–137 | `compositor_sources`, `mutter_vala_args`, `meta_mini_*` | `mutter_api_version` from the root file |
| 138–236 | names, `rpc_config`, gjs deps, `gnome_shell_rpc_config`, `gi-stub-gen` | `gnome_shell_pkglibdir`, `gnome_shell_js_runtime_dir` |
| 238–340 | `legacy_gi_rpc_smoke` typelib, lib, `gi-rpc-echo` | `gi-stub-gen` |
| 343–538 | Meta emit inputs, then Clutter emit, boxed, `gsr_clutter_boxed_lib` | `gi-stub-gen` |
| 539–578 | `gsr-rpc-16` | `ocrpc_dep` |
| 579–821 | Clutter `.so`, staged `clutter-include`, pc, then Meta `.so` | `gsr-rpc-16`, Clutter headers |
| 822–859 | Meta and Clutter typelibs | those two `.so` files |
| 860–1016 | St emit, `st-rpc` `.so`, St boxed, `mutter_rpc_client_dep` | Clutter client dep, Meta `.so` |
| 1017–1222 | `shell-16` `.so`, injected GIR, Shell and Gsr typelibs | St boxed, Clutter |
| 1223–1254 | `subdir('client/gresource')`, St typelib | vendor JS, `st-rpc` |
| 1255–1440 | `gsr-client`, `gsr-smoke`, St pc | all four client libs, gresource |
| 1441–1491 | Meta GIR install, build-tree and installed Meta pc | Meta `.so` |
| 1493–1523 | second `legacy_gi_rpc_smoke` block (`meta-override-client`) | same option as line 239 |
| 1525–1568 | `gtk4_dep`, `gsr-server` | `compositor_sources`, Clutter boxed, `rpc_config` |
| 1570–1615 | session, systemd user units, apport ignore | files under `data/` |

`gsr-server` also links `clutter_helper_vfunc_ids` from the Clutter emit. `gsr-client` links `gsr-rpc`, Meta, Clutter, and Shell.

## Options

### Option A — fragments only export variables

`src/meson/<job>/meson.build` assigns source lists and argument arrays. Every `library()`, `executable()`, `custom_target()`, and `configure_file()` stays in `src/meson.build`.

Outputs stay in `build/src`. Scripts, rpath, `--vapidir`, `GSR_TYPELIB_DIR`, and `PKG_CONFIG_PATH=build/src` stay as they are. `files()` in the fragment still records the right source path.

This is a real Meson split, and it is the one with no behavior change. It does less for the unwieldy part. The length is the target bodies (Clutter, Meta, St, Shell, the two client hosts), not the lists at the top. Those bodies would remain in the parent.

### Option B — fragments own their libraries, `build/src` keeps the session's lookup directory

Recommended.

Same folder. Each fragment declares the generator targets and the `shared_library()` / `static_library()` for that job, and publishes the build directory it landed in:

```meson
clutter_rpc_build_dir = meson.current_build_dir()
```

`src/meson.build` becomes the `subdir()` list plus the targets that must keep writing into `build/src`:

- `gsr-server`, `gsr-client`, `gsr-smoke`
- the typelib `custom_target`s (Meta, Clutter, St, Shell, Gsr), so `GSR_TYPELIB_DIR` stays one directory
- the build-tree `.pc` files, so `PKG_CONFIG_PATH=build/src` stays true
- `subdir('client/gresource')`
- the `clutter-include` stage, so `scripts/compare-clutter-headers.sh` stays true

Cross-links that today say `meson.current_build_dir()` because everything shared one directory get the other fragment's `*_build_dir` instead: `--vapidir`, `-L`, `-I`, and `build_rpath`. A `.so` produced in `build/src/meson/meta/` is found because the executable's rpath lists that directory. `gi-rpc-smoke.sh` can keep `BINDIR=$BUILD/src` for the programs. GI loads `libmutter-rpc-16.so` through the process rpath.

Proposed tree:

```text
src/meson.build
src/meson/compositor/meson.build      # compositor_sources, mutter_vala_args
src/meson/config/meson.build          # rpc_config, gjs_embed_config, gnome_shell_rpc_config, gjs_* deps
src/meson/gi-stub-gen/meson.build     # gi-stub-gen
src/meson/gsr-rpc/meson.build         # libgsr-rpc-16.so
src/meson/clutter/meson.build         # Clutter emit, boxed, libmutter-clutter-rpc-*.so
src/meson/meta/meson.build            # Meta emit, c-meta-shell-gaps, libmutter-rpc-*.so
src/meson/st/meson.build              # St emit, libst-rpc-*.so, gsr-st-boxed
src/meson/shell/meson.build           # libshell-*.so and the injected GIR inputs
src/meson/legacy-gi-rpc-smoke/meson.build
```

`subdir()` order:

1. `compositor` and `config` (no library dependency)
2. `gi-stub-gen`
3. `gsr-rpc`
4. `clutter` (emit, boxed, `.so`; header stage can stay in the parent)
5. `meta`
6. `st`
7. `shell`
8. parent: gresource, typelibs, pc files, `gsr-client`, `gsr-smoke`, `gsr-server`
9. `legacy-gi-rpc-smoke` last, still inside `if get_option('legacy_gi_rpc_smoke')`, covering both of today's blocks

The directory name is the name a reader sees. The file inside it is always `meson.build`.

### Option C — fragments own the programs and the typelibs too

Same folder as B, and `gsr-server` / `gsr-client` / `gsr-smoke` / the typelibs move with their libraries.

`build/src/gsr-server` becomes `build/src/meson/gsr-server/gsr-server` (or similar). Every script in the table above changes. `GSR_TYPELIB_DIR` stops working unless the typelibs are still emitted into one directory, or `Application.vala` prepends each directory in a list. That is a product change riding on a build-file tidy. The nested session is the wrong place to discover a typelib path.

### Option D — a `meson.build` beside each source tree

`src/server/meson.build`, `src/client/libmutter-clutter-rpc-16/meson.build`, `src/client/libst-rpc-16/meson.build`, `src/client/libshell-16/meson.build`, and so on. Same rules as B: one scope, outputs follow the file that declares the target, `subdir()` only downward.

This matches Meson's usual "build file next to the code" layout, and `files()` paths get shorter. It matches this file badly. `gsr-server` compiles `server/`, `shared/`, and a generated Clutter source. `gsr-client` compiles `client/` plus the gresource from `client/gresource/` plus every client `.so`. The Clutter library also compiles `client/libmutter-clutter-rpc-18/` sources. A build file inside one of those directories still reaches into the others with `../`.

`src/client/gresource/meson.build` already exists. A new `src/client/meson.build` could `subdir('gresource')`. A fragment under `src/meson/` cannot.

## Also worth moving, either way

Two pieces are in `src/meson.build` and do not belong to a client library:

- Lines 1570–1615 install `data/gsr-session`, the wayland session, the gnome-session file, the desktop file, the systemd user units, and the apport ignore file. A `data/meson.build` entered with `subdir('data')` from the root file installs the same files. `configure_file` for the apport snippet would write `build/data/gnome-shell-rpc` and install from there. Nothing looks that file up in `build/src`.
- `gtk4_dep` (line 1525) exists so the root file can link `fake-shell`. It can be declared beside `fake-shell`.

## The Shell source split is not the intended version split

The current Shell target has another build-system problem that this work must fix rather than preserve.

`shell_api_define` is not dead. For API 18, `src/meson.build` adds `--define=MUTTER_18` to the Shell target's `vala_args`. `client/libshell-16/Screenshot.vala` consumes it to select between the API 16 and API 18 `paint_to_buffer` signatures.

The target also spells out almost the entire API 16 directory inline and then adds a small API-dependent tail:

- API 16 adds `libshell-16/Signals.vala`.
- API 18 still compiles the listed `libshell-16` sources, then adds `libshell-18/EdgeDragGesture.vala` and `libshell-18/Signals.vala`.

That is not the intended use of the per-version directories. They exist to keep version differences in selected source files, not in Vala preprocessor branches, and the large inline API 16 list is not the intended source-selection boundary.

The proposed `src/meson/shell/meson.build` extraction must therefore define the Shell source sets according to the version-directory design. It must not copy the current monolithic list plus `shell_api_define` unchanged into a smaller file. In particular, remove the `MUTTER_18` compile define by moving the `Screenshot` signature difference into version-selected source, and make the version ownership of the complete Shell source set explicit in that fragment. Legacy API 16 implementations may remain whole in `libshell-16`; API 18 replacements belong in `libshell-18`.

## Recommendation

Option B. It is the cut that shortens `src/meson.build` down to an ordered contents list and the targets whose paths the session already hardcodes. Option A is the fallback if a review wants zero build-tree movement, with the open admission that the long `library()` bodies stay put. Option C moves `GSR_TYPELIB_DIR`. Option D scatters the same targets into source directories that do not match the link graph.

No implementation in this report. A later edit should `meson setup` a fresh build dir and confirm `build/src/gsr-server`, the typelibs beside it, and `PKG_CONFIG_PATH=build/src` still resolve, then run the nested prove.
