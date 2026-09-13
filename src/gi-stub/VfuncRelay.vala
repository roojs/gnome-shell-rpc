/**
 * Vfunc detection + sentinel — no toolkit peer names here.
 * Override-defined relay_* own Live.Hook bind bodies; generated
 * bind_vfunc calls those methods.
 */
namespace GnomeShellRpc.GiStub
{
	public class VfuncRelay
	{
		/** Object whose live hook is running; null when idle. */
		public static GLib.Object? hook_actor;
		/** No JS override → fall through to server base / chain. */
		public static bool use_base;
		static Gee.HashMap<GLib.Type, Gee.HashSet<string>>? caps_by_type;

		public static void begin(GLib.Object self)
		{
			use_base = false;
			hook_actor = self;
		}

		public static void end()
		{
			hook_actor = null;
		}

		/**
		 * Names whose Class slot differs from baseline, plus {@code always}.
		 *
		 * @param ns typelib namespace
		 * @param class_name typelib class (slots compared on this class struct)
		 * @param baseline_gtype_name GType name for compare (empty → {@code type})
		 * @param always names always included (may be empty)
		 */
		public static Gee.HashSet<string> overridden(
			GLib.Type type,
			string ns,
			string class_name,
			string baseline_gtype_name,
			string[] always
		) {
			if (caps_by_type == null) {
				caps_by_type = new Gee.HashMap<GLib.Type, Gee.HashSet<string>>();
			}
			if (caps_by_type.has_key(type)) {
				return caps_by_type.get(type);
			}
			var baseline = GLib.Type.INVALID;
			if (baseline_gtype_name != null && baseline_gtype_name != "") {
				baseline = GLib.Type.from_name(baseline_gtype_name);
			}
			if (baseline == GLib.Type.INVALID) {
				baseline = type;
			}
			var always_set = new Gee.HashSet<string>();
			foreach (var n in always) {
				always_set.add(n);
			}
			var overridden = new Gee.HashSet<string>();
			foreach (var name in OLLMrpc.Gi.vfunc_names(ns, class_name)) {
				if (always_set.contains(name)) {
					overridden.add(name);
					continue;
				}
				var cur = OLLMrpc.Gi.vfunc_slot(type, ns, class_name, name);
				var base_slot = OLLMrpc.Gi.vfunc_slot(
					baseline, ns, class_name, name);
				if (cur != base_slot) {
					overridden.add(name);
				}
			}
			caps_by_type.set(type, overridden);
			return overridden;
		}
	}
}
