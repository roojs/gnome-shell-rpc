namespace GnomeShellRpc.Rpc
{
	/**
	 * RPC server boot — socket, registrations, display/window notifications.
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

		public void start(Meta.Display display)
		{
			this.display = display;
			Ui.Rectangle.rpc_register();
			Ui.Window.rpc_register();
			Ui.WindowParams.rpc_register();
			Ui.Workspace.rpc_register();
			Ui.WorkspaceParams.rpc_register();
			Ui.Display.rpc_register();
			Rpc.Daemon.rpc_register();
			OLLMrpc.Request.rpc_register();
			OLLMrpc.Response.rpc_register();
			OLLMrpc.Notification.rpc_register();
			OLLMrpc.Error.rpc_register();
			OLLMrpc.Live.RemoteParams.rpc_register();
			OLLMrpc.Live.SubscribeParams.rpc_register();
			OLLMrpc.Request.register(
				"RPC-Live-Remote",
				new OLLMrpc.Live.Remote(),
				typeof(OLLMrpc.Live.RemoteParams)
			);
			OLLMrpc.Request.register(
				"RPC-Live-Subscribe",
				new OLLMrpc.Live.Subscribe(),
				typeof(OLLMrpc.Live.SubscribeParams)
			);

			this.ui_display = new Ui.Display(display);
			OLLMrpc.Request.register(
				"RPC-Daemon",
				new Daemon(),
				typeof(DaemonParams)
			);
			OLLMrpc.Request.register(
				"RPC-Display",
				this.ui_display,
				typeof(Ui.DisplayParams)
			);

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

			display.window_created.connect((meta_window) => {
				GLib.debug("window_created title=%s", meta_window.get_title());
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

		private void track_window(Meta.Window meta_window)
		{
			meta_window.unmanaged.connect(() => {
				if (this.listen == null) {
					return;
				}
				foreach (var connection in this.listen.connections) {
					var key = ((uint64)(void*)meta_window).to_string(
						"%" + uint64.FORMAT_MODIFIER + "x"
					);
					if (!connection.lease_ids.has_key(key)) {
						continue;
					}
					var handle = connection.lease_ids.get(key);
					connection.write(new OLLMrpc.Notification() {
						method = "Window.closed",
						object_type = "Window",
						id = handle,
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
					var key = ((uint64)(void*)meta_window).to_string(
						"%" + uint64.FORMAT_MODIFIER + "x"
					);
					if (!connection.lease_ids.has_key(key)) {
						continue;
					}
					connection.write(new OLLMrpc.Notification() {
						method = "notify::title",
						object_type = "Window",
						id = connection.lease_ids.get(key),
						message = meta_window.title,
					});
				}
			});
			this.title_watch_ids.set(meta_window, watch_id);
		}
	}
}
