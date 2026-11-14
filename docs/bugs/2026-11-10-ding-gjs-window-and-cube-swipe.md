# Desktop Icons shows as gjs, and the cube swipe does not rotate

**Status:** Proposal ready for review. Three defects are proven by off-code gates under `tests/call-sync-repro/` and on Weston (`ding-spawn-map`). `src/` stays unchanged.

## Diagnosis and reproductions

1. **First window has `get_compositor_private() == null` and `Shell.WM::map` never runs.**
   - In mutter (`meta_compositor_add_window`), `g_object_new(MetaWindowActorWayland)` calls `meta_window_set_compositor_private` and `clutter_actor_add_child(window_group, actor)` **before** `Meta.Display::window-created` fires.
   - When the shell has subscribed to `child-added` on `window_group` or `top_window_group` (e.g. `desktop-cube` / `workspaceAnimation.js`), `OLLMrpc.Live.Subscription.emit` exports the `MetaWindowActorWayland` in a `Clutter.Actor`-typed `GLib.Value`.
   - `Server.start` only registers `OLLMrpc.Bin.register_alias("Meta-WindowActor", priv.get_type())` later inside `display.window_created` (`src/server/rpc/Server.vala:164`). On the first window, `gtype_to_alias` has no exact entry for `MetaWindowActorWayland` (nor `MetaWindowX11` when Xwayland starts), so `StreamValue.write` falls back to the declared `Clutter-Actor`. The client caches a plain `Clutter.Actor` in `client.proxies` for that lease id. Every later `Window.get_compositor_private()` (`as WindowActor`) and `Shell.WM` `Shell-WM.map` lookup (`as Meta.WindowActor`) returns `null`.
   - **Weston reproduction:** adding `globalObj.window_group.connect('child-added', () => {})` to `tests/gjs-embed/ding-spawn-map.js` and running `GI_META_SMOKE_WAIT_MS=2500 GI_META_SMOKE=ding-spawn-map ./scripts/weston-gsr-prove.sh` reproduces `ding-spawn-map: miss no-map` (`~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`: `notification method=child-added` arrives before `Window.created`, then `Shell-WM.map` calls `get_compositor_private` and drops the map).
   - **Vala gate:** `meson test -C build window-actor-child-added-alias-current window-actor-child-added-alias-fixed --verbose` (`current` fails with `got=GateActor`, `fixed` passes with `got=GateWindowActor`).
   - **Xwayland apps on the Wayland session (not an X11 session):** `gsr-server --wayland` runs a Wayland compositor only (we never support X11 sessions), and mutter's Wayland display server starts Xwayland on demand (`Using public X11 display :0`) for X11 client apps running under Wayland. When an Xwayland client maps, mutter instantiates `MetaWindowX11` and `MetaWindowActorX11` inside the Wayland compositor (core `93216` aborted at `Server.vala:172` with `duplicate register of type 'MetaWindowActorWayland'` because `window_actor_aliased` did not check `gtype_to_alias.has_key(...)`, and `meta_window_x11_get_type()` was missing from `Meta-Window` aliases).

2. **Killed first `ding.js` stays in `list_all_windows` as a zombie `gjs` window, and `get_if_exited` asserts `pid == 0` four times per launch.**
   - `meta_wayland_client_new_subprocess` creates a `socketpair` and passes the child fd to `g_subprocess_launcher_take_fd(launcher, sv[1], 3)`.
   - `Gsr.Server.Meta.WaylandClient` (`src/server/libmutter-18/WaylandClient.vala`) keeps `row.launcher` alive on the exported `WaylandClient` row and never calls `launcher.close()`. `gsr-server` holds `sv[1]` open after `proc.force_exit()` kills the first `ding.js`, so `wl_client` never gets `G_IO_HUP` and the dead client's `Meta.Window` remains in `list_all_windows` forever as an unclaimed `gjs` entry.
   - `g_subprocess_get_if_exited` in GLib asserts `pid == 0` (meaning `wait` / `wait_async` has already reaped the child). Calling `proc.get_if_exited()` on a live child inside `WaylandClient.wait` and `WaylandClient.get_if_exited` triggers the four `g_subprocess_get_if_exited: assertion 'pid == 0' failed` criticals on every launch.
   - **Vala gate:** `meson test -C build wayland-client-launcher-fd-current wayland-client-launcher-fd-fixed --verbose` (`current` fails with `hup=false criticals=2`, `fixed` passes with `hup=true criticals=0`).

