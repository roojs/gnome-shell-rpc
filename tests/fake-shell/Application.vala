namespace GnomeShellRpc.FakeShell
{
	/**
	 * Gtk application that connects {@link Session} and shows
	 * {@link TopBar}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * ./build/src/fake-shell --debug
	 * }}}
	 */
	public class Application : Gtk.Application, GnomeShellRpc.ApplicationInterface
	{
		private static bool opt_debug = false;
		private static bool opt_debug_critical = false;

		private Session session;

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
				application_id: "org.gnome.ShellRpc.FakeShell",
				flags: GLib.ApplicationFlags.HANDLES_COMMAND_LINE
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

			this.hold();
			this.activate();
			this.release();
			return 0;
		}

		public override void activate()
		{
			this.hold();
			this.session = new Session();
			this.session.connect.begin((obj, res) => {
				try {
					this.session.connect.end(res);
				} catch (GLib.Error e) {
					GLib.printerr("fake-shell: %s\n", e.message);
					this.release();
					this.quit();
					return;
				}
				var bar = new TopBar(this, this.session);
				bar.present();
				this.release();
			});
		}
	}

	int main(string[] args)
	{
		return new Application().run(args);
	}
}
