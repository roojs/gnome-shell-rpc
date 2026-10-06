# Build and run (nested)

All commands assume a checkout of this repo. **Do not** use these against your live desktop session.

**Target:** distro **gnome-shell 48** / **libmutter-16** (Meta-16).

---

## Prerequisites

- **libocrpc 1.4.0+** from the [roojs package repository](https://roojs.github.io/repos/) (`libocrpc-dev` on Debian/Ubuntu, `libocrpc-devel` on Fedora)
- **gnome-shell 48** / **libmutter-16** on the host (Ubuntu 25.04+ or Debian with mutter 48)

### libocrpc

Same APT setup as [OLLMchat](https://github.com/roojs/OLLMchat#apt-debian--ubuntu). Suites: Debian 13 (`trixie`), Ubuntu 25.04 (`plucky`), 25.10 (`questing`), 26.04 (`resolute`).

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://roojs.github.io/repos/key.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/roojs.gpg

curl -fsSL https://roojs.github.io/repos/sources \
  | sed "s/@suite@/$(lsb_release -cs)/" \
  | sudo tee /etc/apt/sources.list.d/roojs.sources

sudo apt update
sudo apt install libocrpc-dev
```

Fedora and the rest of the repository layout: [roojs package repositories](https://roojs.github.io/repos/).

### Debian / Ubuntu

**Ubuntu 25.04+** (or Debian with `libmutter-16-dev`). Adjust names on other distros.

```bash
sudo apt install \
  build-essential \
  pkg-config \
  meson \
  ninja-build \
  cmake \
  valac \
  xsltproc \
  gobject-introspection \
  libgirepository-2.0-dev \
  libmutter-16-dev \
  gjs \
  libgjs-dev \
  libgee-0.8-dev \
  libjson-glib-dev \
  libsoup-3.0-dev \
  libgtk-4-dev \
  libnm-dev \
  libsecret-1-dev \
  libpolkit-agent-1-dev \
  libpolkit-gobject-1-dev \
  libgcr-4-dev \
  libsystemd-dev \
  gnome-shell \
  dbus-x11
```

- **cmake** — Meson probes for it while resolving dependencies (`Found CMake: NO` if it is missing)
- **xsltproc** — `meson setup` requires it; `scripts/gir-xslt-inject.sh` writes `Shell-16.injected.gir`
- **libmutter-16-dev** — compositor link + mutter typelibs (Clutter/Cogl/Mtk come with it)
- **gjs** / **libgjs-dev** — `gjs-embed` and smoke scripts
- **libgee-0.8-dev**, **libjson-glib-dev**, **libsoup-3.0-dev** — `libocrpc` headers at compile time
- **libgtk-4-dev** — `fake-shell` test client
- **libnm-dev**, **libsecret-1-dev**, **libpolkit-agent-1-dev**, **libpolkit-gobject-1-dev**, **libgcr-4-dev**, **libsystemd-dev** — `libshell-16` and `gsr-client` (NetworkAgent, keyring, polkit, gcr). The same packages are required for the legacy vendored client-lib build (`-Dgnome_shell_client_libs=enabled`)
- **gnome-shell** — stock **`libst-16.so`**, **`St-16.gir`**, **`Gvc-1.0.gir`** under `/usr/lib/gnome-shell/` and `/usr/share/gnome-shell/`. Shell JS for the client is compiled from **`vendor/gnome-shell/js`** into our gresource.
- **dbus-x11** — `dbus-run-session` for nested compositor runs

Recommended: **systemd-coredump**. The build succeeds without it. When `/usr/lib/systemd/systemd-coredump` is missing, the crash screen says core dumps are not available. With it, `coredumpctl` has the core after a shell crash. See [`nested-debug.md`](nested-debug.md).

```bash
sudo apt install systemd-coredump
```

```bash
meson setup build
ninja -C build
```

`vendor/gnome-shell/` is required at build time. `meson setup` fetches it and pins it to **48.0** when the directory is missing or is not 48.x. That `js/` tree is compiled into the client gresource (`resource:///org/gnome/shell`). It is gitignored; open that path when reading shell JavaScript. **`-Dgnome_shell_js_dir=`** or **`GNOME_SHELL_JS_DIR`** is an optional disk override. Stock **`libst-16` / St GIR** still come from distro **`gnome-shell`**.

```bash
./scripts/gnome-shell-fetch.sh                                       # once
meson setup build -Dvendor_gnome_shell=enabled                       # Meson runs fetch if missing
meson setup build -Dgnome_shell_client_libs=enabled --reconfigure    # legacy client-libs
./scripts/gnome-shell-fetch.sh --refresh                             # refresh vendor pin
```

See [`gnome-shell/README.md`](../gnome-shell/README.md). Optional disk override: **`-Dgnome_shell_js_dir=…`** or **`GNOME_SHELL_JS_DIR`**.

Main artifacts under `build/src/`:

| Output | Role |
| --- | --- |
| `gsr-server` | Compositor binary (mutter plugin) |
| `gsr-client` | Shell client (GJS + gresource compiled from `vendor/gnome-shell/js`) |
| `build/gjs-embed` | **Temporary** test GJS host (manual smokes only) |
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
meson setup build --prefix=$HOME/.local
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

**Default:** Weston-in-X11 isolation — see
[`weston-nested-test-env.md`](weston-nested-test-env.md) (why + architecture).

```bash
./scripts/weston-gsr-session.sh
./scripts/weston-gsr-session.sh --debug
```

Plain session mode starts `gsr-server --wayland --nested --no-x11` on Weston’s
XWayland (`DISPLAY=:N`, not host `:0`) with no `--debug`, no debug logs, and
no log terminal. The nested window fills Weston. `--debug` opens
`weston-terminal` inside Weston and follows the debug logs.
Prove mode still starts mutter from Weston autolaunch. Log:
`~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`.

### Host-GNOME nested (manual only — freezes host)

```bash
dbus-run-session ./build/src/gsr-server --debug --wayland --nested
```

**Emergency stop:**

```bash
pkill -9 -f 'gsr-server --wayland' ; pkill -9 -f gsr-client
pkill -9 -f 'weston.*wayland-gsr'
```

On startup the plugin listens on `$XDG_RUNTIME_DIR/mutter-rpc.sock` (or `MUTTER_RPC_SOCKET`) and spawns **`gsr-client`** with **`resource:///org/gnome/shell/ui/init.js`** by default (`MUTTER_RPC_SOCKET` + `WAYLAND_DISPLAY` set on the child).

Override with a smoke script:

```bash
GI_META_SMOKE=mutter-rpc-load.js \
  WAYLAND_DISPLAY=wayland-gsr \
  dbus-run-session ./build/src/gsr-server --wayland --nested --no-x11
```

`GI_META_SMOKE=init` is the same as the default. Other smokes live under `tests/gjs-embed/` (`meta-smoke.js`, etc.). Run them manually with **`gjs-embed`** or via **`GI_META_SMOKE`** as above (compositor spawns **`gsr-smoke`**, not **`gjs-embed`**).

---

## Run GJS client by hand

Useful without starting the full compositor, or to debug typelib loading:

```bash
MUTTER_TL=$(pkg-config --variable=typelibdir libmutter-16)
export GI_TYPELIB_PATH=$PWD/build/src:$MUTTER_TL${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}
export LD_LIBRARY_PATH=$PWD/build/src${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

./build/src/gsr-smoke --debug tests/gjs-embed/mutter-rpc-load.js
```

Or with the temporary test host:

```bash
./build/gjs-embed --debug tests/gjs-embed/mutter-rpc-load.js
```

`mutter-rpc-load.js` checks that `Meta` resolves to `libmutter-rpc-16.so`, not distro `libmutter-16`.

For launch/minimize exercises against a running compositor, use `meta-smoke.js` (nested compositor above, or with RPC socket env if wired).

---

## Session safety

- **Do not** `meson install` to `/usr` on a machine where you rely on stock mutter.
- **Do not** prepend our typelib path on the host `/usr/bin/gnome-shell`.
- Nested work: prefer **[`weston-nested-test-env.md`](weston-nested-test-env.md)**
  (`./scripts/weston-gsr-session.sh`). Do **not** nest under host GNOME for
  routine proves.

### If you nest under host GNOME anyway

That path can wedge **host** input. Keep SSH / a text VT ready:

```bash
pkill -9 gsr-server; pkill -9 gsr-client
```

Stronger isolation when even Weston-in-X11 is not enough: second VT/seat, or a
VM (see the trade-off table in [`weston-nested-test-env.md`](weston-nested-test-env.md)).

