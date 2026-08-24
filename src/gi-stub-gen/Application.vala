namespace GnomeShellRpc.GiStubGen
{
	/**
	 * CLI for Vala stub emit ({@link GLib.Application}).
	 *
	 * Parses options and delegates to {@link Generator}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * return new GnomeShellRpc.GiStubGen.Application().run(args);
	 * }}}
	 */
	public class Application : GLib.Application, GnomeShellRpc.ApplicationInterface
	{
		private static bool opt_debug = false;
		private static bool opt_debug_critical = false;
		private static string opt_typelib_dir = "";
		private static string opt_out = "";
		private static string opt_missing_out = "";
		private static string opt_deny_file = "";
		private static string opt_overrides_file = "";

		/**
		 * Custom help text ({ARG} = program name).
		 */
		protected string help { get; set; default = """
Usage: {ARG} [OPTION…] emit NAMESPACE VERSION

Emit Vala stubs from a typelib (libgirepository).

Examples:
  {ARG} --out=./build/src/GiRpcSmoke_generated.vala \
    --typelib-dir=./build/src emit GiRpcSmoke 1.0
"""; }

		private const GLib.OptionEntry[] options = {
			{ "debug", 'd', 0, GLib.OptionArg.NONE, ref opt_debug,
				"Enable debug output", null },
			{ "debug-critical", 0, 0, GLib.OptionArg.NONE, ref opt_debug_critical,
				"Treat critical warnings as errors", null },
			{ "typelib-dir", 0, 0, GLib.OptionArg.FILENAME, ref opt_typelib_dir,
				"Prepend typelib search path", "DIR" },
			{ "deny-file", 0, 0, GLib.OptionArg.FILENAME, ref opt_deny_file,
				"Deny list file (one symbol per line, # comments)", "FILE" },
			{ "overrides-file", 0, 0, GLib.OptionArg.FILENAME, ref opt_overrides_file,
				"Overrides file (Type.method key=value)", "FILE" },
			{ "out", 0, 0, GLib.OptionArg.FILENAME, ref opt_out,
				"Output Vala path", "FILE" },
			{ "missing-out", 0, 0, GLib.OptionArg.FILENAME, ref opt_missing_out,
				"Write gap summary markdown", "FILE" },
			{ null }
		};

		public Application()
		{
			GLib.Object(
				application_id: "org.gnome.ShellRpc.GiStubGen",
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
			Application.opt_typelib_dir = "";
			Application.opt_out = "";
			Application.opt_missing_out = "";
			Application.opt_deny_file = "";
			Application.opt_overrides_file = "";

			var args = command_line.get_arguments();
			if (this.check_help_arg(args)) {
				var custom_help = this.get_help_text(
					this.help, args[0], this.app_options()
				);
				command_line.print(
					"%s", custom_help != null ? custom_help : "No help available"
				);
				return 0;
			}

			var opt_context = this.app_options();
			opt_context.set_help_enabled(true);

			unowned string[] remaining_args = args;
			try {
				opt_context.parse(ref remaining_args);
			} catch (GLib.OptionError e) {
				command_line.printerr("error: %s\n", e.message);
				command_line.printerr(
					"Run '%s --help' to see a full list of available command line options.\n",
					args[0]
				);
				return 1;
			}

			GnomeShellRpc.debug_on = Application.opt_debug;
			GnomeShellRpc.debug_critical_enabled = Application.opt_debug_critical;

			if (remaining_args.length < 4) {
				var custom_help = this.get_help_text(
					this.help, args[0], this.app_options()
				);
				command_line.printerr(
					"%s", custom_help != null ? custom_help : "No help available"
				);
				return 1;
			}

			var cmd = remaining_args[1];
			var ns = remaining_args[2];
			var version = remaining_args[3];
			if (remaining_args.length > 4) {
				command_line.printerr(
					"unexpected argument %s\n", remaining_args[4]
				);
				return 1;
			}
			if (cmd != "emit") {
				command_line.printerr("unknown command %s (only emit)\n", cmd);
				return 1;
			}
			if (Application.opt_out == "") {
				command_line.printerr("emit requires --out=FILE.vala\n");
				return 1;
			}

			string[] deny = {};
			if (Application.opt_deny_file != "") {
				string contents;
				size_t len;
				try {
					GLib.FileUtils.get_contents(
						Application.opt_deny_file, out contents, out len
					);
				} catch (GLib.Error e) {
					command_line.printerr(
						"cannot read deny file %s: %s\n",
						Application.opt_deny_file,
						e.message
					);
					return 1;
				}
				foreach (var line in contents.split("\n")) {
					var name = line.strip();
					if (name == "" || name.has_prefix("#")) {
						continue;
					}
					deny += name;
				}
			}

			var overrides = new Gee.HashMap<string, Gee.HashMap<string, string>>();
			if (Application.opt_overrides_file != "") {
				string contents;
				size_t len;
				try {
					GLib.FileUtils.get_contents(
						Application.opt_overrides_file, out contents, out len
					);
				} catch (GLib.Error e) {
					command_line.printerr(
						"cannot read overrides file %s: %s\n",
						Application.opt_overrides_file,
						e.message
					);
					return 1;
				}
				foreach (var line in contents.split("\n")) {
					var stripped = line.strip();
					if (stripped == "" || stripped.has_prefix("#")) {
						continue;
					}
					var space = stripped.index_of(" ");
					if (space < 0) {
						continue;
					}
					var symbol = stripped.substring(0, space);
					var rest = stripped.substring(space + 1).strip();
					var eq = rest.index_of("=");
					if (eq < 0) {
						continue;
					}
					var key = rest.substring(0, eq).strip();
					var val = rest.substring(eq + 1).strip();
					if (!overrides.has_key(symbol)) {
						overrides.set(symbol, new Gee.HashMap<string, string>());
					}
					overrides.get(symbol).set(key, val);
				}
			}

			var gen = new Generator() {
				deny = deny,
				overrides = overrides,
				missing_out_path = Application.opt_missing_out,
			};
			if (Application.opt_typelib_dir != "") {
				GI.Repository.prepend_search_path(Application.opt_typelib_dir);
				GLib.debug("typelib prepend %s", Application.opt_typelib_dir);
			}

			try {
				GI.Repository.get_default().require(ns, version, 0);
				gen.emit(ns, Application.opt_out);
			} catch (GLib.Error e) {
				command_line.printerr("%s\n", e.message);
				return 1;
			}
			return 0;
		}

		private GLib.OptionContext app_options()
		{
			var opt_context = new GLib.OptionContext(
				"emit NAMESPACE VERSION — emit Vala stubs from a typelib"
			);
			opt_context.add_main_entries(Application.options, null);
			return opt_context;
		}
	}

	int main(string[] args)
	{
		return new Application().run(args);
	}
}
