namespace GnomeShellRpc
{
	/**
	 * Process entry: configure mutter, install {@link Plugin}, run the loop.
	 *
	 * Parses {@code --debug} via {@link GLib.OptionEntry} (unknown options
	 * left for {@link Meta.Context.configure}). Routes {@link GLib.debug}
	 * through {@link ApplicationInterface.debug_log}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * dbus-run-session ./build/src/mutter-rpc --debug --wayland --nested
	 * }}}
	 */
	private class CompositorApp : GLib.Object, ApplicationInterface
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

		public static int run(string[] args)
		{
			CompositorApp.opt_debug = false;
			CompositorApp.opt_debug_critical = false;

			GLib.Log.set_default_handler((dom, lvl, msg) => {
				ApplicationInterface.debug_log(
					"mutter-rpc", dom, lvl, msg
				);
			});

			var opt_context = new GLib.OptionContext("- mutter compositor");
			opt_context.set_help_enabled(true);
			opt_context.set_ignore_unknown_options(true);
			opt_context.add_main_entries(CompositorApp.options, null);

			unowned string[] argv = args;
			try {
				opt_context.parse(ref argv);
			} catch (GLib.OptionError e) {
				GLib.stderr.printf("error: %s\n", e.message);
				return 1;
			}

			GnomeShellRpc.debug_on = CompositorApp.opt_debug;
			GnomeShellRpc.debug_critical_enabled =
				CompositorApp.opt_debug_critical;

			var ctx = new Meta.Context("Mutter(GnomeShellRpc)");
			try {
				ctx.configure(ref argv);
			} catch (GLib.Error e) {
				GLib.stderr.printf("Error initializing: %s\n", e.message);
				return 1;
			}

			ctx.set_plugin_gtype(typeof(GnomeShellRpc.Plugin));

			try {
				ctx.setup();
			} catch (GLib.Error e) {
				GLib.stderr.printf("Failed to setup: %s\n", e.message);
				return 1;
			}

			try {
				ctx.start();
				ctx.run_main_loop();
			} catch (GLib.Error e) {
				GLib.stderr.printf("Failed to start: %s\n", e.message);
				return 1;
			}

			return 0;
		}
	}

	int main(string[] args)
	{
		return CompositorApp.run(args);
	}
}
