# gnome-shell integration layer

Build integration for upstream GNOME Shell. **`vendor/gnome-shell/`** is a gitignored checkout for **build / CI / reference** — we do **not** install or ship upstream JavaScript.

| Path | In git? | Role |
| --- | --- | --- |
| `vendor/gnome-shell/` | No | Upstream checkout (build-time only) |
| `gnome-shell/` (here) | Yes | Meson integration |
| `scripts/gnome-shell-fetch.sh` | Yes | Clone / refresh vendor tree |

## Runtime JavaScript

**Packages depend on distro `gnome-shell`.** `gnome-shell-rpc-client` loads JS from the installed gnome-shell package (e.g. `/usr/share/gnome-shell/js/`), not from `vendor/`. We ship **`libmutter-rpc`** and the client binary only.

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
meson setup build                                    # clone vendor if missing
meson setup build -Dgnome_shell_vendor_refresh=true --reconfigure   # CI / pull
meson setup build -Dvendor_gnome_shell=disabled      # smokes-only
```

Plan: [`docs/plans/0.7-gnome-shell-rpc-client.md`](../docs/plans/0.7-gnome-shell-rpc-client.md).
