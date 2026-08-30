namespace GnomeShellRpc.GiStubGen
{
	/**
	 * Shared typelib walk + deny/override policy for {@link Generator} and
	 * {@link HeaderGenerator}. Includes scalar GIR→C helpers ({@link type_c_scalar});
	 * header layout stays in {@link HeaderConfig}.
	 */
	public class TypelibWalk : GLib.Object
	{
		/** Denylisted symbols omitted on emit; {@code Type.method} or bare name. */
		public string[] deny = {};

		/** Same names as {@link deny}, but emit an empty / dummy-return stub. */
		public string[] noop = {};

		/**
		 * {@code Type.method} or bare {@code Type} → override keys
		 * (e.g. {@code list_elem=WindowActor}, {@code emit=union-as-class}).
		 */
		public Gee.HashMap<string, Gee.HashMap<string, string>> overrides =
			new Gee.HashMap<string, Gee.HashMap<string, string>>();

		/** Lookup a type-level policy from {@link overrides} (bare type name). */
		protected string? type_policy(string type_name, string key)
		{
			if (!this.overrides.has_key(type_name)) {
				return null;
			}
			var map = this.overrides.get(type_name);
			if (!map.has_key(key)) {
				return null;
			}
			return map.get(key);
		}

		public void require_typelib(string ns, string version) throws GLib.Error
		{
			GI.Repository.get_default().require(ns, version, 0);
		}

		public delegate void InfoCallback(GI.BaseInfo info);

		public void foreach_info(string ns, InfoCallback cb)
		{
			var n_infos = GI.Repository.get_default().get_n_infos(ns);
			for (var i = 0; i < n_infos; i++) {
				cb(GI.Repository.get_default().get_info(ns, i));
			}
		}

		/**
		 * GIR type name → stock-ish kebab file stem ({@code ActorMeta} →
		 * {@code actor-meta}).
		 */
		public static string to_kebab(string name)
		{
			var sb = new GLib.StringBuilder();
			for (var i = 0; i < name.length; i++) {
				var c = name[i];
				if (c >= 'A' && c <= 'Z') {
					if (i > 0) {
						var prev = name[i - 1];
						var next_lower = (i + 1 < name.length
							&& name[i + 1] >= 'a'
							&& name[i + 1] <= 'z');
						var prev_lower = (prev >= 'a' && prev <= 'z');
						var prev_upper = (prev >= 'A' && prev <= 'Z');
						if (prev_lower || (prev_upper && next_lower)) {
							sb.append_c('-');
						}
					}
					sb.append_c((char) (c + 32));
				} else {
					sb.append_c(c);
				}
			}
			return sb.str;
		}

		/**
		 * Scalar / string GIR tags → C type names for {@link HeaderGenerator}.
		 * Empty string means the caller must handle the tag (INTERFACE, ARRAY, …).
		 */
		protected string type_c_scalar(GI.TypeInfo ti)
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
				default:                 return "";
			}
		}
	}
}
