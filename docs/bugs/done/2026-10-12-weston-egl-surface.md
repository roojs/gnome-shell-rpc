# Weston session dies creating the EGL surface

**Status:** ✅ closed 2026-10-12. Signed off. The session starts. GL at 1280×800 still logs `failed to create egl surface`; the script retries with `--use-pixman` and the output comes up.

**Cause:** Weston 14.0.1 on this GT 1030 fails `failed to create egl surface` at 1280×800. The same size with `--use-pixman` enables `screen0`. Smaller GL sizes also enable it. Bare Weston fails the same way.

**Fix:** Unset `GSR_WESTON_PIXMAN` tries GL and, on that EGL line, restarts the session with `--use-pixman`. `GSR_WESTON_PIXMAN=0` stays fail-fast. `GSR_WESTON_PIXMAN=1` skips GL.

**Proof:** `timeout --foreground -k 2 16 ./scripts/weston-gsr-session.sh --debug` on 2026-10-12 11:36 HKT. `retrying with --use-pixman`, `Using Pixman renderer`, `Output 'screen0' enabled` at 1280×800, autolaunch reached `weston-terminal pid=991893 xdisplay=:1`.

`weston --backend=x11-backend.so --width=1280 --height=800` (no config) exits with `failed to create egl surface`. The same command at 800×480 and at 1024×400 enables `screen0`. `--use-pixman` at 1280×800 enables `screen0`. Host: Weston 14.0.1, NVIDIA GeForce GT 1030 / 570.195.03, `DISPLAY=:0`, X screen 5120×2160, about 190MB of 2048MB VRAM free. `scripts/weston-gsr-session.sh` last changed in `305d443` (2026-10-08), which only added opt-in `GSR_WESTON_PIXMAN=1`. Default size has been 1280×800 since the script was added. The 2026-10-09 prove log did start a nest, so this GL size limit showed up after that.

Unset `GSR_WESTON_PIXMAN` now tries GL and, on that EGL line, restarts the same session with `--use-pixman`. `GSR_WESTON_PIXMAN=0` keeps the old fail-fast. `GSR_WESTON_PIXMAN=1` skips GL.

Weston log:

```
Using rendering device: /dev/dri/renderD129
Chosen EGL config details: id:  40 rgba: 8 8 8 0 buf: 24 dep:  0 stcl: 0 int: 0-8 type: win|pix|pbf vis_id: 0x2b
failed to create egl surface
Enabling output "screen0" failed.
```

Command line from that run:

```
weston --backend=x11-backend.so --width=1280 --height=800 --socket=wayland-gsr --config=/run/user/1001/gsr-weston-983498/weston-gsr.ini
```

`scripts/weston-gsr-session.sh` has not changed since 2026-10-08 (`305d443`), which only added the opt-in `GSR_WESTON_PIXMAN=1`. The last prove log (`~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`, 2026-10-09 15:53) is from a nest that did start. Weston itself was installed 2026-09-11 (`14.0.1-3`) and has not been upgraded. This failure is the parent compositor, before autolaunch.

## Reproduction

```bash
timeout --foreground -k 2 20 ./scripts/weston-gsr-session.sh --debug
```

Failure line: `failed to create egl surface`.

## LLM efforts

### 2026-10-12 logs

`~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log` ends 2026-10-09 15:53 with `slider-grab-smoke: miss` and `stop (smoke-fail)`. That nest did start. No EGL line in that log (Weston's own stderr). Weston package `14.0.1-3` installed 2026-09-11, not upgraded since. `scripts/weston-gsr-session.sh` last changed in `305d443` (pixman opt-in only). Default size 1280×800 since the script was added.

### 2026-10-12 reproduce

`weston --backend=x11-backend.so --width=1280 --height=800` with and without the session ini: `failed to create egl surface`, exit 1. Same command at 640×480, 800×480, and 1024×400: `Output 'screen0' enabled`. 900×480, 800×600, 1280×400, 1280×800: EGL surface fails. `weston --use-pixman --width=1280 --height=800`: `Output 'screen0' enabled`. Host screen `5120x2160`, GPU GT 1030, 1858/2048 MiB in use.

### 2026-10-12 land

`scripts/weston-gsr-session.sh`: unset `GSR_WESTON_PIXMAN` tries GL, and on `failed to create egl surface` execs the same session with `--use-pixman`. First retry died with `exec: weston_cmd: not found` (exec of a shell function). Second run, 11:36, stayed up: pixman output enabled, Xwayland `:1`, weston-terminal launched. Timeout ended the nest.

### 2026-10-12 signed off

User closed this with the startup-frame bug. Session starts via the pixman retry.
