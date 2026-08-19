namespace GnomeShellRpc.RpcClient
{
	private static OLLMrpc.Client rpc_client;

	public static int main(string[] args)
	{
		GnomeShellRpc.Debug.parse_args(args);
		GnomeShellRpc.Debug.install_log_handler("rpc-client");

		GnomeShellRpc.Ui.Rectangle.rpc_register();
		GnomeShellRpc.Ui.Window.rpc_register();
		GnomeShellRpc.Ui.WindowParams.rpc_register();
		GnomeShellRpc.Ui.DisplayParams.rpc_register();
		GnomeShellRpc.Rpc.DaemonParams.rpc_register();
		OLLMrpc.Daemon.rpc_register();

		var loop = new GLib.MainLoop();
		run.begin((obj, res) => {
			try {
				run.end(res);
			} catch (GLib.Error e) {
				GLib.printerr("rpc-client: %s\n", e.message);
				loop.quit();
			}
		});
		loop.run();
		return 0;
	}

	private static async void run()
	{
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

		RpcClient.rpc_client = new OLLMrpc.Client("", "", socket_path) {
			live_handles = true,
			debug = false,
		};

		RpcClient.rpc_client.notification.connect((notif) => {
			switch (notif.method) {
				case "Window.created":
					GLib.print("Window.created id=%d object_type=%s\n",
						notif.id, notif.object_type);
					break;

				case "Window.closed":
					GLib.print("Window.closed id=%d\n", notif.id);
					break;

				default:
					if (notif.method.has_prefix("notify::")) {
						GLib.print("%s id=%d %s=%s\n",
							notif.method,
							notif.id,
							notif.method.substring(8),
							notif.message);
						break;
					}
					GLib.print("notification method=%s id=%d message=%s\n",
						notif.method, notif.id, notif.message);
					break;
			}
		});

		if (!yield RpcClient.rpc_client.connect(new OLLMrpc.Request() {
			method = "RPC-Daemon.hello",
			param = new GnomeShellRpc.Rpc.DaemonParams() {
				protocol = 1,
				client = "rpc-client",
			},
		})) {
			throw new GLib.IOError.FAILED(RpcClient.rpc_client.connect_error);
		}

		GLib.print("connected to %s\n", socket_path);

		var list_resp = yield RpcClient.rpc_client.call(new OLLMrpc.Request() {
			method = "RPC-Display.list_windows",
			param = new GnomeShellRpc.Ui.DisplayParams(),
		});
		if (list_resp.error != null) {
			throw new GLib.IOError.FAILED(list_resp.error.message);
		}
		GLib.print("list_windows: %d window(s)\n", list_resp.result.size);
		foreach (var obj in list_resp.result) {
			var win = (GnomeShellRpc.Ui.Window)obj;
			GLib.print("  [%d] title=%s wm_class=%s\n",
				win.id, win.title, win.wm_class);
		}

		GLib.print("listening for notifications (Ctrl+C to quit)…\n");
	}
}
