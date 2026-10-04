namespace Gsr.Server
{
	/**
	 * Process entry: configure mutter, install {@link Plugin}, run the loop.
	 *
	 * Parses {@code --debug} via {@link GLib.OptionEntry} (unknown options
	 * left for {@link global::Meta.Context.configure}). Routes {@link GLib.debug}
	 * through {@link ApplicationInterface.debug_log}.
	 *
	 * Stderr gets ''started'' before the log handler, then a flush.
	 * After {@link GLib.Log.set_default_handler}, phase lines are
	 * {@link GLib.debug}. The handler prints those when {@code --debug}
	 * is on.
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
			GLib.stderr.printf("started\n");
			GLib.stderr.flush();

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
				Gsr.debug_on = CompositorApp.opt_debug;
				Gsr.debug_critical_enabled = CompositorApp.opt_debug_critical;
				GLib.debug("error: %s", e.message);
				return 1;
			}

			Gsr.debug_on = CompositorApp.opt_debug;
			Gsr.debug_critical_enabled = CompositorApp.opt_debug_critical;

			var ctx = new global::Meta.Context("Mutter(GnomeShellRpc)");
			try {
				ctx.configure(ref argv);
			} catch (GLib.Error e) {
				GLib.debug("Error initializing: %s", e.message);
				return 1;
			}

			ctx.set_plugin_gtype(typeof(Gsr.Server.Plugin));

			try {
				ctx.setup();
			} catch (GLib.Error e) {
				GLib.debug("Failed to setup: %s", e.message);
				return 1;
			}

			try {
				ctx.start();
				ctx.run_main_loop();
			} catch (GLib.Error e) {
				GLib.debug("Failed to start: %s", e.message);
				return 1;
			}

			GLib.debug("exit 0");
			return 0;
		}
	}

	int main(string[] args)
	{
		return CompositorApp.run(args);
	}
}