3. **Desktop Cube horizontal drag on the panel / GJS subclass actors cancels immediately (`event.get_state() == 0`), and Xwayland startup during desktop drag hits the `MetaWindowActorX11` abort above.**
   - On the VM (`GI_META_SMOKE=cube-swipe/ui/init`), overview swipe works (`overview began=1 updated=13 ended=1 ws=3`), while desktop and panel drags stay at `began=0`.
   - For GJS `St.Widget` subclasses (`Main.panel`, `Main.layoutManager.overviewGroup`), `LayoutHooks.measure_event` (`src/server/libmutter-clutter-18/LayoutHooks.vala`) packs `tidduu` + scroll + device_type + time **without** `event.get_state()`, and `Actor.relay_event` / `Actor.relay_captured_event` (`src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala`) construct `Event.from_local(type, x, y, button, 0, keyval)` with `state = 0`. `desktop-cube`'s `DragGesture._handleEvent` checks `(event.get_state() & Clutter.ModifierType.BUTTON1_MASK) == 0` on every `MOTION` and cancels `State.PENDING` / `State.ACTIVE` whenever `state` is `0` (`panel captured type=5 state=0`).
   - **Vala gate:** `meson test -C build captured-event-motion-state-current captured-event-motion-state-fixed --verbose` (`current` fails with `state=0x0`, `fixed` passes with `state=0x100`).
   - On `Main.layoutManager._backgroundGroup` (plain `MetaBackgroundGroup`, delivered via `ClutterEventOverride`), `state=256` (`BUTTON1_MASK`) **was** present; the drag transitioned `0 -> 1 -> 2` (`State.ACTIVE`), grabbed the stage, and then `gsr-server` aborted at `Server.vala:172` (core `93216`) when Xwayland created a `MetaWindowActorX11` while `window_actor_aliased` only handled a single subclass. Proposal 2 fixes that abort too.

## Code proposals

Edits are **Remove** / **Replace with** / **Add** from the tree; verify surrounding context before applying.

### 1. `src/server/libmutter-16/namespace.vala` — `register_alias()`: alias `MetaWindowX11` for Xwayland apps on Wayland

**Why:** This project is Wayland-only (no X11 compositor/session support), and `gsr-server --wayland` lets mutter run Xwayland on demand (`DISPLAY=:0`) so X11 client apps still open on the Wayland desktop. Mutter backs Xwayland client windows with `MetaWindowX11`, while `Gi.register("Meta", …)` registers `MetaWindow` and `register_alias` currently aliases only `meta_window_wayland_get_type()`. Both `libmutter-16.so` and `libmutter-18.so` export `meta_window_x11_get_type`.

**Where:** `Gsr.Server.Meta` extern declarations and `register_alias()`.

**Depends on:** none.

#### Remove
```vala
	/* G_DEFINE_TYPE registers this class on the first get_type call.
	 * Gi.register maps MetaWindow only. Nested clients are MetaWindowWayland. */
	[CCode (cname = "meta_window_wayland_get_type")]
	extern GLib.Type meta_window_wayland_get_type();
```

#### Replace with
```vala
	/* G_DEFINE_TYPE registers these classes on the first get_type call.
	 * Gi.register maps MetaWindow only. Wayland sessions still host X11
	 * client apps via Xwayland, whose windows are MetaWindowX11. */
	[CCode (cname = "meta_window_wayland_get_type")]
	extern GLib.Type meta_window_wayland_get_type();

	[CCode (cname = "meta_window_x11_get_type")]
	extern GLib.Type meta_window_x11_get_type();
```

#### Remove
```vala
		OLLMrpc.Bin.register_alias("Meta-Window", meta_window_wayland_get_type());
	}
```

#### Replace with
```vala
		OLLMrpc.Bin.register_alias("Meta-Window", meta_window_wayland_get_type());
		OLLMrpc.Bin.register_alias("Meta-Window", meta_window_x11_get_type());
	}
```

### 2. `src/server/rpc/Server.vala` — `start()`: alias `MetaWindowActor` subclasses on `child_added` before `Subscription.emit`

**Why:** `meta_compositor_add_window` inserts `MetaWindowActorWayland` / `MetaWindowActorX11` into `window_group` or `top_window_group` before `display.window_created` runs. Connecting to `child_added` on those two groups at `Server.start()` ensures our handler runs before any later client `Subscription` on `child-added`, so `OLLMrpc.Bin.gtype_to_alias` already maps the concrete `MetaWindowActor` subclass (`Wayland` and `X11` independently via `has_key`) before the first wire write.

