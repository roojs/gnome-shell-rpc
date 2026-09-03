/**
 * gnome-shell-rpc thin host — no libshell (0.7.7).
 *
 * {@code Runtime.register()} → {@link Shell.Global.bind_display} → own
 * {@link Gjs.Context} → eval {@code init.js} (default) or SCRIPT.js.
 */
namespace GnomeShellRpc.ShellClient
{
	public class Application : GLib.Application, GnomeShellRpc.ApplicationInterface
	{
		private const string APPLICATION_ID = "org.gnome.ShellRpc";
		private const string INIT_MODULE =
			"resource:///org/gnome/shell/ui/init.js";

		private static bool opt_debug = false;
		private static bool opt_debug_critical = false;

		private const GLib.OptionEntry[] options = {
			{ "debug", 'd', 0, GLib.OptionArg.NONE, ref opt_debug,
				"Enable debug output", null },
			{ "debug-critical", 0, 0, GLib.OptionArg.NONE, ref opt_debug_critical,
				"Treat critical warnings as errors", null },
			{ null }
		};

		[CCode (cname = "shell_js_resources_get_resource")]
		private static extern GLib.Resource shell_js_resources_get_resource();

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
			var opt_context = new GLib.OptionContext("[SCRIPT.js]");
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
			GLib.resources_register(shell_js_resources_get_resource());

			GnomeShellRpc.GiStub.Runtime.register();
			Shell.Global.bind_display(Meta.get_display());

			var script = resolve_script(remaining);
			string[] search_path = {
				"resource:///org/gnome/shell",
			};
			var js_dir = GLib.Environment.get_variable("GNOME_SHELL_JS_DIR");
			if (js_dir != null && js_dir.length > 0) {
				search_path += js_dir;
				GLib.debug("gnome-shell JS search-path %s", js_dir);
			}
			if (!script.has_prefix("resource://")) {
				search_path += GLib.Path.get_dirname(script);
			}
			search_path += ".";

			GLib.debug("shell script %s", script);
			var ctx = new Gjs.Context.with_search_path(search_path);
			var status = 0;
			var ok = false;
			try {
				if (script.has_prefix("resource://")
					|| script.contains("/ui/init.js")
					|| script.contains("/gjs-embed/")) {
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

		private void prepend_typelib_paths()
		{
			var typelib_dir = GLib.Environment.get_variable(
				"GI_RPC_SMOKE_TYPELIB_DIR"
			);
			if (typelib_dir != null && typelib_dir.length > 0) {
				GI.Repository.prepend_search_path(typelib_dir);
				GLib.debug("typelib prepend %s", typelib_dir);
			}
		}

		private string resolve_script(unowned string[] remaining)
		{
			if (remaining.length >= 2) {
				return remaining[1];
			}
			return INIT_MODULE;
		}
	}

	int main(string[] args)
	{
		return new Application().run(args);
	}
}
