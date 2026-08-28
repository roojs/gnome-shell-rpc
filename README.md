# gnome-shell-rpc

Today, GNOME Shell and Mutter run in one process: the shell’s JavaScript calls straight into the compositor. If the shell crashes, the whole session goes down.

This project **separates** them. Mutter keeps compositing (windows, Wayland, the display server). GNOME Shell’s JavaScript runs in another process and talks to Mutter over RPC — same `Meta` API from JS’s point of view, but calls go out-of-process instead of in-process.

The goal is a shell client you can restart without tearing down the desktop.

**Status:** core stack **builds and runs nested** on **gnome-shell 48** / **libmutter-16**. Remaining work is packaging a full shell client process — not proving the split. Still **not** for your live session until that lands.

---

## How it fits together

```
mutter-rpc (compositor)                 gnome-shell-rpc (shell)
  real libmutter                             distro gnome-shell js/ + libmutter-rpc-16
         ▲                                            │
         └──────────── libocrpc / Unix socket ────────┘

today (test phase): manual smokes via `gjs-embed` — compositor spawns `gnome-shell-rpc`
```

- **Compositor side** — **`mutter-rpc`**: mutter **plugin** in this repo; real Mutter, real windows.
- **Client side** — **`gnome-shell-rpc`**: stock GJS + **distro gnome-shell JS** (`Depends: gnome-shell` in packages); **`libmutter-rpc-16`** stands in for `libmutter`. We do **not** ship upstream `js/`.
- **`vendor/gnome-shell/`** — build/CI reference only (gitignored); not installed.

All development uses **nested** mutter inside `dbus-run-session`. Do not point this at your host `gnome-shell`.

---

## Where we are

| Area | Status |
| --- | --- |
| Plugin + RPC + window ops | Working nested |
| Generated Meta stubs (`gi-stub-gen`) | Gaps **0** |
| Client library `libmutter-rpc-16` | Built; install under `…/mutter-rpc-16/` |
| GJS loads our Meta (not distro mutter) | Proven nested |
| Shell client `gnome-shell-rpc` + nested spawn | Working (smoke scripts) |

---

## Documentation

| Doc | What |
| --- | --- |
| [`docs/build.md`](docs/build.md) | Prerequisites, meson/ninja, nested run |
| [`docs/libmutter-rpc-for-gnome-shell-js.md`](docs/libmutter-rpc-for-gnome-shell-js.md) | Point gnome-shell JS at `libmutter-rpc` |
| [`docs/README.md`](docs/README.md) | Index (includes agent plans under `docs/plans/`) |

RPC wire format lives in OLLMchat **libocrpc**.

---

## Artificial intelligence usage

This project was developed with the assistance of artificial intelligence.

- Architecture and design direction are human-led
- AI’s main role was writing implementation for review
- Most of the coding was performed by AI
- Changes were reviewed, revised, and approved before landing
- Application code is treated as author-approved; generated Meta stubs are gated by deny lists, overrides, and a zero-gap scoreboard

Limited exceptions apply mainly to build scaffolding.
