# gnome-shell-rpc

Today, GNOME Shell and Mutter run in one process: the shell’s JavaScript calls
straight into the compositor. If the shell crashes, the whole session goes down.

This project **separates** them. Mutter keeps compositing (windows, Wayland,
the display server). GNOME Shell’s JavaScript runs in another process and talks
to Mutter over RPC — same `Meta` / Clutter / St APIs from JS’s point of view,
but calls go out-of-process instead of in-process.

The goal is a shell client you can restart without tearing down the desktop.

**Status (2026-09-14):** nested stack **builds and boots** on **gnome-shell 48**
/ **libmutter-16**. Thin host + `init.js` corridor through **READY** / prepare
is green. Nest still **dies after READY** while extensions load (current:
second `Helper-ThemeContext.set_theme`). Active work:
[`docs/plans/0.8-init-complete-and-interaction.md`](docs/plans/0.8-init-complete-and-interaction.md).

---

## How it fits together

```
mutter-rpc (compositor)                 gnome-shell-rpc (shell)
  real libmutter                             distro gnome-shell js/ + libmutter-rpc-16
         ▲                                            │
         └──────────── libocrpc / Unix socket ────────┘
```

- **Compositor** — **`mutter-rpc`**: mutter plugin in this repo; real Mutter.
- **Client** — **`gnome-shell-rpc`**: stock GJS + distro gnome-shell JS;
  **`libmutter-rpc-16`** stands in for `libmutter`. We do **not** ship upstream `js/`.
- **`vendor/gnome-shell/`** — build/CI reference only (gitignored); not installed.

All development uses **nested** mutter. Do **not** point this at your host
`gnome-shell`, and do **not** nest under host GNOME (that freezes the desktop).

---

## Nested testing (Weston)

**Default prove env:** Mutter runs `--wayland --nested` **inside Weston**, and
Weston itself is an **X11 window** on your desktop. Close the Weston window to
throw the prove away; host GNOME stays usable.

```bash
# Interactive nest (Weston window; holds until you close it — real stay-up look)
./scripts/weston-gsr-session.sh

# Timed score / agent prove (~25s nest, 10s settle after READY)
./scripts/weston-gsr-prove.sh

# Stay-up timed prove (no READY/A4 early SIGKILL — runs to nest timeout)
GSR_NESTED_STAYUP=1 ./scripts/weston-gsr-prove.sh
```

| Script | Role |
| ------ | ---- |
| `scripts/weston-gsr-session.sh` | Weston (X11) + nested prove via `[autolaunch]` |
| `scripts/weston-gsr-prove.sh` | Timed prove for scoring / agents |
| `scripts/nested-weston-prove.sh` | `dbus-run-session` + `mutter-rpc --nested` (inside Weston) |

Prove log: `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`  
Debug: `~/.cache/gnome-shell-rpc/{mutter-rpc,org.gnome.ShellRpc}.debug.log`

Why Weston-in-X11 (and why not host GNOME):
[`docs/weston-nested-test-env.md`](docs/weston-nested-test-env.md).  
Prove SIGKILL vs real death / gdb: [`docs/nested-debug.md`](docs/nested-debug.md).  
Build / install / older `dbus-run-session` notes: [`docs/build.md`](docs/build.md).

```bash
# Stop a stuck nest
pkill -9 -f 'mutter-rpc --wayland'
pkill -9 -f gnome-shell-rpc
pkill -9 -f 'weston.*wayland-gsr'
```

---

## Where we are

| Area | Status |
| ---- | ------ |
| Plugin + RPC + nested boot | Working (Weston nest) |
| Thin host + `init.js` → READY / A4 prepare | ✔️ |
| Stay-up after READY (extensions / `set_theme`) | ⏳ — see plan 0.8 |
| `WaylandClient.spawnv` argv (`string[]` / Ffi `"S"`) | ✔️ gated |
| Phase B key / panel click smokes | B1/B3 ✔️ (short proves) |
| Generated Meta stubs (`gi-stub-gen`) | Gaps **0** (deny/override gated) |
| Client library `libmutter-rpc-16` | Built; install under `…/mutter-rpc-16/` |

---

## Documentation

| Doc | What |
| --- | ---- |
| [`docs/weston-nested-test-env.md`](docs/weston-nested-test-env.md) | **Default nested prove** (Weston in X11) |
| [`docs/build.md`](docs/build.md) | Prerequisites, meson/ninja, install |
| [`docs/libmutter-rpc-for-gnome-shell-js.md`](docs/libmutter-rpc-for-gnome-shell-js.md) | Point gnome-shell JS at `libmutter-rpc` |
| [`docs/README.md`](docs/README.md) | Docs index + agent plans |
| [`docs/plans/0.8-init-complete-and-interaction.md`](docs/plans/0.8-init-complete-and-interaction.md) | Active plan (stay-up → interaction) |

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
