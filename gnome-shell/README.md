# gnome-shell integration layer

Build integration for upstream GNOME Shell. **`vendor/gnome-shell/`** is a gitignored checkout for **build / CI / reference** — we do **not** install or ship upstream JavaScript.

| Path | In git? | Role |
| --- | --- | --- |
| `vendor/gnome-shell/` | No | Upstream checkout (build-time only) |
| `gnome-shell/` (here) | Yes | Meson integration |
| `scripts/gnome-shell-fetch.sh` | Yes | Clone / refresh vendor tree |

## Runtime JavaScript

**Packages depend on distro `gnome-shell`.** **`gnome-shell-rpc`** (shell binary) loads JS from the installed gnome-shell package (e.g. `/usr/share/gnome-shell/js/`), not from `vendor/`. We ship **`libmutter-rpc`**, **`mutter-rpc`**, and **`gnome-shell-rpc`** — not upstream `js/`.

Prefer **not** to touch, override, or install upstream JS unless a later phase proves it unavoidable.

## Fetch (build / CI)

```bash
./scripts/gnome-shell-fetch.sh              # clone if missing
./scripts/gnome-shell-fetch.sh --refresh    # update for nightly / dev
./scripts/gnome-shell-fetch.sh --ref=48.0 --refresh   # pin for release build reference
```

**Default:** clone once, reuse on rebuild — no network unless refresh.

## Meson

```bash
meson setup build                                    # runtime JS dir; vendor off by default
meson setup build -Dgnome_shell_js_dir=/path/to/js  # override runtime JS path
meson setup build -Dvendor_gnome_shell=enabled -Dgnome_shell_client_libs=enabled   # legacy vendored client libs only
```

Configure prints **`gnome-shell runtime JS dir:`** (distro — not installed by us). Vendor checkout is **off by default** (`-Dvendor_gnome_shell=disabled`). **`gjs-embed`** uses the runtime path in GJS `search-path` (**`GNOME_SHELL_JS_DIR`** env overrides at run time).

**Server St (0.7.6 Phase B):** `mutter-rpc` uses **stock** `/usr/lib/gnome-shell/libst-16.so` + `St-16.typelib` — same pkglibdir as Gvc. No vendored server build.

**Legacy client libs:** `-Dgnome_shell_client_libs=enabled` + `-Dvendor_gnome_shell=enabled` builds vendored **`libst-16.so`** / **`libshell-16.so`** linked to **`libmutter-rpc-16`** under **`build/gnome-shell/client-libs/`** (superseded by Phase C St RPC stubs). Import smokes:

```bash
GI_META_SMOKE=shell-import-smoke.js dbus-run-session ./build/src/mutter-rpc --wayland --nested
```

Phase 5 (**`init.js`**) is **not** this one-liner — see [`0.7-gnome-shell-rpc-client.md`](../docs/plans/0.7-gnome-shell-rpc-client.md) Phase 5.

Plan: [`docs/plans/0.7-gnome-shell-rpc-client.md`](../docs/plans/0.7-gnome-shell-rpc-client.md).
