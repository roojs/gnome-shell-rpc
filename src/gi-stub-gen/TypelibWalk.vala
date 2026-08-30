namespace GnomeShellRpc.GiStubGen
{
	/**
	 * Shared typelib walk + deny/override policy for {@link Generator} and
	 * {@link HeaderGenerator}. No library-specific header layout here —
	 * see {@link HeaderConfig}.
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
	}
}
