namespace GnomeShellRpc.GiRpcMock
{
	/**
	 * Listen on {@code MUTTER_RPC_SOCKET}; Ffi + {@link HelperMock} + {@link GiMock}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * ./build/src/gi-rpc-mock --debug
	 * MUTTER_RPC_SOCKET=$XDG_RUNTIME_DIR/mutter-rpc.sock \
	 *   ./build/src/gnome-shell-rpc --debug src/gjs-embed/register-class-trace-smoke.js
	 * }}}
	 */
	public class Application : GLib.Object, GnomeShellRpc.ApplicationInterface
	{
		private const string APP_ID = "org.gnome.ShellRpc.GiRpcMock";

		private static bool opt_debug = false;
		private static bool opt_debug_critical = false;

		private const GLib.OptionEntry[] options = {
			{ "debug", 'd', 0, GLib.OptionArg.NONE, ref opt_debug,
				"Enable debug output", null },
			{ "debug-critical", 0, 0, GLib.OptionArg.NONE, ref opt_debug_critical,
				"Treat critical warnings as errors", null },
			{ null }
		};

		private GnomeShellRpc.Rpc.Listen? listen = null;

		public Application()
		{
			GLib.Log.set_default_handler((dom, lvl, msg) => {
				GnomeShellRpc.ApplicationInterface.debug_log(
					Application.APP_ID, dom, lvl, msg
				);
			});
		}

		public int run(string[] args)
		{
			Application.opt_debug = false;
			Application.opt_debug_critical = false;

			var opt_context = new GLib.OptionContext(Application.APP_ID);
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(Application.options, null);

			unowned string[] remaining = args;
			try {
				opt_context.parse(ref remaining);
			} catch (GLib.OptionError e) {
				GLib.stderr.printf("error: %s\n", e.message);
				return 1;
			}

			GnomeShellRpc.debug_on = Application.opt_debug;
			GnomeShellRpc.debug_critical_enabled =
				Application.opt_debug_critical;

			this.prepend_typelib_paths();

			OLLMrpc.rpc_register(true);
			GnomeShellRpc.Rpc.Daemon.rpc_register();
			GnomeShellRpc.GiRpcMock.Bootstrap.rpc_register();
			var daemon = new GnomeShellRpc.Rpc.Daemon() {
				server = "gi-rpc-mock",
			};
			OLLMrpc.Request.register("RPC-Daemon", daemon);

			try {
				OLLMrpc.Gi.register("Meta", "16");
				OLLMrpc.Gi.register("Clutter", "16");
				OLLMrpc.Gi.register("St", "16");
			} catch (GLib.Error e) {
				GLib.error("Gi.register: %s", e.message);
			}

			OLLMrpc.Bin.register(
				"Shell-GLSLEffect",
				typeof(MockShellGLSLEffect)
			);

			OLLMrpc.Request.register(
				"RPC-Bootstrap",
				GnomeShellRpc.GiRpcMock.Bootstrap.bind()
			);
			OLLMrpc.Request.register_mock(new HelperMock());

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

			this.listen = new GnomeShellRpc.Rpc.Listen(socket_path) {
				live_handles = true,
			};
			if (!this.listen.start()) {
				GLib.error("failed to listen on %s", socket_path);
			}
			GLib.print("listening on %s\n", socket_path);

			new GLib.MainLoop().run();
			return 0;
		}

		private void prepend_typelib_paths()
		{
			if (GnomeShellRpc.Rpc.MUTTER_TYPELIB_DIR.length > 0) {
				GI.Repository.prepend_search_path(
					GnomeShellRpc.Rpc.MUTTER_TYPELIB_DIR
				);
			}
			if (GnomeShellRpc.Rpc.GNOME_SHELL_PKGLIBDIR.length > 0) {
				GI.Repository.prepend_search_path(
					GnomeShellRpc.Rpc.GNOME_SHELL_PKGLIBDIR
				);
			}
		}
	}

	int main(string[] args)
	{
		return new Application().run(args);
	}
}
