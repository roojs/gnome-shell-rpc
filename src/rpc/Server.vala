namespace GnomeShellRpc.Rpc
{
	/**
	 * RPC server boot — socket, registrations, display/window notifications,
	 * then a lightweight spawn of {@code gjs-embed} + {@code meta-smoke.js}
	 * (no pid watch).
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

		public void start(Meta.Display display)
		{
			this.display = display;
			OLLMrpc.rpc_register(true);
			Shared.Rectangle.rpc_register();
			Ui.Window.rpc_register();
			Ui.Workspace.rpc_register();
			Ui.Display.rpc_register();
			Ui.Compositor.rpc_register();
			Ui.Backend.rpc_register();
			Rpc.Daemon.rpc_register();
			Rpc.Bootstrap.rpc_register();

			Rpc.CancellableBridge.register();
			Rpc.Helper.SoundPlayer.register();
			Rpc.Helper.Background.register();
			Rpc.Helper.Context.register();
			Rpc.Helper.IdleMonitor.register();
			Rpc.Helper.Display.register();
			Rpc.Helper.Window.register();
			Rpc.Helper.WindowActor.register();
			Rpc.Helper.Selection.register();
			Rpc.Helper.SelectionSource.register();
			Rpc.Helper.SelectionSourceMemory.register();
			Rpc.Helper.ShapedTexture.register();

			this.ui_display = new Ui.Display(display);
			OLLMrpc.Request.register("RPC-Daemon", new Daemon());
			OLLMrpc.Request.register_live("Meta-Display", this.ui_display);
			OLLMrpc.Request.register_live("Meta-Compositor",
				new Ui.Compositor(display.get_compositor()));
			OLLMrpc.Request.register_live("Meta-Backend",
				new Ui.Backend(display.get_context().get_backend()));

			try {
				GI.Repository.prepend_search_path(MUTTER_TYPELIB_DIR);
				OLLMrpc.Gi.register("Meta", "16");
				OLLMrpc.Gi.register("Clutter", "16");
				OLLMrpc.Bin.register_alias("Meta-Compositor",
					display.get_compositor().get_type());
				OLLMrpc.Bin.register_alias("Meta-Backend",
					display.get_context().get_backend().get_type());
			} catch (GLib.Error e) {
				GLib.error("%s", e.message);
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
		 * Spawn {@code gjs-embed} + {@code meta-smoke.js} via
		 * {@link Meta.WaylandClient}. Smoke launches apps with stock
		 * {@code get_startup_notification().create_launcher()} + Gio.
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
			var gjs_embed = GLib.Path.build_filename(bindir, "gjs-embed");
			var smoke_env = GLib.Environment.get_variable("GI_META_SMOKE");
			var smoke_name = (smoke_env != null && smoke_env.length > 0)
				? smoke_env
				: "meta-smoke.js";
			if (!smoke_name.has_suffix(".js")) {
				smoke_name += ".js";
			}
			var script = GLib.Path.build_filename(
				bindir, "..", "..", "src", "gjs-embed", smoke_name);
			if (!GLib.FileUtils.test(gjs_embed, GLib.FileTest.IS_EXECUTABLE)) {
				GLib.warning("gjs-embed missing at %s — skip client spawn", gjs_embed);
				return;
			}
			if (!GLib.FileUtils.test(script, GLib.FileTest.IS_REGULAR)) {
				GLib.warning("%s missing at %s — skip client spawn", smoke_name, script);
				return;
			}

			var tip = GLib.Environment.get_variable("GI_TYPELIB_PATH");
			if (tip != null && tip.length > 0) {
				tip = bindir + ":" + MUTTER_TYPELIB_DIR + ":" + tip;
			} else {
				tip = bindir + ":" + MUTTER_TYPELIB_DIR;
			}

			var ld = GLib.Environment.get_variable("LD_LIBRARY_PATH");
			if (ld != null && ld.length > 0) {
				ld = bindir + ":" + ld;
			} else {
				ld = bindir;
			}

			string[] argv = { gjs_embed, "--debug", script };
			var launcher = new GLib.SubprocessLauncher(GLib.SubprocessFlags.NONE);
			launcher.setenv("GI_TYPELIB_PATH", tip, true);
			launcher.setenv("LD_LIBRARY_PATH", ld, true);
			try {
				this.smoke_client = new Meta.WaylandClient(
					this.display.get_context(), launcher);
				this.smoke_client.spawnv(this.display, argv);
			} catch (GLib.Error e) {
				GLib.warning("client spawn failed: %s", e.message);
				this.smoke_client = null;
				return;
			}
			GLib.debug("spawned %s %s via Meta.WaylandClient", gjs_embed, script);
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
