namespace GnomeShellRpc.GiStubGen
{
	/**
	 * Emit stock-shaped {@code <subdir>/*.h} from a typelib.
	 * Phase A–B: shells / types. Phase C: class vfuncs + method prototypes.
	 * Layout from {@link HeaderConfig}.
	 */
	public class HeaderGenerator : GLib.Object
	{
		public HeaderConfig config = new HeaderConfig();

		/**
		 * GIR type name → stock-ish kebab file stem ({@code ActorMeta} →
		 * {@code actor-meta}).
		 */
		private static string to_kebab(string name)
		{
			try {
				return new GLib.Regex("([A-Z]+)([A-Z][a-z])").replace(
					new GLib.Regex("([a-z0-9])([A-Z])").replace(
						name, -1, 0, "\\1-\\2"),
					-1, 0, "\\1-\\2").down();
			} catch (GLib.RegexError e) {
				assert_not_reached();
			}
		}

		/**
		 * Write {@code outdir/<subdir>/…}. {@code outdir} is the {@code -I} root.
		 */
		public void emit_headers(string ns, string outdir) throws GLib.Error
		{
			var cfg = this.config;
			if (cfg.subdir == "" || cfg.file_prefix == "") {
				cfg = HeaderConfig.from_namespace(ns);
				this.config = cfg;
			}

			var ns_dir = GLib.Path.build_filename(outdir, cfg.subdir);
			GLib.DirUtils.create_with_parents(ns_dir, 0755);

			var objects = new Gee.ArrayList<GI.ObjectInfo>();
			var interfaces = new Gee.ArrayList<GI.InterfaceInfo>();
			var records = new Gee.ArrayList<GI.StructInfo>();
			var unions = new Gee.ArrayList<GI.UnionInfo>();
			var enums = new Gee.ArrayList<GI.EnumInfo>();
			var flags = new Gee.ArrayList<GI.EnumInfo>();

			var n_infos = GI.Repository.get_default().get_n_infos(ns);
			for (var i = 0; i < n_infos; i++) {
				var info = GI.Repository.get_default().get_info(ns, i);
				var name = info.get_name();
				if (name == null || name == "") {
					continue;
				}
				switch (info.get_type()) {
				case GI.InfoType.OBJECT:
					objects.add((GI.ObjectInfo) info);
					break;
				case GI.InfoType.INTERFACE:
					interfaces.add((GI.InterfaceInfo) info);
					break;
				case GI.InfoType.STRUCT:
					var si = (GI.StructInfo) info;
					if (si.is_gtype_struct()) {
						break;
					}
					/* Skip GObject private blobs as standalone headers. */
					if (name.has_suffix("Private")) {
						break;
					}
					records.add(si);
					break;
				case GI.InfoType.UNION:
					unions.add((GI.UnionInfo) info);
					break;
				case GI.InfoType.ENUM:
					enums.add((GI.EnumInfo) info);
					break;
				case GI.InfoType.FLAGS:
					flags.add((GI.EnumInfo) info);
					break;
				default:
					break;
				}
			}

			foreach (var suffix in cfg.fixed) {
				switch (suffix) {
				case "types":
					this.write_types_header(
						ns_dir, cfg, objects, interfaces, records, unions);
					break;
				case "enums":
					this.write_enums_header(ns_dir, cfg, enums, flags);
					break;
				case "enum-types":
					this.write_enum_types_header(ns_dir, cfg, enums, flags);
					break;
				default:
					this.write_minimal_fixed(ns_dir, cfg, suffix);
					break;
				}
			}

			foreach (var suffix in cfg.extra) {
				this.write_minimal_fixed(ns_dir, cfg, suffix);
			}

			foreach (var oi in objects) {
				this.write_object_header(ns_dir, cfg, oi);
			}
			foreach (var ii in interfaces) {
				this.write_interface_header(ns_dir, cfg, ii);
			}
			foreach (var si in records) {
				this.write_struct_header(ns_dir, cfg, si);
			}
			foreach (var ui in unions) {
				this.write_union_header(ns_dir, cfg, ui);
			}

			var ordered = this.order_per_type_stems(
				cfg, objects, interfaces, records, unions);
			this.write_umbrella(ns_dir, ordered, cfg);
			this.emit_override_subdirs(ns_dir, cfg);
		}

		/**
		 * Copy {@code header_override_dir/<subdir>/*.h} into the emit tree
		 * (e.g. {@code pango/clutter-text.h} → {@code clutter/pango/…}).
		 * Top-level override files are handled by per-type / fixed writers.
		 */
		private void emit_override_subdirs(
			string ns_dir,
			HeaderConfig cfg
		) throws GLib.Error {
			if (cfg.header_override_dir == "") {
				return;
			}
			Dir? dir = null;
			try {
				dir = Dir.open(cfg.header_override_dir);
			} catch (GLib.Error e) {
				return;
			}
			string? name = null;
			while ((name = dir.read_name()) != null) {
				var child = GLib.Path.build_filename(
					cfg.header_override_dir, name);
				if (!GLib.FileUtils.test(
						child, GLib.FileTest.IS_DIR)) {
					continue;
				}
				this.copy_override_subdir(
					ns_dir, cfg, name, child);
			}
		}

