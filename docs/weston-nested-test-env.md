# Weston nested test environment

> # ⚠️⚠️⚠️ AGENTS — READ THIS FIRST ⚠️⚠️⚠️
>
> ## DO NOT STOP for “status theatre”
>
> **Keep working.** Do not pause to narrate progress, summarize what you tried,
> or ask whether to continue after every prove / dead end / rebuild. Prove with
> `./scripts/weston-gsr-prove.sh` (**5s** nest — do not raise). Stop only for
> real user help or a FAIL-backed OPC bug. See
> `.cursor/rules/no-status-theatre.mdc`.

**Default prove environment** for `mutter-rpc --wayland --nested`: run Mutter
inside a **Weston** compositor that itself lives in an **X11 window** on your
desktop. One command: `./scripts/weston-gsr-session.sh`.

This keeps the product path (`--wayland --nested`) while stopping the nested
compositor from wedging **host GNOME Shell**.

---

## Why not nest under host GNOME?

`mutter-rpc --wayland --nested` makes Mutter a client of whatever parent
session it attaches to.

| Parent | What happens |
|--------|----------------|
| **Host GNOME** (`wayland-0` / `DISPLAY=:0`) | Nested hangs, grabs, or protocol storms often freeze **host** input. Same session stack you work in. |
| **Weston in an X11 window** | Parent is a disposable compositor. Kill/close the Weston window; GNOME keeps running. |

Same-user `dbus-run-session … --nested` on the host, or `machinectl` into
another user **still under host GNOME**, does **not** fix that: the nested
client is still talking to the host Shell.

---

## Why this setup is a good test environment

1. **Real product flags** — Still `mutter-rpc --wayland --nested --no-x11`, not
   a fake `--x11` / headless substitute. Layout, RPC, and shell boot stay on
   the path we care about.
2. **Host stays usable** — Weston is the parent Wayland compositor. Your GNOME
   session is only the X11 host that shows Weston’s window.
3. **One window to throw away** — Close Weston (or kill that process tree) and
   the prove is gone. No VT dance required for the common case.
4. **Agent-friendly** — `[autolaunch]` starts the prove inside the nest. No
   drop-file watcher loop for the normal path.
5. **Clear display boundaries** — Easy to assert we nested in the right place
   (`DISPLAY=:1` XWayland under Weston, not host `:0`).

Trade-off: parent compositor is Weston, not GNOME. That is intentional for
isolation. When you need “nested under GNOME specifically,” use a VM or accept
host-freeze risk (see [`build.md`](build.md) Session safety).

---

## Architecture

```
Host GNOME (wayland-0)          ← do not nest here
    │
    └── X11 :0
          │
          └── Weston (x11-backend)     socket: wayland-gsr
                │
                ├── XWayland :1        ← Mutter nested window (MetaBackendX11Nested)
                │
                └── [autolaunch]
                      └── nested-weston-prove.sh
                            └── mutter-rpc --wayland --nested --no-x11
                                  DISPLAY=:1
                                  --wayland-display=wayland-mutter-gsr
                                  └── gnome-shell-rpc (RPC client)
```

### Who owns which display

| Name | Role |
|------|------|
| Host `DISPLAY=:0` / `wayland-0` | Your desktop. **Not** Mutter’s parent. |
| `wayland-gsr` | Weston’s Wayland socket. |
| Weston XWayland `DISPLAY=:N` (often `:1`) | X11 display **inside** Weston. Mutter nested **must** use this. |
| `wayland-mutter-gsr` | Mutter’s own Wayland socket for `gnome-shell-rpc` / clients. Must not collide with `wayland-gsr`. |

Mutter’s nested backend is **`MetaBackendX11Nested`**: the nested *window* is
an X11 client. Pointing it at host `:0` puts the prove on your desktop (and
back under GNOME’s thumb). Weston’s `xwayland=true` plus autolaunch’s
`DISPLAY` is what keeps the window inside the nest.

---

## How to run

```bash
./scripts/weston-gsr-session.sh
```

Scripts:

| Script | Role |
|--------|------|
| `scripts/weston-gsr-session.sh` | Starts Weston (X11 window) with generated ini |
| `scripts/weston-gsr.ini.in` | Template: XWayland + `[autolaunch]` |
| `scripts/weston-gsr-autolaunch.sh` | Inside Weston → prove |
| `scripts/nested-weston-prove.sh` | `dbus-run-session` + `mutter-rpc … --nested` |

Prove log: `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`.

Stop: close the Weston window, or:

```bash
pkill -9 -f 'mutter-rpc --wayland'
pkill -9 -f gnome-shell-rpc
# then close Weston, or:
pkill -9 -f 'weston.*wayland-gsr'
```

Build/run details and smoke overrides: [`build.md`](build.md).

---

## Quick health checks

After session start:

```bash
# Weston up
ls -l "$XDG_RUNTIME_DIR/wayland-gsr"

# Mutter inside nest (expect DISPLAY=:1 or similar — not :0)
tr '\0' '\n' < /proc/$(pgrep -n -x mutter-rpc)/environ \
  | grep -E '^(DISPLAY|WAYLAND_DISPLAY)='
```

Expect something like `DISPLAY=:1` and `WAYLAND_DISPLAY=wayland-mutter-gsr`.

---

## What this does *not* replace

- Full DRM/seat sessions (second VT, dedicated hardware).
- VM isolation when you need the host desktop guaranteed no matter what.
- Proving “behaves as a client of GNOME Shell specifically” — that still
  means nesting under GNOME (freeze risk) or a GNOME-in-VM setup.
