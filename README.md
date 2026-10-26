# gnome-shell-rpc

Demo of the current progress:

<video src="https://github.com/user-attachments/assets/8fd6bb3f-5274-49bd-9db4-05b9de49607d" controls width="100%"></video>

If the video does not display, [watch it here](https://github.com/user-attachments/assets/8fd6bb3f-5274-49bd-9db4-05b9de49607d).

Today, GNOME Shell and Mutter run in one process: the shell’s JavaScript calls
straight into the compositor. If the shell crashes, the whole session goes down.

This project **separates** them. Mutter keeps compositing (windows, Wayland,
the display server). GNOME Shell’s JavaScript runs in another process and talks
to Mutter over RPC — same `Meta` / Clutter / St APIs from JS’s point of view,
but calls go out-of-process instead of in-process.

The goal is a shell client you can restart without tearing down the desktop.

**Status (2026-10-19):** Shell 16 mostly works. A few minor UI details still need fixing.

---

## How it fits together

```
gsr-server (compositor)                 gsr-client (shell)
  src/server/, real libmutter            src/client/, gresource + libmutter-rpc-16
         ▲                                            │
         └──────────── libocrpc / Unix socket ────────┘
```

- **Compositor** — **`gsr-server`** in `src/server/`: mutter plugin; real Mutter.
- **Client** — **`gsr-client`** in `src/client/`: stock GJS plus our copy of shell
  JavaScript ([`docs/shell-javascript.md`](docs/shell-javascript.md)).
  **`libmutter-rpc-16`** stands in for `libmutter`.

Shared types live in `src/shared/`. Folder roles: [`src/README.md`](src/README.md).

All development uses **nested** mutter. Do **not** point this at your host `gnome-shell`, and do **not** nest under host GNOME (that may freeze  the desktop).
How to run that nest: [`docs/weston-nested-test-env.md`](docs/weston-nested-test-env.md).

---

## Documentation

| Doc | What |
| --- | ---- |
| [`docs/shell-javascript.md`](docs/shell-javascript.md) | Where the shell JavaScript comes from |
| [`docs/debugging.md`](docs/debugging.md) | **LLM instructions for a fix:** read logs, reproduce, shrink, fix the repro, then land |
| [`docs/weston-nested-test-env.md`](docs/weston-nested-test-env.md) | **Default nested prove** (Weston in X11) |
| [`docs/nested-debug.md`](docs/nested-debug.md) | Prove SIGKILL vs real death; do not gdb your own kill |
| [`docs/build.md`](docs/build.md) | Prerequisites, meson/ninja, install |
| [`docs/libmutter-rpc-for-gnome-shell-js.md`](docs/libmutter-rpc-for-gnome-shell-js.md) | Point gnome-shell JS at `libmutter-rpc` |
| [`docs/signals-client.md`](docs/signals-client.md) | Client proxy signals, class closures, and how GJS connects them |
| [`docs/signals-server.md`](docs/signals-server.md) | Server leases, subscriptions, and vfunc hooks |
| [`docs/signal-reentrancy.md`](docs/signal-reentrancy.md) | Prove signal order in the stand-alone test before editing `src/` |
| [`docs/README.md`](docs/README.md) | Docs index |

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

---

## License

gnome-shell-rpc is distributed under the terms of the GNU General Public License,
version 2 or later. See the [COPYING](COPYING) file for details.