		private void copy_override_subdir(
			string ns_dir,
			HeaderConfig cfg,
			string sub_name,
			string src_dir
		) throws GLib.Error {
			var dest_dir = GLib.Path.build_filename(ns_dir, sub_name);
			GLib.DirUtils.create_with_parents(dest_dir, 0755);
			Dir? dir = null;
			try {
				dir = Dir.open(src_dir);
			} catch (GLib.Error e) {
				return;
			}
			string? name = null;
			while ((name = dir.read_name()) != null) {
				if (!name.has_suffix(".h")) {
					continue;
				}
				var src = GLib.Path.build_filename(src_dir, name);
				string body;
				size_t len;
				try {
					GLib.FileUtils.get_contents(src, out body, out len);
				} catch (GLib.Error e) {
					continue;
				}
				var dest = GLib.Path.build_filename(dest_dir, name);
				var stream = GLib.FileStream.open(dest, "w");
				if (stream == null) {
					throw new GLib.IOError.FAILED("cannot write " + dest);
				}
				stream.puts(
					"/* Generated by gi-stub-gen — from header-overrides */\n");
				stream.puts("#pragma once\n\n");
				this.put_override_body(stream, body);
			}
		}

		/**
		 * Parents before children so umbrella {@code #include} order is valid C.
		 */
		private Gee.ArrayList<string> order_per_type_stems(
			HeaderConfig cfg,
			Gee.ArrayList<GI.ObjectInfo> objects,
			Gee.ArrayList<GI.InterfaceInfo> interfaces,
			Gee.ArrayList<GI.StructInfo> records,
			Gee.ArrayList<GI.UnionInfo> unions
		) {
			var ordered = new Gee.ArrayList<string>();
			var seen = new Gee.HashSet<string>();
			foreach (var oi in objects) {
				this.order_object_walk(cfg, oi, ordered, seen);
			}
			foreach (var ii in interfaces) {
				var stem = cfg.stem(to_kebab(ii.get_name()));
				if (!seen.contains(stem)) {
					seen.add(stem);
					ordered.add(stem);
				}
			}
			foreach (var si in records) {
				var stem = cfg.stem(to_kebab(si.get_name()));
				if (!seen.contains(stem)) {
					seen.add(stem);
					ordered.add(stem);
				}
			}
			foreach (var ui in unions) {
				var stem = cfg.stem(to_kebab(ui.get_name()));
				if (!seen.contains(stem)) {
					seen.add(stem);
					ordered.add(stem);
				}
			}
			return ordered;
		}

		private void order_object_walk(
			HeaderConfig cfg,
			GI.ObjectInfo oi,
			Gee.ArrayList<string> ordered,
			Gee.HashSet<string> seen
		) {
			var stem = cfg.stem(to_kebab(oi.get_name()));
			if (seen.contains(stem)) {
				return;
			}
			var parent = oi.get_parent();
			if (parent != null
				&& parent.get_namespace() == oi.get_namespace()) {
				this.order_object_walk(cfg, parent, ordered, seen);
			}
			seen.add(stem);
			ordered.add(stem);
		}

		private GLib.FileStream open_h(
			string ns_dir,
			string filename
		) throws GLib.Error {
			var path = GLib.Path.build_filename(ns_dir, filename);
			var stream = GLib.FileStream.open(path, "w");
			if (stream == null) {
				throw new GLib.IOError.FAILED("cannot write " + path);
			}
			return stream;
		}

		private void write_banner(
			GLib.FileStream stream,
			HeaderConfig cfg,
			bool allow_direct = false
		) {
			stream.puts(
				"/* Generated by gi-stub-gen emit-headers — do not edit */\n");
			stream.puts("#pragma once\n\n");
			if (!allow_direct && cfg.compilation_macro != "") {
				stream.printf(
					"#if !defined(%s) && !defined(%s)\n",
					cfg.inside_macro,
					cfg.compilation_macro);
				stream.printf(
					"#error \"Only <%s/%s> can be included directly.\"\n",
					cfg.subdir,
					cfg.umbrella);
				stream.puts("#endif\n\n");
			}
		}

		/** file_prefix {@code clutter} → {@code Clutter}. */
		private string c_prefix(HeaderConfig cfg)
		{
			var p = cfg.file_prefix;
			if (p.length == 0) {
				return "";
			}
			return p.substring(0, 1).up() + p.substring(1);
		}

		/**
		 * {@code clutter_actor_get_type} → {@code CLUTTER_TYPE_ACTOR}.
		 */
		private string type_macro_from_func(string type_init)
		{
			var stem = type_init;
			if (stem.has_suffix("_get_type")) {
				stem = stem.substring(0, stem.length - "_get_type".length);
			}
			var cast = stem.up();
			var i = cast.index_of("_");
			if (i < 0) {
				return cast + "_TYPE";
			}
			return cast.substring(0, i) + "_TYPE" + cast.substring(i);
		}

		private string cast_macro_from_func(string type_init)
		{
			var stem = type_init;
			if (stem.has_suffix("_get_type")) {
				stem = stem.substring(0, stem.length - "_get_type".length);
			}
			return stem.up();
		}

		/**
		 * {@code clutter_actor_get_type} → {@code CLUTTER_IS_ACTOR} (stock shape).
		 */
		private string is_macro_from_func(string type_init)
		{
			var cast = this.cast_macro_from_func(type_init);
			var i = cast.index_of("_");
			if (i < 0) {
				return cast + "_IS";
			}
			return cast.substring(0, i) + "_IS" + cast.substring(i);
		}

