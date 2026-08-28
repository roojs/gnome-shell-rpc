# Pointing GNOME Shell JS at `libmutter-rpc`

How a **gnome-shell 48** JavaScript tree loads **our** Meta (`libmutter-rpc-16`) instead of distro mutter — without renaming the GI namespace and without becoming the compositor.

Build the library first: [`build.md`](build.md).

---

## Contract

| Piece | Value |
| --- | --- |
| GI namespace / version | **`Meta` / `16`** (same as mutter) |
| Shared library in the typelib | **`libmutter-rpc-16.so`** |
| pkg-config | **`libmutter-rpc-16`** |
| Install typelib + GIR | **`${libdir}/mutter-rpc-16/`** (not stock `mutter-16/`) |

JS keeps `gi.require('Meta', '16')` / `imports.gi.versions.Meta = '16'`. Only **where** the typelib is found changes.

---

## Build-tree (nested, no install)

After [`build.md`](build.md):

```bash
MUTTER_TL=$(pkg-config --variable=typelibdir libmutter-16)
RPC_TL=$PWD/build/src

export GI_TYPELIB_PATH=$RPC_TL:$MUTTER_TL${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}
export LD_LIBRARY_PATH=$RPC_TL${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

./build/src/gjs-embed --debug src/gjs-embed/mutter-rpc-load.js
```

Stock Clutter / Cogl / Mtk typelibs stay on the path **after** ours (`$MUTTER_TL`).

---

## After `meson install` (private prefix)

See [`build.md`](build.md) for install layout. Then:

```bash
RPC_TL=$(pkg-config --variable=typelibdir libmutter-rpc-16)
RPC_GIR=$(pkg-config --variable=girdir libmutter-rpc-16)
MUTTER_TL=$(pkg-config --variable=typelibdir libmutter-16)

export GI_TYPELIB_PATH=$RPC_TL:$MUTTER_TL${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}
export GI_GIR_PATH=$RPC_GIR${GI_GIR_PATH:+:$GI_GIR_PATH}
```

| pkg-config variable | Role |
| --- | --- |
| `typelibdir` | `${libdir}/mutter-rpc-16` — `Meta-16.typelib` |
| `girdir` | same dir — `Meta-16.gir` |
| `Libs` | `-lmutter-rpc-16` |
| `Cflags` | stock mutter public `meta/*.h` |

---

## What to point at us

| Consumer | How |
| --- | --- |
| **GJS** (`js/ui`, smokes) | `GI_TYPELIB_PATH` as above; stock `gi.require('Meta', '16')` |
| **C** linking Meta | `pkg-config --libs --cflags libmutter-rpc-16` |
| **Process** | **Not** stock `/usr/bin/gnome-shell` (that process **is** the compositor). Use `gjs-embed` or a dedicated client binary — see [`build.md`](build.md). |

---

## Do not

- Put `GI_TYPELIB_PATH` on the **host** session `gnome-shell` — two Meta graphs in one address space.
- Install `Meta-16.typelib` / `Meta-16.gir` into stock mutter’s dirs or `/usr/share/gir-1.0`.
- Rename the GI namespace to `MetaRpc` — rename the **`.so`** only.
