# Build and run (nested)

All commands assume a checkout of this repo. **Do not** use these against your live desktop session.

**Target:** distro **gnome-shell 48** / **libmutter-16** (Meta-16).

---

## Prerequisites

- **libocrpc** from a sibling OLLMchat build (`libocrpc.so` + `ocrpc.vapi` in one directory)
- **gnome-shell 48** / **libmutter-16** on the host (Ubuntu 25.04+ or Debian with mutter 48)

### Debian / Ubuntu

**Ubuntu 25.04+** (or Debian with `libmutter-16-dev`). Adjust names on other distros.

```bash
sudo apt install \
  build-essential \
  pkg-config \
  meson \
  ninja-build \
  valac \
  gobject-introspection \
  libgirepository-2.0-dev \
  libmutter-16-dev \
  gjs \
  libgjs-dev \
  libgee-0.8-dev \
  libjson-glib-dev \
  libsoup-3.0-dev \
  libgtk-4-dev \
  libpolkit-agent-1-dev \
  libgcr-4-dev \
  gnome-shell \
  dbus-x11
```

- **libmutter-16-dev** — compositor link + mutter typelibs (Clutter/Cogl/Mtk come with it)
- **gjs** / **libgjs-dev** — `gjs-embed` and smoke scripts
- **libgee-0.8-dev**, **libjson-glib-dev**, **libsoup-3.0-dev** — `libocrpc` headers at compile time
- **libgtk-4-dev** — `fake-shell` test client
- **gnome-shell** — stock **`libst-16.so`**, **`St-16.typelib`**, **`Gvc-1.0.gir`** under `/usr/lib/gnome-shell/` and `/usr/share/gnome-shell/`; runtime JS path is separate
- **libpolkit-agent-1-dev**, **libgcr-4-dev** — only if enabling legacy vendored client-lib build (`-Dgnome_shell_client_libs=enabled`)
- **dbus-x11** — `dbus-run-session` for nested compositor runs

Build OLLMchat **libocrpc** first, then pass its output directory to meson:

```bash
meson setup build -Docrpc_libdir=/path/to/OLLMchat/build/libocrpc
ninja -C build
```

Vendor checkout is **off by default** (`-Dvendor_gnome_shell=disabled`). Enable only for legacy client-lib experiments:

```bash
meson setup build -Dvendor_gnome_shell=enabled -Dgnome_shell_client_libs=enabled --reconfigure
meson setup build -Dgnome_shell_vendor_refresh=true --reconfigure   # refresh vendor pin
./scripts/gnome-shell-fetch.sh --refresh                             # same, manual
```

See [`gnome-shell/README.md`](../gnome-shell/README.md). Meson prints **`gnome-shell runtime JS dir:`** at configure (from distro layout, not vendor). Override: **`-Dgnome_shell_js_dir=…`** or runtime **`GNOME_SHELL_JS_DIR`**.

Main artifacts under `build/src/`:

| Output | Role |
| --- | --- |
| `mutter-rpc` | Compositor binary (mutter plugin) |
| `gnome-shell-rpc` | Shell client (GJS + distro gnome-shell JS path) |
| `gjs-embed` | **Temporary** test GJS host (manual smokes only) |
| `libmutter-rpc-16.so` | Client Meta stubs (RPC to plugin) |
| `Meta-16.typelib` | GI typelib → `libmutter-rpc-16.so` |
| `libst-rpc-16.so` | Client St stubs (RPC to server libst) |
| `St-16.typelib` | GI typelib → `libst-rpc-16.so` |
| `build/gnome-shell/client-libs/libst-16.so` | Legacy client St (when `-Dgnome_shell_client_libs=enabled`) |
| `build/gnome-shell/client-libs/libshell-16.so` | Client Shell C lib (same) |

Install puts St/Shell next to Meta typelibs under **`${libdir}/mutter-rpc-16/`** — never `/usr/lib/gnome-shell/`. Nested runs use the client-libs build dir via `GI_TYPELIB_PATH` / rpath.

---

## Install (optional, private prefix)

Default meson prefix is `/usr` — **prefer a user prefix** so nothing overwrites distro mutter:

```bash
meson setup build --prefix=$HOME/.local \
  -Docrpc_libdir=/path/to/OLLMchat/build/libocrpc
ninja -C build install
```

Layout after install:

- `libmutter-rpc-16.so` → `${libdir}/`
- `Meta-16.typelib` + `Meta-16.gir` → `${libdir}/mutter-rpc-16/`
- `libst-16.so` + `St-16.typelib` + `libshell-16.so` + `Shell-16.typelib` → `${libdir}/mutter-rpc-16/`
- `libmutter-rpc-16.pc` → `${libdir}/pkgconfig/` (`typelibdir` / `clientlibdir` → `${libdir}/mutter-rpc-16`)

See [`libmutter-rpc-for-gnome-shell-js.md`](libmutter-rpc-for-gnome-shell-js.md) for `GI_TYPELIB_PATH` after install.

---

## Run nested compositor

```bash
dbus-run-session ./build/src/mutter-rpc --wayland --nested
```

On startup the plugin listens on `$XDG_RUNTIME_DIR/mutter-rpc.sock` (or `MUTTER_RPC_SOCKET`) and spawns **`gnome-shell-rpc`** with **`resource:///org/gnome/shell/ui/init.js`** by default (`MUTTER_RPC_SOCKET` + `WAYLAND_DISPLAY` set on the child).

Override with a smoke script:

```bash
GI_META_SMOKE=mutter-rpc-load.js \
  dbus-run-session ./build/src/mutter-rpc --wayland --nested
```

`GI_META_SMOKE=init` is the same as the default. Other smokes live under `src/gjs-embed/` (`meta-smoke.js`, etc.). Run them manually with **`gjs-embed`** or via **`GI_META_SMOKE`** as above (compositor spawns **`gnome-shell-rpc`**, not **`gjs-embed`**).

---

## Run GJS client by hand

Useful without starting the full compositor, or to debug typelib loading:

```bash
MUTTER_TL=$(pkg-config --variable=typelibdir libmutter-16)
export GI_TYPELIB_PATH=$PWD/build/src:$MUTTER_TL${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}
export LD_LIBRARY_PATH=$PWD/build/src${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

./build/src/gnome-shell-rpc --debug src/gjs-embed/mutter-rpc-load.js
```

Or with the temporary test host:

```bash
./build/src/gjs-embed --debug src/gjs-embed/mutter-rpc-load.js
```

`mutter-rpc-load.js` checks that `Meta` resolves to `libmutter-rpc-16.so`, not distro `libmutter-16`.

For launch/minimize exercises against a running compositor, use `meta-smoke.js` (nested compositor above, or with RPC socket env if wired).

---

## Session safety

- **Do not** `meson install` to `/usr` on a machine where you rely on stock mutter.
- **Do not** prepend our typelib path on the host `/usr/bin/gnome-shell`.
- Nested work only: `dbus-run-session` + `./build/src/mutter-rpc --wayland --nested`.