		/**
		 * Body from {@code header_override_dir/name}, or empty if missing.
		 */
		private string load_override(HeaderConfig cfg, string name)
		{
			if (cfg.header_override_dir == "") {
				return "";
			}
			var path = GLib.Path.build_filename(
				cfg.header_override_dir, name);
			try {
				string body;
				size_t len;
				GLib.FileUtils.get_contents(path, out body, out len);
				return body;
			} catch (GLib.Error e) {
				return "";
			}
		}

		private void put_override_body(
			GLib.FileStream stream,
			string override_body
		) {
			stream.puts(override_body);
			if (!override_body.has_suffix("\n")) {
				stream.puts("\n");
			}
			stream.puts("\n");
		}

		private void write_minimal_fixed(
			string ns_dir,
			HeaderConfig cfg,
			string suffix
		) throws GLib.Error {
			var filename = cfg.stem(suffix) + ".h";
			var stream = this.open_h(ns_dir, filename);
			/* Override file is the fixed stem, e.g. keysyms.h / macros.h.
			 * Extra umbrellas (pango) are included directly by St — no guard. */
			var override_body = this.load_override(cfg, filename);
			var allow_direct = false;
			foreach (var ex in cfg.extra) {
				if (ex == suffix) {
					allow_direct = true;
					break;
				}
			}
			this.write_banner(stream, cfg, allow_direct && override_body != "");
			if (override_body != "") {
				this.put_override_body(stream, override_body);
				return;
			}
			stream.puts("#include <glib.h>\n\n");
			stream.puts("G_BEGIN_DECLS\n\n");
			stream.printf(
				"/* %s — placeholder */\n\n",
				cfg.include_path(filename));
			stream.puts("G_END_DECLS\n");
		}

		private void write_types_header(
			string ns_dir,
			HeaderConfig cfg,
			Gee.ArrayList<GI.ObjectInfo> objects,
			Gee.ArrayList<GI.InterfaceInfo> interfaces,
			Gee.ArrayList<GI.StructInfo> records,
			Gee.ArrayList<GI.UnionInfo> unions
		) throws GLib.Error {
			var stream = this.open_h(ns_dir, cfg.stem("types") + ".h");
			this.write_banner(stream, cfg);
			stream.puts("#include <glib-object.h>\n\n");
			stream.puts("G_BEGIN_DECLS\n\n");
			foreach (var oi in objects) {
				var tn = oi.get_type_name();
				stream.printf("typedef struct _%s %s;\n", tn, tn);
				stream.printf("typedef struct _%sClass %sClass;\n", tn, tn);
				stream.printf(
					"typedef struct _%sPrivate %sPrivate;\n", tn, tn);
			}
			stream.puts("\n");
			foreach (var ii in interfaces) {
				var ri = (GI.RegisteredTypeInfo) ii;
				var tn = ri.get_type_name();
				stream.printf("typedef struct _%s %s;\n", tn, tn);
				stream.printf(
					"typedef struct _%sInterface %sInterface;\n", tn, tn);
			}
			stream.puts("\n");
			foreach (var si in records) {
				var tn = this.c_prefix(cfg) + si.get_name();
				stream.printf("typedef struct _%s %s;\n", tn, tn);
			}
			stream.puts("\n");
			foreach (var ui in unions) {
				var tn = this.c_prefix(cfg) + ui.get_name();
				stream.printf("typedef union _%s %s;\n", tn, tn);
			}
			stream.puts("\nG_END_DECLS\n");
		}

		private void write_enums_header(
			string ns_dir,
			HeaderConfig cfg,
			Gee.ArrayList<GI.EnumInfo> enums,
			Gee.ArrayList<GI.EnumInfo> flags
		) throws GLib.Error {
			var stream = this.open_h(ns_dir, cfg.stem("enums") + ".h");
			this.write_banner(stream, cfg);
			stream.puts("#include <glib-object.h>\n\n");
			stream.puts("G_BEGIN_DECLS\n\n");
			foreach (var ei in enums) {
				this.emit_enum_block(stream, cfg, ei);
			}
			foreach (var ei in flags) {
				this.emit_enum_block(stream, cfg, ei);
			}
			stream.puts("G_END_DECLS\n");
		}

		private void emit_enum_block(
			GLib.FileStream stream,
			HeaderConfig cfg,
			GI.EnumInfo ei
		) {
			var c_type = this.c_prefix(cfg) + ei.get_name();
			stream.puts("typedef enum\n{\n");
			for (var i = 0; i < ei.get_n_values(); i++) {
				var vi = ei.get_value(i);
				var ident = vi.get_attribute("c:identifier");
				if (ident == null || ident == "") {
					var nick = vi.get_name().up().replace("-", "_");
					ident = @"$(cfg.file_prefix.up())_$(ei.get_name().up())_$(nick)";
				}
				stream.printf("  %s = %lli,\n", ident, vi.get_value());
			}
			stream.printf("} %s;\n\n", c_type);
		}

