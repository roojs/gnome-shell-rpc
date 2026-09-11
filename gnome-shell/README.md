# gnome-shell integration layer

Build integration for upstream GNOME Shell. **`vendor/gnome-shell/`** is a gitignored checkout for **build / CI / reference** — we do **not** install or ship upstream JavaScript.

| Path | In git? | Role |
| --- | --- | --- |
| `vendor/gnome-shell/` | No | Upstream checkout (build-time only) |
| `gnome-shell/` (here) | Yes | Meson integration |
| `scripts/gnome-shell-fetch.sh` | Yes | Clone / refresh vendor tree |

## Runtime JavaScript

**Prefer distro** `/usr/share/gnome-shell/js` when present. If that tree is missing, configure **falls back to `vendor/gnome-shell/js`** (dev machines without a full gnome-shell JS install). Override with **`-Dgnome_shell_js_dir=`** or runtime **`GNOME_SHELL_JS_DIR`**. We still do **not** install or ship upstream JS from vendor into packages.

Stock **`libst-16.so`** (server link) and **`St-16.gir`** (schema for client stubs) must exist under `/usr/lib/gnome-shell` and `/usr/share/gnome-shell` — if not, **`meson setup` errors** with `sudo apt install gnome-shell`. Distro **St typelib is not** what the RPC client loads; that is **`build/src/St-16.typelib` → `libst-rpc-16.so`**.

## Fetch (build / CI)

```bash
./scripts/gnome-shell-fetch.sh              # clone if missing
./scripts/gnome-shell-fetch.sh --refresh    # update for nightly / dev
./scripts/gnome-shell-fetch.sh --ref=48.0 --refresh   # pin for release build reference
```

**Default:** clone once, reuse on rebuild — no network unless refresh.

## Meson

```bash
./scripts/gnome-shell-fetch.sh                       # optional — meson also pins 48.0 if needed
meson setup build                                    # auto-detects / re-pins vendor to 48.x
meson setup build -Dgnome_shell_js_dir=/path/to/js  # override runtime JS path
meson setup build -Dvendor_gnome_shell=enabled -Dgnome_shell_client_libs=enabled   # + legacy client libs
```

Configure prints **`gnome-shell vendor root:`** (must be **version 48.x**). Stale `head` / 51.rc checkouts are **re-pinned to 48.0 automatically** on setup (network once). No `-Dgnome_shell_vendor_ref` needed. **`gjs-embed`** uses the runtime path in GJS `search-path` (**`GNOME_SHELL_JS_DIR`** env overrides at run time).

**Server St (0.7.6 Phase B):** `mutter-rpc` uses **stock** `/usr/lib/gnome-shell/libst-16.so` + `St-16.typelib` — same pkglibdir as Gvc. No vendored server build.

**Legacy client libs:** `-Dgnome_shell_client_libs=enabled` + `-Dvendor_gnome_shell=enabled` builds vendored **`libst-16.so`** / **`libshell-16.so`** linked to **`libmutter-rpc-16`** under **`build/gnome-shell/client-libs/`** (superseded by Phase C St RPC stubs). Import smokes:

```bash
GI_META_SMOKE=shell-import-smoke.js dbus-run-session ./build/src/mutter-rpc --wayland --nested
```

Phase 5 (**`init.js`**) is **not** this one-liner — see archived [`0.7-gnome-shell-rpc-client.md`](../docs/plans/done/0.7-gnome-shell-rpc-client.md) Phase 5.

Active plan: [`docs/plans/0.8-init-complete-and-interaction.md`](../docs/plans/0.8-init-complete-and-interaction.md) · index [`docs/plans/README.md`](../docs/plans/README.md).
