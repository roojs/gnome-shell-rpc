namespace GnomeShellRpc.Rpc
{
	/**
	 * RPC server boot — socket, registrations, display/window notifications,
	 * then spawn {@code gnome-shell-rpc} (default {@code init.js}; no pid watch).
	 *
	 * == Example ==
	 *
	 * {{{
	 * new GnomeShellRpc.Rpc.Server().start(meta_display);
	 * }}}
	 */
	public class Server : GLib.Object
	{
		public Meta.Display display { get; private set; }
		public Listen listen { get; private set; }
		public Ui.Display ui_display { get; private set; }

		private Gee.HashMap<Meta.Window, ulong> title_watch_ids =
			new Gee.HashMap<Meta.Window, ulong>();
		private Meta.WaylandClient? smoke_client = null;
		private bool window_actor_aliased = false;
		private string rpc_socket_path = "";

		public void start(Meta.Display display)
		{
			this.display = display;
			OLLMrpc.rpc_register(true);
			Shared.Rectangle.rpc_register();
			Ui.Window.rpc_register();
			Ui.Workspace.rpc_register();
			Ui.Display.rpc_register();
			Ui.Compositor.rpc_register();
			Rpc.Daemon.rpc_register();
			Rpc.Bootstrap.rpc_register();

			Rpc.CancellableBridge.register();
			Rpc.Helper.rpc_register();
			Rpc.Helper.Settings.bind(display);
			Rpc.Helper.GLSLEffect.bind(display);

			this.ui_display = new Ui.Display(display);
			OLLMrpc.Request.register("RPC-Daemon", new Daemon());
			OLLMrpc.Request.register_live("Meta-Display", this.ui_display);
			OLLMrpc.Request.register_live("Meta-Compositor",
				new Ui.Compositor(display.get_compositor()));

			GI.Repository.prepend_search_path(MUTTER_TYPELIB_DIR);
			GI.Repository.prepend_search_path(GNOME_SHELL_PKGLIBDIR);
			OLLMrpc.Gi.register("Meta", "16");
			OLLMrpc.Gi.register("Clutter", "16");
			OLLMrpc.Gi.register("St", "16");
			OLLMrpc.Bin.register_alias("Meta-Compositor",
				display.get_compositor().get_type());
			OLLMrpc.Bin.register_alias("Meta-Context",
				display.get_context().get_type());
			OLLMrpc.Bin.register_alias("Meta-Backend",
				display.get_context().get_backend().get_type());
			var sn = display.get_startup_notification();
			if (sn != null) {
				this.alias_live("Meta-StartupNotification", sn.get_type());
			}
			var player = display.get_sound_player();
			if (player != null) {
				this.alias_live("Meta-SoundPlayer", player.get_type());
			}
			var idle = display.get_context().get_backend()
				.get_core_idle_monitor();
			if (idle != null) {
				this.alias_live("Meta-IdleMonitor", idle.get_type());
			}
			var stage = display.get_context().get_backend().get_stage();
			if (stage != null) {
				this.alias_live("Clutter-Stage", stage.get_type());
				var ctx = stage.get_context();
				if (ctx != null) {
					this.alias_live("Clutter-Context", ctx.get_type());
					var clutter_backend = ctx.get_backend();
					if (clutter_backend != null) {
						this.alias_live(
							"Clutter-Backend", clutter_backend.get_type());
					}
				}
			}
			GLib.debug("Gi.register Meta-16 ok (%u types)",
				OLLMrpc.Gi.types != null ? OLLMrpc.Gi.types.size : 0);

			var bootstrap = Bootstrap.bind(this.display);
			OLLMrpc.Request.register("RPC-Bootstrap", bootstrap);

			var socket_path = GLib.Environment.get_variable("MUTTER_RPC_SOCKET");
			if (socket_path == null || socket_path.length == 0) {
				var runtime = GLib.Environment.get_variable("XDG_RUNTIME_DIR");
				if (runtime != null && runtime.length > 0) {
					socket_path = GLib.Path.build_filename(runtime, "mutter-rpc.sock");
				} else {
					socket_path = "/tmp/mutter-rpc.sock";
				}
			}

			this.rpc_socket_path = socket_path;

			this.listen = new Listen(socket_path) {
				live_handles = true,
			};
			if (!this.listen.start()) {
				GLib.error("failed to start RPC listener on %s", socket_path);
			}
			GLib.debug("listening on %s", socket_path);
			this.spawn_client();

			display.window_created.connect((meta_window) => {
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
				var frame = meta_window.get_frame_rect();
				GLib.debug("window_created title=%s frame=%d,%d %dx%d minimized=%s",
					meta_window.get_title(), frame.x, frame.y, frame.width,
					frame.height, meta_window.minimized.to_string());
				this.track_window(meta_window);
				if (this.listen == null) {
					return;
				}
				foreach (var connection in this.listen.connections) {
					var handle = (int)connection.export(meta_window);
					connection.write(new OLLMrpc.Notification() {
						method = "Window.created",
						object_type = "Window",
						id = handle,
					});
				}
			});

			foreach (unowned Meta.Window win in display.list_all_windows()) {
				if (win == null) {
					continue;
				}
				this.track_window(win);
			}
		}

		/**
		 * Spawn {@code gnome-shell-rpc} via {@link Meta.WaylandClient}.
		 *
		 * Default (no {@code GI_META_SMOKE}, or {@code init}): product
		 * {@code init.js} resource. Otherwise a {@code src/gjs-embed/} smoke.
		 * Sets {@code MUTTER_RPC_SOCKET} and {@code WAYLAND_DISPLAY}.
		 */
		private void spawn_client()
		{
			string self_exe;
			try {
				self_exe = GLib.FileUtils.read_link("/proc/self/exe");
			} catch (GLib.Error e) {
				GLib.warning("client spawn: %s", e.message);
				return;
			}
			var bindir = GLib.Path.get_dirname(self_exe);
			var shell_bin = GLib.Path.build_filename(bindir, "gnome-shell-rpc");
			if (!GLib.FileUtils.test(shell_bin, GLib.FileTest.IS_EXECUTABLE)) {
				shell_bin = GLib.Path.build_filename(
					bindir, "..", "gnome-shell", "client-libs", "gnome-shell-rpc");
			}
			if (!GLib.FileUtils.test(shell_bin, GLib.FileTest.IS_EXECUTABLE)) {
				GLib.warning("gnome-shell-rpc missing at %s — skip client spawn", shell_bin);
				return;
			}

			var smoke_env = GLib.Environment.get_variable("GI_META_SMOKE");
			var use_init = smoke_env == null
				|| smoke_env.length == 0
				|| smoke_env == "init"
				|| smoke_env == "init.js";

			string[] argv;
			if (use_init) {
				argv = { shell_bin, "--debug" };
			} else {
				var smoke_name = smoke_env;
				if (!smoke_name.has_suffix(".js")) {
					smoke_name += ".js";
				}
				var script = GLib.Path.build_filename(
					bindir, "..", "..", "src", "gjs-embed", smoke_name);
				if (!GLib.FileUtils.test(script, GLib.FileTest.IS_REGULAR)) {
					GLib.warning("%s missing at %s — skip client spawn", smoke_name, script);
					return;
				}
				argv = { shell_bin, "--debug", script };
			}

			var tip = GLib.Environment.get_variable("GI_TYPELIB_PATH");
			var client_tl = GNOME_SHELL_CLIENT_TYPELIB_DIR;
			string[] tip_parts = { bindir, MUTTER_TYPELIB_DIR };
			if (client_tl.length > 0) {
				tip_parts += client_tl;
			}
			if (tip != null && tip.length > 0) {
				tip_parts += tip;
			}
			tip = string.joinv(":", tip_parts);

			var ld = GLib.Environment.get_variable("LD_LIBRARY_PATH");
			string[] ld_parts = { bindir };
			if (client_tl.length > 0) {
				ld_parts += client_tl;
			}
			if (ld != null && ld.length > 0) {
				ld_parts += ld;
			}
			ld = string.joinv(":", ld_parts);

			var launcher = new GLib.SubprocessLauncher(GLib.SubprocessFlags.NONE);
			launcher.setenv("GI_TYPELIB_PATH", tip, true);
			launcher.setenv("LD_LIBRARY_PATH", ld, true);
			if (this.rpc_socket_path.length > 0) {
				launcher.setenv("MUTTER_RPC_SOCKET", this.rpc_socket_path, true);
			}
			var wayland_display = GLib.Environment.get_variable("WAYLAND_DISPLAY");
			if (wayland_display != null && wayland_display.length > 0) {
				launcher.setenv("WAYLAND_DISPLAY", wayland_display, true);
			}
			try {
				this.smoke_client = new Meta.WaylandClient(
					this.display.get_context(), launcher);
				this.smoke_client.spawnv(this.display, argv);
			} catch (GLib.Error e) {
				GLib.warning("client spawn failed: %s", e.message);
				this.smoke_client = null;
				return;
			}
			GLib.debug(
				"spawned %s MUTTER_RPC_SOCKET=%s WAYLAND_DISPLAY=%s via Meta.WaylandClient",
				string.joinv(" ", argv),
				this.rpc_socket_path,
				wayland_display ?? "(unset)"
			);
		}

		private void alias_live(string alias, GLib.Type gtype)
		{
			try {
				OLLMrpc.Bin.register_alias(alias, gtype);
			} catch (GLib.Error e) {
				GLib.debug("alias %s for %s: %s", alias, gtype.name(), e.message);
			}
		}

		private uint64? lease_handle_for(
			OLLMrpc.Transport.Connection connection,
			Meta.Window meta_window)
		{
			var ptr = (uint64) (void*) meta_window;
			var hi = (int) (ptr >> 32);
			var lo = (int) ptr;
			if (!connection.lease_ids.has_key(hi)) {
				return null;
			}
			var inner = connection.lease_ids.get(hi);
			if (!inner.has_key(lo)) {
				return null;
			}
			return (uint64) inner.get(lo);
		}

		private void track_window(Meta.Window meta_window)
		{
			meta_window.unmanaged.connect(() => {
				if (this.listen == null) {
					return;
				}
				foreach (var connection in this.listen.connections) {
					var handle = this.lease_handle_for(connection, meta_window);
					if (handle == null) {
						continue;
					}
					connection.write(new OLLMrpc.Notification() {
						method = "Window.closed",
						object_type = "Window",
						id = (int) handle,
					});
				}
				if (this.title_watch_ids.has_key(meta_window)) {
					meta_window.disconnect(this.title_watch_ids.get(meta_window));
					this.title_watch_ids.unset(meta_window);
				}
			});

			if (this.title_watch_ids.has_key(meta_window)) {
				return;
			}

			var watch_id = meta_window.notify["title"].connect(() => {
				if (this.listen == null) {
					return;
				}
				foreach (var connection in this.listen.connections) {
					var handle = this.lease_handle_for(connection, meta_window);
					if (handle == null) {
						continue;
					}
					connection.write(new OLLMrpc.Notification() {
						method = "notify::title",
						object_type = "Window",
						id = (int) handle,
						message = meta_window.title,
					});
				}
			});
			this.title_watch_ids.set(meta_window, watch_id);
		}
	}
}