		private void write_enum_types_header(
			string ns_dir,
			HeaderConfig cfg,
			Gee.ArrayList<GI.EnumInfo> enums,
			Gee.ArrayList<GI.EnumInfo> flags
		) throws GLib.Error {
			var stream = this.open_h(ns_dir, cfg.stem("enum-types") + ".h");
			this.write_banner(stream, cfg);
			stream.puts("#include <glib-object.h>\n\n");
			stream.puts("G_BEGIN_DECLS\n\n");
			foreach (var ei in enums) {
				this.emit_enum_get_type(stream, cfg, ei);
			}
			foreach (var ei in flags) {
				this.emit_enum_get_type(stream, cfg, ei);
			}
			stream.puts("G_END_DECLS\n");
		}

		private void emit_enum_get_type(
			GLib.FileStream stream,
			HeaderConfig cfg,
			GI.EnumInfo ei
		) {
			var kebab = to_kebab(ei.get_name()).replace("-", "_");
			var func = @"$(cfg.file_prefix)_$(kebab)_get_type";
			var type_macro = this.type_macro_from_func(func);
			stream.printf("#define %s (%s ())\n", type_macro, func);
			stream.printf("GType %s (void);\n\n", func);
		}

		private void write_object_header(
			string ns_dir,
			HeaderConfig cfg,
			GI.ObjectInfo oi
		) throws GLib.Error {
			var name = oi.get_name();
			var filename = cfg.stem(to_kebab(name)) + ".h";
			var stream = this.open_h(ns_dir, filename);
			this.write_banner(stream, cfg);

			var override_body = this.load_override(cfg, name + ".h");
			var methods_extra = this.load_override(cfg, name + ".methods.h");
			if (override_body != "") {
				this.put_override_body(stream, override_body);
				this.emit_object_method_protos(
					stream, cfg, oi, methods_extra + override_body);
				if (methods_extra != "") {
					this.put_override_body(stream, methods_extra);
				}
				stream.puts("G_END_DECLS\n");
				return;
			}

			stream.puts("#include <glib-object.h>\n");
			stream.printf(
				"#include \"%s\"\n",
				cfg.include_path(cfg.stem("types") + ".h"));

			var parent = oi.get_parent();
			var parent_tn = "GObject";
			var parent_class_tn = "GObjectClass";
			var foreign = new Gee.HashSet<string>();
			if (parent != null) {
				parent_tn = parent.get_type_name();
				parent_class_tn = parent_tn + "Class";
				var pns = parent.get_namespace();
				if (pns == oi.get_namespace()) {
					stream.printf(
						"#include \"%s\"\n",
						cfg.include_path(
							cfg.stem(to_kebab(parent.get_name()))
							+ ".h"));
				} else {
					this.add_foreign_ns(cfg, foreign, pns);
				}
			}
			var cs = oi.get_class_struct();
			if (cs != null) {
				this.collect_struct_foreign(cfg, foreign, cs);
			}
			for (var m = 0; m < oi.get_n_methods(); m++) {
				this.collect_callable_foreign(cfg, foreign, oi.get_method(m));
			}
			foreach (var inc in foreign) {
				stream.puts(inc);
			}
			stream.puts("\nG_BEGIN_DECLS\n\n");

			var tn = oi.get_type_name();
			var type_init = oi.get_type_init();
			var cast_macro = this.cast_macro_from_func(type_init);
			var type_macro = this.type_macro_from_func(type_init);
			var is_macro = this.is_macro_from_func(type_init);

			stream.puts(@"#define $(type_macro) ($(type_init) ())
#define $(cast_macro)(obj) \\
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), $(type_macro), $(tn)))
#define $(cast_macro)_CLASS(klass) \\
  (G_TYPE_CHECK_CLASS_CAST ((klass), $(type_macro), $(tn)Class))
#define $(is_macro)(obj) \\
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), $(type_macro)))
#define $(is_macro)_CLASS(klass) \\
  (G_TYPE_CHECK_CLASS_TYPE ((klass), $(type_macro)))
#define $(cast_macro)_GET_CLASS(obj) \\
  (G_TYPE_INSTANCE_GET_CLASS ((obj), $(type_macro), $(tn)Class))

");

			/* Opaque instance (parent + priv only) — no invented fields. */
			stream.puts(@"struct _$(tn)
{
  $(parent_tn) parent_instance;
  $(tn)Private *priv;
};

");

			/*
			 * Class vfuncs / fields in GIR class_struct order (stock-shaped ABI).
			 */
			stream.puts(@"struct _$(tn)Class
{
");
			if (cs != null && cs.get_n_fields() > 0) {
				this.emit_gtype_struct_fields(stream, cfg, cs);
			} else {
				stream.puts(@"  $(parent_class_tn) parent_class;
");
			}
			stream.puts("};\n\n");

			stream.printf("GType %s (void);\n\n", type_init);
			this.emit_object_method_protos(stream, cfg, oi, methods_extra);
			if (methods_extra != "") {
				this.put_override_body(stream, methods_extra);
			}
			stream.puts("G_END_DECLS\n");
		}

		private void write_interface_header(
			string ns_dir,
			HeaderConfig cfg,
			GI.InterfaceInfo ii
		) throws GLib.Error {
			var name = ii.get_name();
			var filename = cfg.stem(to_kebab(name)) + ".h";
			var stream = this.open_h(ns_dir, filename);
			this.write_banner(stream, cfg);
			stream.puts("#include <glib-object.h>\n");
			stream.printf(
				"#include \"%s\"\n",
				cfg.include_path(cfg.stem("types") + ".h"));

			var foreign = new Gee.HashSet<string>();
			var istruct = ii.get_iface_struct();
			if (istruct != null) {
				this.collect_struct_foreign(cfg, foreign, istruct);
			}
			foreach (var inc in foreign) {
				stream.puts(inc);
			}
			stream.puts("\nG_BEGIN_DECLS\n\n");

			var ri = (GI.RegisteredTypeInfo) ii;
			var tn = ri.get_type_name();
			var type_init = ri.get_type_init();
			var cast_macro = this.cast_macro_from_func(type_init);
			var type_macro = this.type_macro_from_func(type_init);
			var is_macro = this.is_macro_from_func(type_init);

			stream.puts(@"#define $(type_macro) ($(type_init) ())
#define $(cast_macro)(obj) \\
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), $(type_macro), $(tn)))
#define $(is_macro)(obj) \\
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), $(type_macro)))
#define $(cast_macro)_GET_IFACE(obj) \\
  (G_TYPE_INSTANCE_GET_INTERFACE ((obj), $(type_macro), $(tn)Interface))

