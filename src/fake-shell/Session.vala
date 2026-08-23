namespace GnomeShellRpc.FakeShell
{
	/**
	 * Owns the RPC {@link OLLMrpc.Client} for a compositor connection.
	 *
	 * Connect-only (no {@link OLLMrpc.ClientBoot}). Retain for process
	 * lifetime. Demuxes notifications into {@link Display} / {@link Window}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * var session = new GnomeShellRpc.FakeShell.Session();
	 * yield session.connect();
	 * }}}
	 */
	public class Session : GLib.Object
	{
		public OLLMrpc.Client client { get; private set; }
		public Display display { get; private set; }

		public Session()
		{
			this.display = new Display(this);
		}

		/**
		 * Connect to {@code MUTTER_RPC_SOCKET} (or runtime default), hello,
		 * then refresh the window graph.
		 */
		public new async void connect() throws GLib.Error
		{
			Shared.Rectangle.rpc_register();
			Ui.Window.rpc_register();
			Ui.WindowParams.rpc_register();
			Ui.DisplayParams.rpc_register();
			Rpc.DaemonParams.rpc_register();
			OLLMrpc.Daemon.rpc_register();

			var socket_path = GLib.Environment.get_variable("MUTTER_RPC_SOCKET");
			if (socket_path == null || socket_path.length == 0) {
				var runtime = GLib.Environment.get_variable("XDG_RUNTIME_DIR");
				if (runtime != null && runtime.length > 0) {
					socket_path = GLib.Path.build_filename(runtime, "mutter-rpc.sock");
				} else {
					socket_path = "/tmp/mutter-rpc.sock";
				}
			}
			GLib.debug("socket path %s", socket_path);

			this.client = new OLLMrpc.Client("", "", socket_path) {
				live_handles = true,
				debug = false,
			};

			this.client.notification.connect((notif) => {
				switch (notif.method) {
					case "Window.created":
					case "Window.closed":
						this.display.list_windows.begin((obj, res) => {
							try {
								this.display.list_windows.end(res);
							} catch (GLib.Error e) {
								GLib.warning("%s", e.message);
							}
						});
						break;

					default:
						GLib.debug("notification method=%s id=%d",
							notif.method, notif.id);
						break;
				}
			});

			if (!yield this.client.connect(new OLLMrpc.Request() {
				method = "RPC-Daemon.hello",
				param = new Rpc.DaemonParams() {
					protocol = 1,
					client = "fake-shell",
				},
			})) {
				throw new GLib.IOError.FAILED(this.client.connect_error);
			}

			yield this.display.list_windows();
		}

		/**
		 * Send a typed request on the connected client.
		 *
		 * @param request wire request
		 * @return wire response
		 */
		public async OLLMrpc.Response call(OLLMrpc.Request request) throws GLib.Error
		{
			var response = yield this.client.call(request);
			if (response.error != null) {
				throw new GLib.IOError.FAILED(response.error.message);
			}
			return response;
		}
	}
}
