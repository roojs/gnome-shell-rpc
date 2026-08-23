namespace GnomeShellRpc.RpcClient
{
	/**
	 * CLI that lists windows and listens for notifications.
	 *
	 * == Example ==
	 *
	 * {{{
	 * ./build/src/rpc-client --debug
	 * }}}
	 */
	public class Application : GLib.Application, GnomeShellRpc.ApplicationInterface
	{
		private static bool opt_debug = false;
		private static bool opt_debug_critical = false;
		private static OLLMrpc.Client rpc_client;

		private const GLib.OptionEntry[] options = {
			{ "debug", 'd', 0, GLib.OptionArg.NONE, ref opt_debug,
				"Enable debug output", null },
			{ "debug-critical", 0, 0, GLib.OptionArg.NONE, ref opt_debug_critical,
				"Treat critical warnings as errors", null },
			{ null }
		};

		public Application()
		{
			GLib.Object(
				application_id: "org.gnome.ShellRpc.RpcClient",
				flags: GLib.ApplicationFlags.HANDLES_COMMAND_LINE
					| GLib.ApplicationFlags.NON_UNIQUE
			);

			GLib.Log.set_default_handler((dom, lvl, msg) => {
				GnomeShellRpc.ApplicationInterface.debug_log(
					this.get_application_id(), dom, lvl, msg
				);
			});
		}

		protected override int command_line(GLib.ApplicationCommandLine command_line)
		{
			Application.opt_debug = false;
			Application.opt_debug_critical = false;

			var args = command_line.get_arguments();
			var opt_context = new GLib.OptionContext(
				this.get_application_id()
			);
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(Application.options, null);

			unowned string[] remaining = args;
			try {
				opt_context.parse(ref remaining);
			} catch (GLib.OptionError e) {
				command_line.printerr("error: %s\n", e.message);
				command_line.printerr(
					"Run '%s --help' to see a full list of available command line options.\n",
					args[0]
				);
				return 1;
			}

			GnomeShellRpc.debug_on = Application.opt_debug;
			GnomeShellRpc.debug_critical_enabled =
				Application.opt_debug_critical;

			GnomeShellRpc.Shared.Rectangle.rpc_register();
			GnomeShellRpc.Ui.Window.rpc_register();
			GnomeShellRpc.Ui.WindowParams.rpc_register();
			GnomeShellRpc.Ui.DisplayParams.rpc_register();
			GnomeShellRpc.Rpc.DaemonParams.rpc_register();
			OLLMrpc.Daemon.rpc_register();

			this.hold();
			this.run_client.begin((obj, res) => {
				try {
					this.run_client.end(res);
				} catch (GLib.Error e) {
					command_line.printerr("rpc-client: %s\n", e.message);
					this.release();
					this.quit();
				}
			});
			return 0;
		}

		private async void run_client() throws GLib.Error
		{
			var socket_path = GLib.Environment.get_variable("MUTTER_RPC_SOCKET");
			if (socket_path == null || socket_path.length == 0) {
				var runtime = GLib.Environment.get_variable("XDG_RUNTIME_DIR");
				if (runtime != null && runtime.length > 0) {
					socket_path = GLib.Path.build_filename(
						runtime, "mutter-rpc.sock"
					);
				} else {
					socket_path = "/tmp/mutter-rpc.sock";
				}
			}
			GLib.debug("socket path %s", socket_path);

			Application.rpc_client = new OLLMrpc.Client("", "", socket_path) {
				live_handles = true,
				debug = false,
			};

			Application.rpc_client.notification.connect((notif) => {
				switch (notif.method) {
					case "Window.created":
						GLib.print("Window.created id=%d object_type=%s\n",
							notif.id, notif.object_type);
						if (Application.rpc_client.proxies.has_key(notif.id)) {
							break;
						}
						Application.rpc_client.proxies.set(
							notif.id,
							new GnomeShellRpc.Ui.Window() {
								id = notif.id,
							}
						);
						break;

					case "Window.closed":
						GLib.print("Window.closed id=%d\n", notif.id);
						Application.rpc_client.proxies.unset(notif.id);
						break;

					default:
						GLib.print(
							"notification method=%s id=%d message=%s\n",
							notif.method, notif.id, notif.message
						);
						break;
				}
			});

			if (!yield Application.rpc_client.connect(new OLLMrpc.Request() {
				method = "RPC-Daemon.hello",
				param = new GnomeShellRpc.Rpc.DaemonParams() {
					protocol = 1,
					client = "rpc-client",
				},
			})) {
				throw new GLib.IOError.FAILED(
					Application.rpc_client.connect_error
				);
			}

			GLib.print("connected to %s\n", socket_path);

			var list_resp = yield Application.rpc_client.call(
				new OLLMrpc.Request() {
					method = "Meta-Display.list_windows",
					param = new GnomeShellRpc.Ui.DisplayParams(),
				}
			);
			if (list_resp.error != null) {
				throw new GLib.IOError.FAILED(list_resp.error.message);
			}
			GLib.print("list_windows: %d window(s)\n", list_resp.result.size);
			foreach (var obj in list_resp.result) {
				var win = (GnomeShellRpc.Ui.Window)obj;
				GLib.print("  [%d] title=%s wm_class=%s\n",
					win.id, win.title, win.wm_class);
				Application.rpc_client.proxies.set(win.id, win);
			}

			GLib.print("listening for notifications (Ctrl+C to quit)…\n");
		}
	}

	int main(string[] args)
	{
		return new Application().run(args);
	}
}
