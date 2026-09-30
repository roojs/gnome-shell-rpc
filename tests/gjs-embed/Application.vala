namespace GnomeShellRpc.GjsEmbed
{
	/**
	 * Embed {@link Gjs.Context} and eval a script file.
	 *
	 * Prepends {@code GI_RPC_SMOKE_TYPELIB_DIR} to the GI typelib search path
	 * when set (toy stub for 0.5).
	 *
	 * == Example ==
	 *
	 * {{{
	 * GI_RPC_SMOKE_TYPELIB_DIR=./build/src \
	 *   ./build/src/gjs-embed --debug src/gjs-embed/smoke.js
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
				command_line.printerr(
					"Run '%s --help' to see a full list of available command line options.\n",
					args[0]
				);
				return 1;
			}

			GnomeShellRpc.debug_on = Application.opt_debug;
			GnomeShellRpc.debug_critical_enabled =
				Application.opt_debug_critical;

			if (remaining.length < 2) {
				command_line.printerr(
					"usage: %s [--debug] SCRIPT.js\n",
					GLib.Path.get_basename(remaining[0])
				);
				return 1;
			}

			var typelib_dir = GLib.Environment.get_variable(
				"GI_RPC_SMOKE_TYPELIB_DIR"
			);
			if (typelib_dir != null && typelib_dir.length > 0) {
				GI.Repository.prepend_search_path(typelib_dir);
				GLib.debug("typelib prepend %s", typelib_dir);
			}

			var script = remaining[1];
			string[] search_path = {};

			var js_dir = GLib.Environment.get_variable("GNOME_SHELL_JS_DIR");
			if (js_dir == null || js_dir.length == 0) {
				js_dir = GNOME_SHELL_JS_DIR;
			}
			if (js_dir.length > 0) {
				search_path += js_dir;
				GLib.debug("gnome-shell JS search-path %s", js_dir);
			}

			var js_extra = GLib.Environment.get_variable("GNOME_SHELL_JS_EXTRA_DIRS");
			if (js_extra != null && js_extra.length > 0) {
				foreach (var part in js_extra.split(":")) {
					if (part.length > 0) {
						search_path += part;
						GLib.debug("gnome-shell JS extra search-path %s", part);
					}
				}
			}

			search_path += GLib.Path.get_dirname(script);
			search_path += ".";
			GLib.debug("script %s", script);

			var ctx = new Gjs.Context.with_search_path(search_path);
			var status = 0;
			var ok = false;
			var use_module = script.contains("/ui/init.js")
				|| (js_dir.length > 0 && script.has_prefix(js_dir));
			try {
				if (use_module) {
					uint8 module_status = 0;
					ok = ctx.eval_module_file(script, out module_status);
					status = module_status;
				} else {
					ok = ctx.eval_file(script, out status);
				}
			} catch (GLib.Error e) {
				command_line.printerr("%s\n", e.message);
				return 1;
			}
			if (!ok) {
				return 1;
			}
			return status;
		}
	}

	int main(string[] args)
	{
		return new Application().run(args);
	}
}
