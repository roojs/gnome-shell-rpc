namespace GnomeShellRpc.ShellClient
{
	/**
	 * gnome-shell-rpc: libshell bootstrap + upstream init.js entry.
	 *
	 * Requires {@code MUTTER_RPC_SOCKET}, client typelibs on
	 * {@code GI_TYPELIB_PATH}, and a running {@code mutter-rpc} compositor.
	 */
	public class Application : GLib.Application, GnomeShellRpc.ApplicationInterface
	{
		private const string APPLICATION_ID = "org.gnome.ShellRpc";
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
				application_id: APPLICATION_ID,
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
			var opt_context = new GLib.OptionContext("SCRIPT.js");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(Application.options, null);

			unowned string[] remaining = args;
			try {
				opt_context.parse(ref remaining);
			} catch (GLib.OptionError e) {
				command_line.printerr("error: %s\n", e.message);
				return 1;
			}

			GnomeShellRpc.debug_on = Application.opt_debug;
			GnomeShellRpc.debug_critical_enabled =
				Application.opt_debug_critical;

			prepend_typelib_paths();

			shell_bootstrap_connected();

			var ctx = get_gjs_context();
			var script = resolve_script(remaining, command_line);
			if (script == null) {
				return 1;
			}

			GLib.debug("shell script %s", script);
			var status = 0;
			var ok = false;
			try {
				uint8 module_status = 0;
				ok = ctx.eval_module_file(script, out module_status);
				status = module_status;
			} catch (GLib.Error e) {
				command_line.printerr("%s\n", e.message);
				return 1;
			}
			if (!ok) {
				return 1;
			}
			return status;
		}

		private void prepend_typelib_paths()
		{
			var typelib_dir = GLib.Environment.get_variable(
				"GI_RPC_SMOKE_TYPELIB_DIR"
			);
			if (typelib_dir != null && typelib_dir.length > 0) {
				GI.Repository.prepend_search_path(typelib_dir);
				GLib.debug("typelib prepend %s", typelib_dir);
			}

			foreach (var var_name in new string[] {
				"GI_TYPELIB_PATH",
				"LD_LIBRARY_PATH",
			}) {
				/* spawn sets these; nothing to do here for GI.Repository */
			}
		}

		private string? resolve_script(
			unowned string[] remaining,
			GLib.ApplicationCommandLine command_line
		)
		{
			if (remaining.length >= 2) {
				return remaining[1];
			}

			GLib.debug("no script arg — default init.js resource");
			return "resource:///org/gnome/shell/ui/init.js";
		}
	}

	int main(string[] args)
	{
		return new Application().run(args);
	}
}
