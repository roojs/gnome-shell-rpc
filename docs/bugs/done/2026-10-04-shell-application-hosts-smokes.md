# Shell boot hosts the smokes

**Status:** ✅ closed 2026-10-07. User: assume fixed.

**Plan:** [`../plans/done/1.2.4-shell-boot.md`](../plans/done/1.2.4-shell-boot.md) is archived.

Separate from [`2026-10-04-terminal-launch-slow.md`](2026-10-04-terminal-launch-slow.md) and [`2026-10-04-greeter-crash-screen.md`](2026-10-04-greeter-crash-screen.md). Those are failures seen through this boot. This bug is the boot itself.

## What the shell boot is

A product start does this, in order:

1. `--debug`, `--debug-critical`, `--disable-extensions`.
2. Typelib search path, then `require` `Gsr`, `Clutter`, `Shell`.
3. `Gsr.Client.Rpc.register()` and `Shell.Global.bind_display`.
4. `apply_extension_policy()` (temporary; [`../plans/done/1.2.1-teardown-followups.md`](../plans/done/1.2.1-teardown-followups.md)).
5. Eval `resource:///org/gnome/shell-rpc/signals.js` (connect wrap, 0.8.6).
6. `Server-Bootstrap.begin_shell_startup`.
7. Eval `resource:///org/gnome/shell/ui/init.js` as a module.
8. Eval `resource:///org/gnome/shell-rpc/restart.js` (Alt+F2 `r`, [`../plans/done/1.2.2-x11-manual-restart.md`](../plans/done/1.2.2-x11-manual-restart.md)).

`Gsr.Server.Rpc.SpawnClient.spawn_client` (`src/server/rpc/SpawnClient.vala`) spawns that binary as `gsr-client`. `Server.start` calls it. With no `GI_META_SMOKE`, the argv is the binary plus `--debug` / `--disable-extensions`. `resolve_script` then picks the init resource.

## What got bolted on

The same `command_line` also hosts every nested smoke and several debug probes. Each one added a branch, and the product steps above are now gated on path sniffing so a smoke does not run them.

| Knob | Where | What it does in the shell binary |
| --- | --- | --- |
| `SCRIPT.js` argument | `resolve_script` | Any path instead of the init resource. `gi-rpc-smoke.sh` passes one. |
| `GI_META_SMOKE` | `SpawnClient.spawn_client` | Appends `tests/gjs-embed/<name>.js` to the `gsr-client` argv. `init` means the product script. |
| `GI_RPC_GJS_EMBED_DIR` | search path | `gi-rpc-smoke.sh` always exports `src/gjs-embed` (the old tree; files now live in `tests/gjs-embed/`). |
| `GI_RPC_REGISTER_CLASS_TRACE` | preload | Evals `register-class-trace-preload.js` before init. Errors if the embed dir is unset. |
| `GI_RPC_LAUNCH_PROBE` | preload | Evals `app-launch-click-probe-preload.js` before init. Same embed-dir check. |
| `GI_RPC_JS_OVERRIDE_DIR` | `install_js_override_overlay` | Walks a sparse tree, writes a temp gresource, runs `glib-compile-resources`, registers it over `resource:///org/gnome/shell`. About 140 lines. |
| `GNOME_SHELL_JS_DIR` | search path and `resolve_script` | Boot `ui/init.js` from a disk tree instead of the resource. |

The eval itself sniffs the path:

```64:71:src/client/SmokeApplication.vala
			if (script.has_prefix("resource://")
				|| script.contains("/ui/init.js")
				|| script.contains("/gjs-embed/")) {
				ctx.eval_module_file(script, out module_status);
				status = module_status;
			} else {
				ctx.eval_file(script, out status);
			}
```

`begin_shell_startup`, both preloads, and `restart.js` run only when the script is the init resource or the path ends in `/ui/init.js`. That test exists so a smoke file does not look like a shell start.

`tests/gjs-embed/Application.vala` is already a second `GLib.Application` (`gjs-embed`). It evals `SCRIPT.js` and does not register RPC, bind the display, install the connect wrap, or start the shell. Smokes that need the compositor therefore go through `gsr-client`, which is why the probes landed in `Application`. They now live on `SmokeApplication`.