**Where:** `Gsr.Server.Rpc.Server` field `window_actor_aliased` and `start()`.

**Depends on:** none.

#### Remove
```vala
		private Gee.HashMap<global::Meta.Window, ulong> title_watch_ids =
			new Gee.HashMap<global::Meta.Window, ulong>();
		private bool window_actor_aliased = false;
```

#### Replace with
```vala
		private Gee.HashMap<global::Meta.Window, ulong> title_watch_ids =
			new Gee.HashMap<global::Meta.Window, ulong>();
```

#### Keep
```vala
			var stage = display.get_context().get_backend().get_stage();
			Gsr.Server.Clutter.register_alias(stage);
```

#### Add — Connect `child_added` on `window_group` and `top_window_group` before any client connects so `MetaWindowActor` subclasses are aliased to `Meta-WindowActor` prior to `Subscription.emit`.
```vala
			global::Clutter.Actor[] window_groups = {
				display.get_compositor().get_window_group(),
				display.get_compositor().get_top_window_group(),
			};
			foreach (var group in window_groups) {
				group.child_added.connect((actor) => {
					if (!(actor is global::Meta.WindowActor)
							|| OLLMrpc.Bin.gtype_to_alias.has_key(actor.get_type())) {
						return;
					}
					try {
						OLLMrpc.Bin.register_alias("Meta-WindowActor", actor.get_type());
					} catch (GLib.Error e) {
						GLib.error("%s", e.message);
					}
				});
			}
```

#### Remove
```vala
				if (!this.window_actor_aliased) {
					var priv = meta_window.get_compositor_private();
					if (priv != null) {
						try {
							OLLMrpc.Bin.register_alias("Meta-WindowActor",
								priv.get_type());
							this.window_actor_aliased = true;
						} catch (GLib.Error e) {
							GLib.error("%s", e.message);
						}
					}
				}
```

#### Replace with
```vala
				var priv = meta_window.get_compositor_private();
				if (priv != null && !OLLMrpc.Bin.gtype_to_alias.has_key(priv.get_type())) {
					try {
						OLLMrpc.Bin.register_alias("Meta-WindowActor", priv.get_type());
					} catch (GLib.Error e) {
						GLib.error("%s", e.message);
					}
				}
```

### 3. `src/server/libmutter-18/WaylandClient.vala` — close `SubprocessLauncher` after spawn and track exit without calling `get_if_exited()` on a live child

**Why:** `meta_wayland_client_new_subprocess` hands the child socketpair fd to `g_subprocess_launcher_take_fd`. Closing the local `SubprocessLauncher` immediately after `new global::Meta.WaylandClient.subprocess(...)` drops the compositor's duplicate of the child Wayland socket so `force_exit()` closes the Wayland connection and unmanages the window. Tracking exit via `wait_async` instead of calling `proc.get_if_exited()` before reap eliminates the `g_subprocess_get_if_exited: assertion 'pid == 0' failed` criticals.

**Where:** `Gsr.Server.Meta.WaylandClient` fields, `new_subprocess()`, `wait()`, `get_if_exited()`, and `get_exit_status()`.

**Depends on:** none.

#### Remove
```vala
		private global::Meta.WaylandClient? peer = null;
		private GLib.SubprocessLauncher? launcher = null;
		private GLib.Subprocess? subprocess = null;
```

#### Replace with
```vala
		private global::Meta.WaylandClient? peer = null;
		private GLib.Subprocess? subprocess = null;
		private bool exited = false;
```

#### Remove
```vala
			var row = new WaylandClient();
			row.launcher = new GLib.SubprocessLauncher(
				(GLib.SubprocessFlags) flags
			);
			if (cwd != null && cwd.length > 0) {
				row.launcher.set_cwd(cwd);
			}
			try {
				row.peer = new global::Meta.WaylandClient.subprocess(
					context, row.launcher, wire
				);
			} catch (GLib.Error e) {
				request.connection.reply_error(
					request, (int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e
				);
				return;
			}
			row.subprocess = row.peer.get_subprocess();
```