");

			stream.puts(@"struct _$(tn)Interface
{
");
			if (istruct != null && istruct.get_n_fields() > 0) {
				this.emit_gtype_struct_fields(stream, cfg, istruct);
			} else {
				stream.puts("  GTypeInterface parent_iface;\n");
			}
			stream.puts("};\n\n");

			stream.printf("GType %s (void);\n\n", type_init);
			this.emit_interface_method_protos(stream, cfg, ii);
			stream.puts("G_END_DECLS\n");
		}

		/**
		 * Record header. Override {@code {Name}.h} replaces the body
		 * (fields + curated method protos); otherwise GIR fields + get_type.
		 * GIR methods are appended when not already present in the override.
		 */
		private void write_struct_header(
			string ns_dir,
			HeaderConfig cfg,
			GI.StructInfo si
		) throws GLib.Error {
			var name = si.get_name();
			var filename = cfg.stem(to_kebab(name)) + ".h";
			var stream = this.open_h(ns_dir, filename);
			this.write_banner(stream, cfg);

			var override_body = this.load_override(cfg, name + ".h");
			if (override_body != "") {
				this.put_override_body(stream, override_body);
			} else {
				stream.puts("#include <glib-object.h>\n");
				stream.printf(
					"#include \"%s\"\n",
					cfg.include_path(cfg.stem("types") + ".h"));

				var foreign = new Gee.HashSet<string>();
				this.collect_struct_foreign(cfg, foreign, si);
				foreach (var inc in foreign) {
					stream.puts(inc);
				}
				stream.puts("\nG_BEGIN_DECLS\n\n");

				var tn = this.c_prefix(cfg) + name;
				var n_fields = si.get_n_fields();
				if (n_fields > 0 && si.get_size() > 0) {
					stream.puts(@"struct _$(tn)
{
");
					for (var f = 0; f < n_fields; f++) {
						var field = si.get_field(f);
						var ctype = this.field_c_type(cfg, field.get_type());
						stream.puts(@"  $(ctype) $(field.get_name());
");
					}
					stream.puts("};\n\n");
				} else {
					stream.puts(@"/* Opaque record $(tn) */
struct _$(tn) { guint8 _gsr_opaque; };

");
				}
			}

			var kebab = to_kebab(name).replace("-", "_");
			var func = @"$(cfg.file_prefix)_$(kebab)_get_type";
			if (override_body == ""
				|| !override_body.contains(@"GType $(func)")) {
				stream.printf("GType %s (void);\n\n", func);
			}
			var methods_extra = this.load_override(cfg, name + ".methods.h");
			for (var m = 0; m < si.get_n_methods(); m++) {
				var mi = si.get_method(m);
				var cname = mi.get_symbol();
				if (cname == null || cname == "") {
					continue;
				}
				if (override_body != "" && override_body.contains(cname)) {
					continue;
				}
				if (methods_extra != "" && (methods_extra.contains(cname + " (")
						|| methods_extra.contains(cname + "("))) {
					continue;
				}
				this.emit_function_proto(stream, cfg, mi);
			}
			if (methods_extra != "") {
				this.put_override_body(stream, methods_extra);
			}
			stream.puts("G_END_DECLS\n");
		}

		/**
		 * Opaque union shell (e.g. {@code ClutterEvent}).
		 * Override {@code {Name}.h} splices macros / layout; GIR methods still
		 * append unless already declared in the override.
		 */
		private void write_union_header(
			string ns_dir,
			HeaderConfig cfg,
			GI.UnionInfo ui
		) throws GLib.Error {
			var name = ui.get_name();
			var filename = cfg.stem(to_kebab(name)) + ".h";
			var stream = this.open_h(ns_dir, filename);
			this.write_banner(stream, cfg);

			var override_body = this.load_override(cfg, name + ".h");
			if (override_body != "") {
				this.put_override_body(stream, override_body);
			} else {
				stream.puts("#include <glib-object.h>\n");
				stream.printf(
					"#include \"%s\"\n\n",
					cfg.include_path(cfg.stem("types") + ".h"));
				stream.puts("G_BEGIN_DECLS\n\n");
				var tn = this.c_prefix(cfg) + name;
				var size = ui.get_size();
				if (size > 0) {
					stream.puts(@"union _$(tn)
{
  guint8 _gsr_opaque[$(size)];
};

");
				} else {
					stream.puts(@"union _$(tn)
{
  guint8 _gsr_opaque;
};

");
				}
			}

			var kebab = to_kebab(name).replace("-", "_");
			var func = @"$(cfg.file_prefix)_$(kebab)_get_type";
			/* Skip only if override already declared the prototype (not
			 * merely mentioned the symbol in CLUTTER_TYPE_*). */
			if (override_body == ""
				|| !override_body.contains(@"GType $(func)")) {
				stream.printf("GType %s (void);\n\n", func);
			}
			for (var m = 0; m < ui.get_n_methods(); m++) {
				var mi = ui.get_method(m);
				var cname = mi.get_symbol();
				if (cname != null && cname != ""
					&& override_body != ""
					&& override_body.contains(cname)) {
					continue;
				}
				this.emit_function_proto(stream, cfg, mi);
			}
			stream.puts("G_END_DECLS\n");
		}

		private void collect_callable_foreign(
			HeaderConfig cfg,
			Gee.HashSet<string> dest,
			GI.CallableInfo ci
		) {
			this.collect_type_foreign(cfg, dest, ci.get_return_type());
			for (var a = 0; a < ci.get_n_args(); a++) {
				this.collect_type_foreign(
					cfg, dest, ci.get_arg(a).get_type());
			}
		}

		private void add_foreign_ns(
			HeaderConfig cfg,
			Gee.HashSet<string> dest,
			string? ns
		) {
			if (ns == null || ns == "") {
				return;
			}
			var inc = cfg.include_for_ns(ns);
			if (inc != null) {
				dest.add(inc);
			}
		}

		private void collect_struct_foreign(
			HeaderConfig cfg,
			Gee.HashSet<string> dest,
			GI.StructInfo si
		) {
			for (var f = 0; f < si.get_n_fields(); f++) {
				this.collect_type_foreign(cfg, dest, si.get_field(f).get_type());
			}
		}

		private void collect_type_foreign(
			HeaderConfig cfg,
			Gee.HashSet<string> dest,
			GI.TypeInfo ti
		) {
			if (ti.get_tag() != GI.TypeTag.INTERFACE) {
				return;
			}
			var iface = ti.get_interface();
			if (iface == null) {
				return;
			}
			if (iface.get_type() == GI.InfoType.CALLBACK) {
				var cb = (GI.CallbackInfo) iface;
				this.collect_type_foreign(cfg, dest, cb.get_return_type());
				for (var a = 0; a < cb.get_n_args(); a++) {
					this.collect_type_foreign(
						cfg, dest, cb.get_arg(a).get_type());
				}
				return;
			}
			this.add_foreign_ns(cfg, dest, iface.get_namespace());
		}

		/**
		 * Emit GIR class/iface struct fields (parent, vfuncs, GType slots).
		 * Order matches typelib — prefer stock ABI without copying stock headers.
		 */
		private void emit_gtype_struct_fields(
			GLib.FileStream stream,
			HeaderConfig cfg,
			GI.StructInfo si
		) {
			for (var f = 0; f < si.get_n_fields(); f++) {
				var field = si.get_field(f);
				var fname = field.get_name();
				var ti = field.get_type();
				if (ti.get_tag() == GI.TypeTag.GTYPE) {
					stream.printf("  GType %s;\n", fname);
					continue;
				}
				if (ti.get_tag() != GI.TypeTag.INTERFACE) {
					stream.printf(
						"  %s %s;\n",
						this.field_c_type(cfg, ti),
						fname);
					continue;
				}
				var iface = ti.get_interface();
				if (iface == null) {
					stream.printf("  gpointer %s;\n", fname);
					continue;
				}
				switch (iface.get_type()) {
				case GI.InfoType.CALLBACK:
					stream.puts(
						this.callback_field_decl(
							cfg, fname, (GI.CallbackInfo) iface));
					break;
				default:
					/* parent_class / g_iface / parent_iface */
					stream.printf(
						"  %s %s;\n",
						this.field_c_type(cfg, ti),
						fname);
					break;
				}
			}
		}

		private string callback_field_decl(
			HeaderConfig cfg,
			string fname,
			GI.CallbackInfo cb
		) {
			var ret = this.type_c(cfg, cb.get_return_type(), false);
			string[] args = {};
			for (var a = 0; a < cb.get_n_args(); a++) {
				var arg = cb.get_arg(a);
				if (arg.is_skip()) {
					continue;
				}
				args += this.arg_c_decl(cfg, arg);
			}
			if (args.length == 0) {
				return @"  $(ret) (* $(fname)) (void);\n";
			}
			return @"  $(ret) (* $(fname)) ($(string.joinv(", ", args)));\n";
		}

		private string arg_c_decl(HeaderConfig cfg, GI.ArgInfo arg)
		{
			var ti = arg.get_type();
			var dir = arg.get_direction();
			/* OUT/INOUT scalars become pointers in C. */
			var as_ptr = dir == GI.Direction.OUT || dir == GI.Direction.INOUT;
			var ctype = this.type_c(cfg, ti, as_ptr);
			/* Stock uses const sparingly; GIR transfer-none on structs is too
			 * broad (PaintContext/PaintVolume). Only ActorBox + strings. */
			if (dir == GI.Direction.IN
				&& arg.get_ownership_transfer() == GI.Transfer.NOTHING
				&& ti.is_pointer()
				&& !ctype.has_prefix("const ")
				&& (this.type_is_actor_box(ti)
					|| ti.get_tag() == GI.TypeTag.UTF8
					|| ti.get_tag() == GI.TypeTag.FILENAME)) {
				ctype = "const " + ctype;
			}
			return @"$(ctype) $(arg.get_name())";
		}

		private bool type_is_actor_box(GI.TypeInfo ti)
		{
			if (ti.get_tag() != GI.TypeTag.INTERFACE) {
				return false;
			}
			var iface = ti.get_interface();
			return iface != null
				&& iface.get_type() == GI.InfoType.STRUCT
				&& iface.get_name() == "ActorBox";
		}

		private string type_c(HeaderConfig cfg, GI.TypeInfo ti, bool force_ptr)
		{
			var base_type = this.field_c_type(cfg, ti);
			var ptr = force_ptr || ti.is_pointer();
			/* GIR marks object args as INTERFACE + pointer; avoid "Foo * *". */
			if (force_ptr && ti.is_pointer()
				&& ti.get_tag() == GI.TypeTag.INTERFACE) {
				var iface = ti.get_interface();
				if (iface != null) {
					switch (iface.get_type()) {
					case GI.InfoType.OBJECT:
					case GI.InfoType.INTERFACE:
					case GI.InfoType.STRUCT:
					case GI.InfoType.UNION:
						return base_type; /* already has * */
					default:
						break;
					}
				}
			}
			if (ptr && !base_type.has_suffix("*") && base_type != "void") {
				return base_type + " *";
			}
			if (force_ptr && base_type == "void") {
				return "gpointer";
			}
			return base_type;
		}

		private void emit_object_method_protos(
			GLib.FileStream stream,
			HeaderConfig cfg,
			GI.ObjectInfo oi,
			string methods_extra = ""
		) {
			for (var m = 0; m < oi.get_n_methods(); m++) {
				var mi = oi.get_method(m);
				var sym = mi.get_symbol();
				if (sym != null && sym != ""
					&& methods_extra != ""
					&& (methods_extra.contains(sym + " (")
						|| methods_extra.contains(sym + "("))) {
					continue;
				}
				this.emit_function_proto(stream, cfg, mi);
			}
			var cs = oi.get_class_struct();
			if (cs != null) {
				for (var m = 0; m < cs.get_n_methods(); m++) {
					this.emit_function_proto(stream, cfg, cs.get_method(m));
				}
			}
		}

		private void emit_interface_method_protos(
			GLib.FileStream stream,
			HeaderConfig cfg,
			GI.InterfaceInfo ii
		) {
			for (var m = 0; m < ii.get_n_methods(); m++) {
				this.emit_function_proto(stream, cfg, ii.get_method(m));
			}
		}

		private void emit_function_proto(
			GLib.FileStream stream,
			HeaderConfig cfg,
			GI.FunctionInfo fi
		) {
			var symbol = fi.get_symbol();
			if (symbol == null || symbol == "") {
				return;
			}
			var flags = fi.get_flags();
			var ret = this.type_c(cfg, fi.get_return_type(), false);
			string[] args = {};
			/* GIR omits the instance parameter from get_n_args(). */
			if ((flags & GI.FunctionInfoFlags.IS_METHOD) != 0) {
				var self_t = this.container_c_ptr(cfg, fi.get_container());
				if (self_t != null) {
					args += @"$(self_t) self";
				}
			}
			for (var a = 0; a < fi.get_n_args(); a++) {
				var arg = fi.get_arg(a);
				if (arg.is_skip()) {
					continue;
				}
				args += this.arg_c_decl(cfg, arg);
			}
			if (args.length == 0) {
				stream.printf("%s %s (void);\n", ret, symbol);
			} else {
				stream.printf(
					"%s %s (%s);\n",
					ret, symbol, string.joinv(", ", args));
			}
		}

		/** {@code ClutterActor *} / {@code ClutterActorClass *} for method self. */
		private string? container_c_ptr(HeaderConfig cfg, GI.BaseInfo? container)
		{
			if (container == null) {
				return null;
			}
			switch (container.get_type()) {
			case GI.InfoType.OBJECT:
				return ((GI.ObjectInfo) container).get_type_name() + " *";
			case GI.InfoType.INTERFACE:
				var iri = (GI.RegisteredTypeInfo) container;
				return iri.get_type_name() + " *";
			case GI.InfoType.STRUCT:
			case GI.InfoType.UNION:
				var mapped = this.gir_c_name(cfg, container);
				if (mapped != null && mapped != "") {
					return mapped + " *";
				}
				try {
					var sri = (GI.RegisteredTypeInfo) container;
					var rtn = sri.get_type_name();
					if (rtn != null && rtn != "") {
						return rtn + " *";
					}
				} catch (GLib.Error e) {
					/* fall through */
				}
				var ns = container.get_namespace();
				var name = container.get_name();
				if (ns == this.c_prefix(cfg) || ns == cfg.file_prefix
					|| (ns != null && ns.down() == cfg.file_prefix)) {
					/* ActorClass → ClutterActorClass */
					return this.c_prefix(cfg) + name + " *";
				}
				mapped = cfg.c_type_for(ns, name);
				if (mapped != null) {
					return mapped + " *";
				}
				return this.c_prefix(cfg) + name + " *";
			default:
				return null;
			}
		}

		private string field_c_type(HeaderConfig cfg, GI.TypeInfo ti)
		{
			switch (ti.get_tag()) {
				case GI.TypeTag.VOID:
					return ti.is_pointer() ? "gpointer" : "void";
				case GI.TypeTag.BOOLEAN:  return "gboolean";
				case GI.TypeTag.INT8:     return "gint8";
				case GI.TypeTag.UINT8:    return "guint8";
				case GI.TypeTag.INT16:    return "gint16";
				case GI.TypeTag.UINT16:   return "guint16";
				case GI.TypeTag.INT32:    return "gint32";
				case GI.TypeTag.UINT32:   return "guint32";
				case GI.TypeTag.INT64:    return "gint64";
				case GI.TypeTag.UINT64:   return "guint64";
				case GI.TypeTag.FLOAT:    return "gfloat";
				case GI.TypeTag.DOUBLE:   return "gdouble";
				case GI.TypeTag.GTYPE:    return "GType";
				case GI.TypeTag.UTF8:
				case GI.TypeTag.FILENAME: return "gchar *";
				default: break;
			}
			if (ti.get_tag() != GI.TypeTag.INTERFACE) {
				return ti.is_pointer() ? "gpointer" : "guint8";
			}
			var iface = ti.get_interface();
			if (iface == null) {
				return ti.is_pointer() ? "gpointer" : "guint8";
			}
			switch (iface.get_type()) {
			case GI.InfoType.OBJECT:
				var omapped = this.gir_c_name(cfg, iface);
				if (omapped != null && omapped != "") {
					return omapped + (ti.is_pointer() ? " *" : "");
				}
				return ((GI.ObjectInfo) iface).get_type_name()
					+ (ti.is_pointer() ? " *" : "");
			case GI.InfoType.INTERFACE:
				var imapped = this.gir_c_name(cfg, iface);
				if (imapped != null && imapped != "") {
					return imapped + (ti.is_pointer() ? " *" : "");
				}
				var iri = (GI.RegisteredTypeInfo) iface;
				var itn = iri.get_type_name();
				if (itn == null || itn == "") {
					itn = this.gir_c_name(cfg, iface);
				}
				/* GIR sometimes yields "GParam" for ParamSpec. */
				if (iface.get_name() == "ParamSpec") {
					itn = "GParamSpec";
				}
				return itn + (ti.is_pointer() ? " *" : "");
			case GI.InfoType.STRUCT:
			case GI.InfoType.UNION:
				var mapped = this.gir_c_name(cfg, iface);
				if (mapped != null && mapped != "") {
					return mapped + (ti.is_pointer() ? " *" : "");
				}
				try {
					var sri = (GI.RegisteredTypeInfo) iface;
					var rtn = sri.get_type_name();
					if (rtn != null && rtn != "") {
						return rtn + (ti.is_pointer() ? " *" : "");
					}
				} catch (GLib.Error e) {
					/* not a registered type */
				}
				var ins = iface.get_namespace();
				var iname = iface.get_name();
				if (ins != null && ins != "") {
					return ins + iname
						+ (ti.is_pointer() ? " *" : "");
				}
				return this.c_prefix(cfg) + iname
					+ (ti.is_pointer() ? " *" : "");
			case GI.InfoType.ENUM:
			case GI.InfoType.FLAGS:
				var ens = iface.get_namespace();
				if (ens != null && ens != ""
					&& ens != this.c_prefix(cfg)) {
					return ens + iface.get_name();
				}
				return this.c_prefix(cfg) + iface.get_name();
			default:
				return ti.is_pointer() ? "gpointer" : "guint8";
			}
		}

		/**
		 * Resolve C name via {@link HeaderConfig.c_types}, else null.
		 */
		private string? gir_c_name(HeaderConfig cfg, GI.BaseInfo iface)
		{
			var ins = iface.get_namespace();
			var iname = iface.get_name();
			if (ins == null || iname == null) {
				return null;
			}
			return cfg.c_type_for(ins, iname);
		}

		private void write_umbrella(
			string ns_dir,
			Gee.ArrayList<string> per_type,
			HeaderConfig cfg
		) throws GLib.Error {
			var path = GLib.Path.build_filename(ns_dir, cfg.umbrella);
			var stream = GLib.FileStream.open(path, "w");
			if (stream == null) {
				throw new GLib.IOError.FAILED("cannot write " + path);
			}
			stream.puts(
				"/* Generated by gi-stub-gen emit-headers — do not edit */\n");
			stream.puts("#pragma once\n\n");
			stream.printf("#define %s\n\n", cfg.inside_macro);
			foreach (var suffix in cfg.fixed) {
				var file = cfg.stem(suffix) + ".h";
				stream.printf("#include \"%s\"\n", cfg.include_path(file));
			}
			foreach (var stem in per_type) {
				stream.printf(
					"#include \"%s\"\n", cfg.include_path(stem + ".h"));
			}
			foreach (var suffix in cfg.extra) {
				var file = cfg.stem(suffix) + ".h";
				stream.printf("#include \"%s\"\n", cfg.include_path(file));
			}
			stream.printf("\n#undef %s\n", cfg.inside_macro);
		}
	}
}
