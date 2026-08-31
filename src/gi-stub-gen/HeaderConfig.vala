namespace GnomeShellRpc.GiStubGen
{
	/**
	 * Layout options for {@link HeaderGenerator} (not library-specific).
	 *
	 * Loaded from a {@code *.headers} file or derived from the GI namespace
	 * ({@code Clutter} → {@code subdir=clutter}, {@code file_prefix=clutter}).
	 *
	 * Also carries library-specific header policy that must not live in the
	 * emitter: {@code foreign_include} (Ns → {@code #include}) and
	 * {@code c_type} ({@code Ns.Name} → C spelling).
	 *
	 * Review later (0.7.4): merge into {@link HeaderGenerator} if that class
	 * stays small; keep separate while header emit grows.
	 */
	public class HeaderConfig : GLib.Object
	{
		/** Directory under {@code --outdir} ({@code clutter} → {@code outdir/clutter/}). */
		public string subdir = "";

		/** Filename prefix ({@code clutter} → {@code clutter-actor.h}). */
		public string file_prefix = "";

		/** Umbrella include guard define ({@code __CLUTTER_H_INSIDE__}). */
		public string inside_macro = "";

		/** Umbrella filename inside {@link subdir} ({@code clutter.h}). */
		public string umbrella = "";

		/** Fixed helper stems without prefix ({@code types} → {@code clutter-types.h}). */
		public string[] fixed = {};

		/** Extra umbrella stems ({@code pango} → {@code clutter-pango.h}). */
		public string[] extra = {};

		/**
		 * Optional {@code FOO_COMPILATION} for stock-style direct-include guard.
		 * Empty = omit the guard.
		 */
		public string compilation_macro = "";

		/**
		 * Foreign GI namespace → {@code #include …} line (from {@code foreign_include}).
		 * Emitter never hardcodes Atk/Cogl/… paths.
		 */
		public Gee.HashMap<string, string> foreign_includes =
			new Gee.HashMap<string, string>();

		/**
		 * {@code Ns.Name} → C typedef/struct name (from {@code c_type}).
		 * Used when GIR has no usable {@code get_type_name()} (class structs, etc.).
		 */
		public Gee.HashMap<string, string> c_types =
			new Gee.HashMap<string, string>();

		/**
		 * Absolute dir of {@code {Type}.h} body overrides (macros / opaque
		 * unions GIR cannot express). Relative paths in {@code *.headers}
		 * resolve against that file’s directory.
		 */
		public string header_override_dir = "";

		/**
		 * Defaults from GI namespace name only (no fixed/extra lists).
		 */
		public static HeaderConfig from_namespace(string ns)
		{
			var cfg = new HeaderConfig();
			var lower = ns.down();
			cfg.subdir = lower;
			cfg.file_prefix = lower;
			cfg.inside_macro = @"__$(ns.up())_H_INSIDE__";
			cfg.umbrella = @"$(lower).h";
			return cfg;
		}

		/**
		 * Parse a {@code *.headers} file. Unknown keys error.
		 */
		public static HeaderConfig load_file(string path) throws GLib.Error
		{
			string contents;
			size_t len;
			GLib.FileUtils.get_contents(path, out contents, out len);
			var cfg = new HeaderConfig();
			var fixed_list = new Gee.ArrayList<string>();
			var extra_list = new Gee.ArrayList<string>();
			foreach (var line in contents.split("\n")) {
				var stripped = line.strip();
				if (stripped == "" || stripped.has_prefix("#")) {
					continue;
				}
				var space = stripped.index_of(" ");
				string key;
				string rest;
				if (space < 0) {
					key = stripped;
					rest = "";
				} else {
					key = stripped.substring(0, space);
					rest = stripped.substring(space + 1).strip();
				}
				switch (key) {
				case "subdir":
					cfg.subdir = rest;
					break;
				case "file_prefix":
					cfg.file_prefix = rest;
					break;
				case "inside_macro":
					cfg.inside_macro = rest;
					break;
				case "umbrella":
					cfg.umbrella = rest;
					break;
				case "fixed":
					if (rest != "") {
						fixed_list.add(rest);
					}
					break;
				case "extra":
					if (rest != "") {
						extra_list.add(rest);
					}
					break;
				case "compilation_macro":
					cfg.compilation_macro = rest;
					break;
				case "foreign_include":
					/* foreign_include Atk <atk/atk.h> */
					HeaderConfig.parse_foreign_include(path, rest, cfg);
					break;
				case "c_type":
					/* c_type GObject.InitiallyUnownedClass GInitiallyUnownedClass */
					HeaderConfig.parse_c_type(path, rest, cfg);
					break;
				case "header_override_dir":
					cfg.header_override_dir = rest;
					break;
				default:
					throw new GLib.IOError.FAILED(
						@"$(path): unknown key $(key)");
				}
			}
			cfg.fixed = fixed_list.to_array();
			cfg.extra = extra_list.to_array();
			if (cfg.subdir == "" || cfg.file_prefix == ""
				|| cfg.inside_macro == "" || cfg.umbrella == "") {
				throw new GLib.IOError.FAILED(
					@"$(path): require subdir, file_prefix, inside_macro, umbrella");
			}
			if (cfg.header_override_dir != ""
				&& !GLib.Path.is_absolute(cfg.header_override_dir)) {
				cfg.header_override_dir = GLib.Path.build_filename(
					GLib.Path.get_dirname(path),
					cfg.header_override_dir);
			}
			return cfg;
		}

		private static void parse_foreign_include(
			string path,
			string rest,
			HeaderConfig cfg
		) throws GLib.Error {
			var sp = rest.index_of(" ");
			if (sp < 0) {
				throw new GLib.IOError.FAILED(
					@"$(path): foreign_include needs Ns <header> or Ns \"header\"");
			}
			var ns = rest.substring(0, sp).strip();
			var header = rest.substring(sp + 1).strip();
			if (ns == "" || header == "") {
				throw new GLib.IOError.FAILED(
					@"$(path): foreign_include needs Ns <header>");
			}
			cfg.foreign_includes.set(ns, @"#include $(header)\n");
		}

		private static void parse_c_type(
			string path,
			string rest,
			HeaderConfig cfg
		) throws GLib.Error {
			var sp = rest.index_of(" ");
			if (sp < 0) {
				throw new GLib.IOError.FAILED(
					@"$(path): c_type needs Ns.Name CType");
			}
			var gir = rest.substring(0, sp).strip();
			var ctype = rest.substring(sp + 1).strip();
			if (gir == "" || ctype == "" || !gir.contains(".")) {
				throw new GLib.IOError.FAILED(
					@"$(path): c_type needs Ns.Name CType");
			}
			cfg.c_types.set(gir, ctype);
		}

		/** {@code #include …} line for a foreign GI namespace, or null. */
		public string? include_for_ns(string ns)
		{
			if (!this.foreign_includes.has_key(ns)) {
				return null;
			}
			return this.foreign_includes.get(ns);
		}

		/** Override C name for {@code Ns.Name}, or null. */
		public string? c_type_for(string ns, string name)
		{
			var key = @"$(ns).$(name)";
			if (!this.c_types.has_key(key)) {
				return null;
			}
			return this.c_types.get(key);
		}

		public string stem(string suffix)
		{
			return @"$(this.file_prefix)-$(suffix)";
		}

		public string include_path(string filename)
		{
			return @"$(this.subdir)/$(filename)";
		}
	}
}