#### Replace with
```vala
			var row = new WaylandClient();
			var launcher = new GLib.SubprocessLauncher(
				(GLib.SubprocessFlags) flags
			);
			if (cwd != null && cwd.length > 0) {
				launcher.set_cwd(cwd);
			}
			try {
				row.peer = new global::Meta.WaylandClient.subprocess(
					context, launcher, wire
				);
			} catch (GLib.Error e) {
				launcher.close();
				request.connection.reply_error(
					request, (int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e
				);
				return;
			}
			launcher.close();
			row.subprocess = row.peer.get_subprocess();
			var spawned = row.subprocess;
			spawned.wait_async.begin(null, (obj, res) => {
				try {
					spawned.wait_async.end(res);
				} catch (GLib.Error e) {
				}
				row.exited = true;
			});
```

#### Remove
```vala
		public void wait(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED("WaylandClient.wait: no subprocess")
				);
				return;
			}
			var connection = request.connection;
			int lease_id = (int) request.lease_id;
			if (!proc.get_if_exited()) {
				proc.wait_async.begin(null, (obj, res) => {
					try {
						proc.wait_async.end(res);
					} catch (GLib.Error e) {
						GLib.warning("WaylandClient.wait: %s", e.message);
					}
					connection.write(new OLLMrpc.Notification() {
						method = "WaylandClient.exited",
						id = lease_id,
					});
				});
			}
			if (proc.get_if_exited()) {
				connection.write(new OLLMrpc.Notification() {
					method = "WaylandClient.exited",
					id = lease_id,
				});
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", true),
			});
		}

		public void get_if_exited(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("b", false),
				});
				return;
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", proc.get_if_exited()),
			});
		}

		public void get_exit_status(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			int status = 0;
			if (proc != null && proc.get_if_exited()) {
				status = proc.get_exit_status();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("i", status),
			});
		}
```

#### Replace with
```vala
		public void wait(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED("WaylandClient.wait: no subprocess")
				);
				return;
			}
			var connection = request.connection;
			var lease_id = (int) request.lease_id;
			if (this.exited) {
				connection.write(new OLLMrpc.Notification() {
					method = "WaylandClient.exited",
					id = lease_id,
				});
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("b", true),
				});
				return;
			}
			proc.wait_async.begin(null, (obj, res) => {
				try {
					proc.wait_async.end(res);
				} catch (GLib.Error e) {
					GLib.warning("wait failed: %s", e.message);
				}
				this.exited = true;
				connection.write(new OLLMrpc.Notification() {
					method = "WaylandClient.exited",
					id = lease_id,
				});
			});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", true),
			});
		}

		public void get_if_exited(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			var if_exited = proc != null && this.exited && proc.get_if_exited();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", if_exited),
			});
		}

		public void get_exit_status(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			var status = 0;
			if (proc != null && this.exited && proc.get_if_exited()) {
				status = proc.get_exit_status();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("i", status),
			});
		}
```

### 4. `src/server/libmutter-16/WaylandClient.vala` — close `SubprocessLauncher` after `spawnv` and guard `get_if_exited()` until reaped

**Why:** Same `SubprocessLauncher` fd lifetime and `g_subprocess_get_if_exited` contract on mutter 16.

**Where:** `Gsr.Server.Meta.WaylandClient` fields, `spawnv()`, `wait()`, `get_if_exited()`, and `get_exit_status()`.

**Depends on:** none.

#### Keep
```vala
		private global::Meta.WaylandClient? peer = null;
		private GLib.SubprocessLauncher? launcher = null;
		private GLib.Subprocess? subprocess = null;
```

#### Add — Track when `wait_async` has reaped `subprocess` before calling `get_if_exited()`.
```vala
		private bool exited = false;
```

#### Keep
```vala
			this.subprocess = proc;
```

#### Add — Close `launcher` after `spawnv` so the parent process drops the child Wayland socket fd, and mark `exited` when `proc` terminates.
```vala
			if (this.launcher != null) {
				this.launcher.close();
				this.launcher = null;
			}
			proc.wait_async.begin(null, (obj, res) => {
				try {
					proc.wait_async.end(res);
				} catch (GLib.Error e) {
				}
				this.exited = true;
			});
```

