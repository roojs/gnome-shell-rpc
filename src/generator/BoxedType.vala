namespace Gsr.Generator
{
	/**
	 * Boxed-type TypeOverride step run from {@link Generator.emit}.
	 *
	 * The constructor takes the {@link Generator} that is emitting, and the
	 * generation stays here. A sized record is a Vala assignment into
	 * {@link GLib.Bytes}. A record with no size packs an empty list.
	 * A boxed type with no override and no deny fails the emit.
	 *
	 * == Example ==
	 *
	 * {{{
	 * var boxed = new BoxedType(gen);
	 * boxed.emit("Clutter", "Clutter_generated.vala");
	 * }}}
	 */
	public class BoxedType : GLib.Object
	{
		private Generator generator;

		/**
		 * @param generator the emit that owns deny, overrides, and the typelib
		 */
		public BoxedType(Generator generator)
		{
			this.generator = generator;
		}

		/**
		 * Write boxed-type overrides beside {@code out_path}.
		 *
		 * {@code Foo.vala} is written as {@code Foo_boxed.vala}. Same {@code emit}
		 * command. No extra argument.
		 *
		 * @param ns GI namespace just emitted
		 * @param out_path stub path from {@link Generator.emit}
		 */
		public void emit(string ns, string out_path) throws GLib.Error
		{
			var names = new Gee.ArrayList<string>();
			var missing = new Gee.ArrayList<string>();
			var stream = this.open(out_path);
			this.walk(ns, stream, names, missing);
			this.walk_listed(stream, names, missing);
			this.finish(stream, ns, names);
			if (missing.size == 0) {
				return;
			}
			throw new GLib.IOError.FAILED(
				"boxed type has no override and no deny: "
				+ string.joinv(", ", missing.to_array())
			);
		}

		/**
		 * Typelibs named by the overrides file ({@code Namespace boxed}).
		 * Each entry is the typelib's own {@code Name-Version}.
		 *
		 * @param stream boxed-type Vala file
		 * @param names class names written, in order
		 * @param missing types with no override and no deny
		 */
		private void walk_listed(
			GLib.FileStream stream,
			Gee.ArrayList<string> names,
			Gee.ArrayList<string> missing
		) throws GLib.Error
		{
			if (!this.generator.overrides.has_key("Namespace")) {
				return;
			}
			if (!this.generator.overrides.get("Namespace").has_key("boxed")) {
				return;
			}
			var listed = this.generator.overrides.get("Namespace").get("boxed");
			var repo = GI.Repository.get_default();
			foreach (var item in listed.split(",")) {
				var spec = item.strip();
				if (spec == "") {
					continue;
				}
				var dash = spec.last_index_of("-");
				if (dash <= 0) {
					throw new GLib.IOError.FAILED(
						"boxed typelib is not Name-Version: " + spec
					);
				}
				var dep_ns = spec.substring(0, dash);
				var dep_ver = spec.substring(dash + 1);
				repo.require(dep_ns, dep_ver, 0);
				this.walk(dep_ns, stream, names, missing);
			}
		}

		/**
		 * Walk one namespace that is already loaded. A sized record is a byte
		 * copy. Size 0 packs nothing. {@code Ns.Name} in the deny is left out.
		 *
		 * @param ns GI namespace
		 * @param stream boxed-type Vala file
		 * @param names class names written, in order
		 * @param missing types with no override and no deny
		 */
		private void walk(
			string ns,
			GLib.FileStream stream,
			Gee.ArrayList<string> names,
			Gee.ArrayList<string> missing
		) throws GLib.Error
		{
			var repo = GI.Repository.get_default();
			var n_infos = repo.get_n_infos(ns);
			for (var i = 0; i < n_infos; i++) {
				var info = repo.get_info(ns, i);
				var kind = info.get_type();
				if (kind != GI.InfoType.STRUCT && kind != GI.InfoType.UNION) {
					continue;
				}
				var name = info.get_name();
				if (name == null || name == "") {
					continue;
				}
				if (name.has_suffix("Class") || name.has_suffix("Private")) {
					continue;
				}
				if (name.has_suffix("Interface")) {
					continue;
				}
				if ((ns + "." + name) in this.generator.deny) {
					continue;
				}
				if (kind != GI.InfoType.STRUCT) {
					if (!(name in this.generator.deny)) {
						missing.add(ns + "." + name);
					}
					continue;
				}
				var si = (GI.StructInfo) info;
				if (si.is_gtype_struct() || si.is_foreign()) {
					if (!(name in this.generator.deny)) {
						missing.add(ns + "." + name);
					}
					continue;
				}
				var ri = (GI.RegisteredTypeInfo) si;
				var type_init = ri.get_type_init();
				if (type_init == null || type_init == "") {
					continue;
				}
				var cls = ns + name + "Override";
				names.add(cls);
				if (si.get_size() > 0) {
					this.append_copy(stream, ns, name, cls);
					continue;
				}
				this.append_empty(stream, ns, name, cls);
			}
		}

		/**
		 * One {@link GLib.Bytes} of {@code sizeof(name)}, Vala assignment both ways.
		 *
		 * @param stream boxed-type Vala file
		 * @param ns GI namespace
		 * @param name GI record name
		 * @param cls generated class name
		 */
		private void append_copy(
			GLib.FileStream stream,
			string ns,
			string name,
			string cls
		)
		{
			var qual = "global::" + ns + "." + name;
			stream.puts(@"
	public class $(cls) : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof($(qual)); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			uint8[] data = new uint8[sizeof($(qual))];
			if (src.get_boxed() != null) {
				*(($(qual)*) data) = *(($(qual)*) src.get_boxed());
			}
			return this.pack_bytes(data);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			var data = this.unpack_bytes(
				fields, index, out consumed, (int) sizeof($(qual)));
			var v = GLib.Value(typeof($(qual)));
			v.set_boxed((void*) data);
			return v;
		}
	}
");
		}

		/**
		 * Size 0: empty list, {@code consumed} 0, empty value of that GType.
		 *
		 * @param stream boxed-type Vala file
		 * @param ns GI namespace
		 * @param name GI record name
		 * @param cls generated class name
		 */
		private void append_empty(
			GLib.FileStream stream,
			string ns,
			string name,
			string cls
		)
		{
			var qual = "global::" + ns + "." + name;
			stream.puts(@"
	public class $(cls) : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof($(qual)); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			return new Gee.ArrayList<GLib.Value?>();
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 0;
			return GLib.Value(typeof($(qual)));
		}
	}
");
		}

		/**
		 * Open the boxed-type Vala file and write the file header.
		 *
		 * {@code Foo.vala} is written as {@code Foo_boxed.vala}.
		 *
		 * @param out_path stub path from {@link Generator.emit}
		 * @return stream positioned after the namespace opening brace
		 */
		private GLib.FileStream open(string out_path) throws GLib.Error
		{
			var boxed_path = out_path;
			if (boxed_path.has_suffix(".vala")) {
				boxed_path = boxed_path.substring(0, boxed_path.length - 5);
			}
			boxed_path = boxed_path + "_boxed.vala";
			var stream = GLib.FileStream.open(boxed_path, "w");
			if (stream == null) {
				throw new GLib.IOError.FAILED("cannot write " + boxed_path);
			}
			stream.puts("""/* Generated by gi-stub-gen — do not edit */
namespace Gsr.Boxed
{
""");
			return stream;
		}

		/**
		 * @param stream boxed-type Vala file, after the generated classes
		 * @param ns GI namespace this emit started from
		 * @param names class names written, in order
		 */
		private void finish(
			GLib.FileStream stream,
			string ns,
			Gee.ArrayList<string> names
		)
		{
			stream.puts(@"
	public void register_$(ns)_boxed_types()
	{
");
			foreach (var name in names) {
				stream.puts(
					@"		OLLMrpc.Bin.TypeOverride.register(new $(name)());
"
				);
			}
			stream.puts(@"	}
}
");
		}
	}
}
