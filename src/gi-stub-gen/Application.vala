namespace GnomeShellRpc.GiStubGen
{
	/**
	 * CLI for Vala stub emit and Clutter C header emit ({@link GLib.Application}).
	 *
	 * Parses options and delegates to {@link Generator} / {@link HeaderGenerator}.
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
		private static string opt_outdir = "";
		private static string opt_headers_config = "";
		private static string opt_missing_out = "";
		private static string opt_deny_file = "";
		private static string opt_overrides_file = "";
		/** Directory of `{Type}.override.vala` bodies — read by {@link Generator}. */
		public static string opt_override_path = "";

		/**
		 * Custom help text ({ARG} = program name).
		 */
		protected string help { get; set; default = """
Usage: {ARG} [OPTION…] emit NAMESPACE VERSION
       {ARG} [OPTION…] emit-headers NAMESPACE VERSION

Emit Vala stubs or stock-shaped C headers from a typelib (libgirepository).

Examples:
  {ARG} --out=./build/src/GiRpcSmoke_generated.vala \
    --typelib-dir=./build/src emit GiRpcSmoke 1.0
  {ARG} --outdir=./build/src/clutter-include \
    --headers-config=src/gi-stub-gen/Clutter.headers \
    --typelib-dir=/usr/lib/…/mutter-16 emit-headers Clutter 16
"""; }

		private const GLib.OptionEntry[] options = {
			{ "debug", 'd', 0, GLib.OptionArg.NONE, ref opt_debug,
				"Enable debug output", null },
			{ "debug-critical", 0, 0, GLib.OptionArg.NONE, ref opt_debug_critical,
				"Treat critical warnings as errors", null },
			{ "typelib-dir", 0, 0, GLib.OptionArg.STRING, ref opt_typelib_dir,
				"Prepend typelib search path(s), colon-separated", "DIR[:DIR…]" },
			{ "deny-file", 0, 0, GLib.OptionArg.FILENAME, ref opt_deny_file,
				"Deny list (one symbol per line; optional noop flag)", "FILE" },
			{ "overrides-file", 0, 0, GLib.OptionArg.FILENAME, ref opt_overrides_file,
				"Overrides file (Type[.method] key=value; type emit=… policies)", "FILE" },
			{ "override-path", 0, 0, GLib.OptionArg.FILENAME, ref opt_override_path,
				"Directory of {Type}.override.vala client bodies", "DIR" },
			{ "out", 0, 0, GLib.OptionArg.FILENAME, ref opt_out,
				"Output Vala path (emit)", "FILE" },
			{ "outdir", 0, 0, GLib.OptionArg.FILENAME, ref opt_outdir,
				"Output include root (emit-headers); parent of subdir/", "DIR" },
			{ "headers-config", 0, 0, GLib.OptionArg.FILENAME, ref opt_headers_config,
				"Header layout file (subdir, file_prefix, fixed, extra, …)", "FILE" },
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
			Application.opt_outdir = "";
			Application.opt_headers_config = "";
			Application.opt_missing_out = "";
			Application.opt_deny_file = "";
			Application.opt_overrides_file = "";
			Application.opt_override_path = "";

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
			if (cmd != "emit" && cmd != "emit-headers") {
				command_line.printerr(
					"unknown command %s (emit or emit-headers)\n", cmd);
				return 1;
			}
			if (cmd == "emit" && Application.opt_out == "") {
				command_line.printerr("emit requires --out=FILE.vala\n");
				return 1;
			}
			if (cmd == "emit-headers" && Application.opt_outdir == "") {
				command_line.printerr(
					"emit-headers requires --outdir=DIR (-I root)\n");
				return 1;
			}

			string[] deny = {};
			string[] noop = {};
			string? deny_err = this.load_deny(out deny, out noop);
			if (deny_err != null) {
				command_line.printerr("%s", deny_err);
				return 1;
			}

			Gee.HashMap<string, Gee.HashMap<string, string>> overrides;
			string? ov_err = this.load_overrides(out overrides);
			if (ov_err != null) {
				command_line.printerr("%s", ov_err);
				return 1;
			}

			if (Application.opt_typelib_dir != "") {
				foreach (var dir in Application.opt_typelib_dir.split(":")) {
					if (dir.length == 0) {
						continue;
					}
					GI.Repository.prepend_search_path(dir);
					GLib.debug("typelib prepend %s", dir);
				}
			}

			try {
				if (cmd == "emit") {
					var gen = new Generator() {
						deny = deny,
						noop = noop,
						overrides = overrides,
						missing_out_path = Application.opt_missing_out,
					};
					gen.require_typelib(ns, version);
					gen.emit(ns, Application.opt_out);
				} else {
					HeaderConfig cfg;
					if (Application.opt_headers_config != "") {
						cfg = HeaderConfig.load_file(
							Application.opt_headers_config);
					} else {
						cfg = HeaderConfig.from_namespace(ns);
					}
					var gen = new HeaderGenerator() {
						deny = deny,
						noop = noop,
						overrides = overrides,
						config = cfg,
					};
					gen.require_typelib(ns, version);
					gen.emit_headers(ns, Application.opt_outdir);
				}
			} catch (GLib.Error e) {
				command_line.printerr("%s\n", e.message);
				return 1;
			}
			return 0;
		}

		private string? load_deny(out string[] deny, out string[] noop)
		{
			deny = {};
			noop = {};
			if (Application.opt_deny_file == "") {
				return null;
			}
			string contents;
			size_t len;
			try {
				GLib.FileUtils.get_contents(
					Application.opt_deny_file, out contents, out len
				);
			} catch (GLib.Error e) {
				return @"cannot read deny file $(Application.opt_deny_file): $(e.message)\n";
			}
			var deny_list = new Gee.ArrayList<string>();
			var noop_list = new Gee.ArrayList<string>();
			foreach (var line in contents.split("\n")) {
				var name = line.strip();
				if (name == "" || name.has_prefix("#")) {
					continue;
				}
				var hash = name.index_of("#");
				if (hash >= 0) {
					name = name.substring(0, hash).strip();
				}
				if (name == "") {
					continue;
				}
				var space = name.index_of(" ");
				if (space < 0) {
					deny_list.add(name);
					continue;
				}
				var symbol = name.substring(0, space);
				var flag = name.substring(space + 1).strip();
				if (flag != "noop") {
					return @"deny file $(Application.opt_deny_file): unknown flag $(flag) on $(symbol) (only noop)\n";
				}
				noop_list.add(symbol);
			}
			deny = deny_list.to_array();
			noop = noop_list.to_array();
			return null;
		}

		private string? load_overrides(
			out Gee.HashMap<string, Gee.HashMap<string, string>> overrides
		) {
			overrides = new Gee.HashMap<string, Gee.HashMap<string, string>>();
			if (Application.opt_overrides_file == "") {
				return null;
			}
			string contents;
			size_t len;
			try {
				GLib.FileUtils.get_contents(
					Application.opt_overrides_file, out contents, out len
				);
			} catch (GLib.Error e) {
				return @"cannot read overrides file $(Application.opt_overrides_file): $(e.message)\n";
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
			return null;
		}

		private GLib.OptionContext app_options()
		{
			var opt_context = new GLib.OptionContext(
				"emit|emit-headers NAMESPACE VERSION — typelib → Vala stubs or C headers"
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