#### Remove
```vala
		public void wait(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.connection.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED("WaylandClient.wait: no subprocess")
				);
				return;
			}
			var connection = request.connection;
			int lease_id = (int) request.lease_id;
			if (!proc.get_if_exited()) {
				proc.wait_async.begin(null, (obj, res) => {
					try {
						proc.wait_async.end(res);
					} catch (GLib.Error e) {
						GLib.warning("WaylandClient.wait: %s", e.message);
					}
					connection.write(new OLLMrpc.Notification() {
						method = "WaylandClient.exited",
						id = lease_id,
					});
				});
			}
			if (proc.get_if_exited()) {
				connection.write(new OLLMrpc.Notification() {
					method = "WaylandClient.exited",
					id = lease_id,
				});
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", true),
			});
		}

		public void get_if_exited(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("b", false),
				});
				return;
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", proc.get_if_exited()),
			});
		}

		public void get_exit_status(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			int status = 0;
			if (proc != null && proc.get_if_exited()) {
				status = proc.get_exit_status();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("i", status),
			});
		}
```

#### Replace with
```vala
		public void wait(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.connection.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED("WaylandClient.wait: no subprocess")
				);
				return;
			}
			var connection = request.connection;
			var lease_id = (int) request.lease_id;
			if (this.exited) {
				connection.write(new OLLMrpc.Notification() {
					method = "WaylandClient.exited",
					id = lease_id,
				});
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("b", true),
				});
				return;
			}
			proc.wait_async.begin(null, (obj, res) => {
				try {
					proc.wait_async.end(res);
				} catch (GLib.Error e) {
					GLib.warning("wait failed: %s", e.message);
				}
				this.exited = true;
				connection.write(new OLLMrpc.Notification() {
					method = "WaylandClient.exited",
					id = lease_id,
				});
			});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", true),
			});
		}

		public void get_if_exited(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			var if_exited = proc != null && this.exited && proc.get_if_exited();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", if_exited),
			});
		}

		public void get_exit_status(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			var status = 0;
			if (proc != null && this.exited && proc.get_if_exited()) {
				status = proc.get_exit_status();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("i", status),
			});
		}
```

### 5. `src/server/libmutter-clutter-18/LayoutHooks.vala` — `measure_event()`: pack `event.get_state()`

**Why:** `measure_event` omits modifier/button state (`BUTTON1_MASK`, etc.), so `relay_event` and `relay_captured_event` always leave `event.get_state()` at `0` on GJS `St.Widget` subclasses (`Main.panel`, `overviewGroup`), causing `desktop-cube` `DragGesture._handleEvent` to cancel every drag on the first `MOTION`.

**Where:** `Gsr.Server.Clutter.LayoutHooks.measure_event()` before `hook.emit(fields)`.

**Depends on:** none.

#### Remove
```vala
			fields.add(OLLMrpc.val("i", device_type));
			fields.add(OLLMrpc.val("u", event.get_time()));
			hook.emit(fields);
```

#### Replace with
```vala
			fields.add(OLLMrpc.val("i", device_type));
			fields.add(OLLMrpc.val("u", event.get_time()));
			if (et != global::Clutter.EventType.SCROLL) {
				fields.add(OLLMrpc.val("u", (uint) event.get_state()));
			}
			hook.emit(fields);
```

### 6. `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` — `relay_event()` and `relay_captured_event()`: unpack `state` from `call.args`

**Why:** Read the trailing `event.get_state()` packed by `LayoutHooks.measure_event` so `ev.get_state()` preserves `BUTTON1_MASK` and keyboard modifiers during `event` and `captured-event` hooks.

**Where:** `Actor.relay_event()` and `Actor.relay_captured_event()`.

**Depends on:** ### 5.

#### Remove
```vala
			var ev = Event.from_local(type, x, y, button, 0, keyval);
			ev.read_scroll_tail(call.args, 6);
			Gsr.Client.Rpc.VfuncRelay.begin(this);
```

#### Replace with
```vala
			var state = 0u;
			if (type != EventType.scroll && call.args.size > 9) {
				state = call.args.get(9).get_uint();
			}
			var ev = Event.from_local(type, x, y, button, state, keyval);
			ev.read_scroll_tail(call.args, 6);
			Gsr.Client.Rpc.VfuncRelay.begin(this);
```

#### Remove
```vala
			var ev = Event.from_local(type, x, y, button, 0, keyval);
			ev.read_scroll_tail(call.args, 6);
			bool stop = this.signal_captured_event(ev);
```

#### Replace with
```vala
			var state = 0u;
			if (type != EventType.scroll && call.args.size > 9) {
				state = call.args.get(9).get_uint();
			}
			var ev = Event.from_local(type, x, y, button, state, keyval);
			ev.read_scroll_tail(call.args, 6);
			bool stop = this.signal_captured_event(ev);
```

