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
	public class Application : GLib.Application, GnomeShellRpc.ApplicationInterface
	{
		private static bool opt_debug = false;
		private static bool opt_debug_critical = false;

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
				application_id: "org.gnome.ShellRpc.GiRpcMock",
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

			this.prepend_typelib_paths();

			OLLMrpc.rpc_register(true);
			GnomeShellRpc.Rpc.Daemon.rpc_register();
			OLLMrpc.Request.register(
				"RPC-Daemon",
				new GnomeShellRpc.Rpc.Daemon()
			);

			try {
				OLLMrpc.Gi.register("Meta", "16");
				OLLMrpc.Gi.register("Clutter", "16");
				OLLMrpc.Gi.register("St", "16");
			} catch (GLib.Error e) {
				GLib.error("Gi.register: %s", e.message);
			}

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

			var listen = new GnomeShellRpc.Rpc.Listen(socket_path) {
				live_handles = true,
			};
			if (!listen.start()) {
				GLib.error("failed to listen on %s", socket_path);
			}
			command_line.print("listening on %s\n", socket_path);

			this.hold();
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