## LLM efforts

- 2026-11-10 08:14. Previous session 08:06 (`gsr-client` 164273) had the same two `Launching DING process` lines, the same `title` reject, and the same `parent is null` stack from the panel overview toggle. `get_if_exited` asserted `pid == 0` on the server at each launch. The guest was then shut off.
- 2026-11-10 08:50. Started `ubuntu26.04`. New session 08:50:53. Same DING pair, same title reject, same cube stack at 08:51:25. One `ding.js` left, pid 3877.
- 2026-11-10 08:59. `GSR_NESTED_TIMEOUT=30 GI_META_SMOKE=window-title-set ./scripts/agent-nested-smoke-prove.sh`. `window-title-set: miss Property MetaWindow.title is not writable`. `stop (smoke-fail) after 1s`.
- 2026-11-10 09:00. Setter on `Window.title` in both overrides, denied in both `Meta.deny` files. `ninja -C build src/gsr-smoke`. Same smoke, `GSR_NESTED_STAYUP` still 1 from the shell: `window-title-set: ok`, then `stop (timeout) after 30s` because `window-title-set: ok` was not in the prove pattern.
- 2026-11-10 09:02. Added `window-title-set: ok` to the prove pattern. `GSR_NESTED_STAYUP=0` same smoke: `window-title-set: title=Desktop Icons 1 notified=true`, `window-title-set: ok`, `stop (smoke-ok) after 1s`.
- 2026-11-10 09:07. Copied the 18 override and `Meta.deny` to the guest checkout and built `libmutter-rpc-18.so` and `Meta-18.typelib` there. Installed both and restarted `org.gnome.ShellRpc@wayland.service`. Pids 5210 / 5232. `GNOME Shell started` at 09:08:04. No DING line and no `title` reject by 09:08:46. `column_spacing` / `layout_manager is null` still logs four times.
- 2026-11-10 09:37. User session after the title install. `gsr-server` 10236, `gsr-client` 10477. `Launching DING process` at 09:37:24 and 09:37:27. `g_subprocess_get_if_exited: assertion 'pid == 0' failed` four times at each of those stamps. `Received notification for window. 0 notifications remaining.` at 09:37:28 only. No `property 'title' … is not writable`. One `ding.js` pid 11013, started 09:37:27. `too much recursion` at 09:37:56 from `emulateX11WindowType.js:412` `_refreshWindows` → `Main.activateWindow`.
- 2026-11-10 09:53. `GSR_NESTED_STAYUP=0 GSR_NESTED_TIMEOUT=30 GI_META_SMOKE=gjs-app-skip ./scripts/agent-nested-smoke-prove.sh`. Client log `gjs-app-skip: name=GTK Demo before=2 after=2 listed=true skip=true` then `gjs-app-skip: miss name=GTK Demo after=2 listed=true`. `AppState.RUNNING` is 2. `skip_taskbar` is true and `get_running()` still contains the app.
- 2026-11-10 10:11. User stopped. Both remaining issues are open: doubled desktop icons, and one `gjs` still registered in the footer. The `Shell.App` skip-taskbar count in `src/client/libshell-16/App.vala` was not proven after the 09:53 miss and was not installed on the guest.
- 2026-11-10 14:00. This host, `/var/log/syslog`. Two GSR sessions, 12:31:14 (`gsr-client` 25571) and 12:33:08 (`gsr-client` 35452). Debug cache untouched since 2026-11-05. No gsr core. Session 1 ended on `Stopping gdm.service` at 12:32:46, peak 8.3G. Session 2 ended at 12:33:38 when the session target stopped, peak 460.6M. Stock `gnome-shell` pid 9739 dumped core at 12:31:01 (`status=6/ABRT`) before the first GSR login. Each GSR session logged one `Launching DING process` and one `Received notification`. Both logged `undefined symbol: st_icon_info_load_symbolic_async` from the two appindicator extensions. `nm -D` on the installed `libst-rpc-16.so` has `st_icon_info_load_symbolic` and `st_icon_info_load_symbolic_finish` and not `st_icon_info_load_symbolic_async`. Stock `libst-16.so` has all three.
- 2026-11-10 14:55. `timeout 5 ./build/tests/call-sync-repro/symbolic-icon-async-gate` printed `symbolic-icon-async: ok`. Copied that task pair into `src/client/libst-rpc-16/overrides/IconInfo.override.vala`. Denied `IconInfo.load_symbolic_finish` so the generated RPC finish is not linked. `ninja -C build src/client/libst-rpc-16/libst-rpc-16.so`. `nm -D` shows `T st_icon_info_load_symbolic_async`. Header is `StIconInfo*`, `StIconColors*`, `GCancellable*`, `GAsyncReadyCallback`, `gpointer`.
- 2026-11-10 14:59. `GSR_NESTED_STAYUP=0 GSR_NESTED_TIMEOUT=30 GI_META_SMOKE=gjs-app-skip ./scripts/agent-nested-smoke-prove.sh`. `gjs-app-skip: name=GTK Demo before=2 after=0 listed=false skip=true`, `gjs-app-skip: ok`, `stop (smoke-ok) after 1s`.
- 2026-11-10 15:00. `GSR_NESTED_TIMEOUT=70 GI_META_SMOKE=desktop-cube-lockup/ui/init ./scripts/agent-nested-smoke-prove.sh`. `workspaces=6 parent=[… GsrServerClutterActor.workspaces-view …]`, `desktop-cube-lockup/ui/init: ok`, `stop (smoke-ok) after 16s`.
- 2026-11-11 08:44. `GSR_NESTED_STAYUP=0 GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=ding-icons/ui/init ./scripts/agent-nested-smoke-prove.sh`. Tee log: `desktops=1`, `title=Desktop Icons 1 type=0 skip=true app=gjs state=0 listed=false`, `ding-icons/ui/init: ok`. `stop (smoke-ok) after 13s`. RPC was `Gsr-Mutter-WaylandClient.hide_from_window_list`.
- 2026-11-11 09:05. Guest login after the 09:04:55 install. `Launching DING process` at 09:05:09 and 09:05:12. Claim at 09:05:13. `ding.js` 34599. User reports both the doubled icons and the `gjs` footer are still there.
- 2026-11-11 10:24. `owns_window` on the 18 server also matches the subprocess pid. `Window.hide_from_window_list` sets `skip_taskbar` on the client after the RPC. Built on the guest. Stopped `org.gnome.ShellRpc@wayland.service` and installed `gsr-server` and `libmutter-rpc-18.so`. No login on this build yet.
- 2026-11-11 10:29. Login `gsr-server` 48927, `gsr-client` 49171. Binaries on disk are 10:29:11. `Launching DING process` at 10:29:40 and 10:29:43. Claim at 10:29:44. `ding.js` 49694 started 10:29:43. User: not fixed. The Weston `ding-icons` smoke had one launch and `listed=false`. It does not reproduce this login.
- 2026-11-12 08:22. User: do not prove this on a mutter 18 nest. Use the virtual machine. Read the still-running 10:29 session. `Shell.Eval` returns `(false, '')`. `ding.js` is not running now. Weston on this host stays mutter 16. No `src/` edit.
- 2026-11-12 09:10. VM restarts without `--debug`. First `ding.js` reaches nautilus and `show_all` (`realized=true mapped=true visible=true`, 1280×800) and never enters `get_window_actors`. Second launch maps and `owns_window` is true. A 15s and a 60s timer still never map the first window. `WAYLAND_DEBUG=1` shows the first client bind `xdg_wm_base`, `get_toplevel`, `configure(1280, 768)`, buffer attach, and `wl_callback.done`, with `get_window_actors` still empty at 2s. `window-created` fires (`type=0`). At 2s the window is in `list_all_windows` at 1280×800 maximized and `get_compositor_private()` is null. After the second claim both windows are in the list; only the new one has an actor. Height clamp to 768 does not create the actor. `unmanaged` does not fire for that window during the 3s wait. Guest DING files have temporary logs. `src/` unchanged. A gdb attach on `gsr-server` left a breakpoint and the process dumped `SIGTRAP` at 09:23:14. Service started again at 09:24, `gsr-server` 74596.
- 2026-11-12 09:55. tty3 `systemd-run` of `GI_META_SMOKE=ding-new-subprocess` on the build-tree server. Log `/tmp/ding-new-subprocess.log`: `ding.js` and a plain Gtk client both `listed=0` `miss no-owned-window`. The Gtk client log stops at `init` until flags are `NONE`, then `shown`, and the smoke still lists no window. Not the session failure. tty2 restored, user service stayed active.
- 2026-11-12 10:05. User-session extension `actor-probe@gsr` (not left enabled). A 320×200 window was not distinguishable from DING's title. A maximized 1280×800 `Probe Window` logged `t2 n=2 Probe Window actor=false | Desktop Icons 1 actor=true` and `miss no-actor`. `/tmp/ding-window-client.log` reached `shown`. `enabled-extensions` restored to apps-menu, desktop-cube, ding.
- 2026-11-13 09:05. Read VM `journalctl --user -u org.gnome.ShellRpc@wayland.service` for 08:50 and 08:55 restarts. In 08:55 (`actor-probe@gsr` enabled before DING), `Probe Window` opened first (`actor=false`) while DING's first window opened second and mapped immediately (`actor=true`, single launch). Confirmed the bug hits whichever window opens **first** in a session, not DING specifically.
- 2026-11-13 09:14. Reproduced the full DING double-launch headlessly on the VM without touching the user session: `dbus-run-session -- timeout --foreground -k 2 10 env MUTTER_RPC_SOCKET=/tmp/gsr-smoke.sock XDG_CURRENT_DESKTOP=ubuntu:GNOME NO_AT_BRIDGE=1 GIO_USE_VFS=local ./build/src/server/gsr-server --headless --virtual-monitor 1280x800 --wayland-display wayland-gsr-smoke`. Logged `DING t2 actors= all=Desktop Icons 1 1280x800 max=true/true actor=false`, `DING timeout windows=`, second launch, `DING t2 actors= all=Desktop Icons 1 1280x800 max=true/true actor=true || Desktop Icons 1 1280x800 max=true/true actor=false`.
- 2026-11-13 09:24. Traced `meta_window_set_compositor_private`, `gsr_server_plugin_real_map`, and `oll_mrpc_transport_connection_export` in gdb on that headless VM run. Both `meta_window_set_compositor_private` and `Plugin.map` **did** run on the server for Window 1! The first `export` of Window 1's `MetaWindowActorWayland` happened inside `clutter_actor_add_child` → `oll_mrpc_live_subscription_emit` (`window_group` `child-added`), **before** `Server.vala:164` (`display.window_created`) registered `Meta-WindowActor` for `MetaWindowActorWayland`. `StreamValue.write` encoded it as `Clutter-Actor`, poisoning `client.proxies` with a `Clutter.Actor` so `Window.get_compositor_private() as WindowActor` returned `null` forever.
- 2026-11-13 09:34. Proved the same race on local Weston (`mutter-16`) by adding `globalObj.window_group.connect('child-added', () => {})` to `tests/gjs-embed/ding-spawn-map.js`: `GI_META_SMOKE_WAIT_MS=2500 GI_META_SMOKE=ding-spawn-map ./scripts/weston-gsr-prove.sh` failed with `ding-spawn-map: miss no-map` (`stop (smoke-fail) after 3s`).
- 2026-11-13 09:42. Wrote two Vala gates in `tests/call-sync-repro/`: `window-actor-child-added-alias-gate` (proving `child-added` before `register_alias` yields `GateActor` and pre-aliasing on `child_added` yields `GateWindowActor`) and `wayland-client-launcher-fd-gate` (proving unclosed `SubprocessLauncher` after `take_fd` withholds `G_IO_HUP` on `force_exit` and `get_if_exited` before `wait_async` emits `pid == 0` criticals; `launcher.close()` + `wait_async` passes with `hup=true criticals=0`). `meson test -C build window-actor-child-added-alias-current window-actor-child-added-alias-fixed wayland-client-launcher-fd-current wayland-client-launcher-fd-fixed --verbose` passed (2 OK, 2 EXPECTEDFAIL).
- 2026-11-13 10:45. Ran headless `cube-swipe` probe on VM (`desktop-cube@schneegans.github.com`): overview swipe rotated (`began=1 updated=13 ended=1 ws=3`), while desktop/panel drags stayed at `began=0` — panel `captured-event` received `state=0` on `MOTION` (because `LayoutHooks.measure_event` / `Actor.relay_captured_event` omit `event.get_state()`, proven by `captured-event-motion-state-gate`), and desktop drag aborted `gsr-server` at `Server.vala:172` (core `93216`) when Xwayland created a `MetaWindowActorX11`. Wrote proposals 1–6 in this bug file; `src/` untouched.
