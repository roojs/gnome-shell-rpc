/**
 * Client side of {@link Gsr.Server.Meta.KeyBindingOverride}.
 *
 * The stub {@link Meta.KeyBinding} is one unused byte. The five getters
 * gjs calls are the C symbols in {@code key-binding-wire.c}, fed from
 * the values stored here for the life of the signal handler.
 */
namespace Shell
{
	internal class KeyBindingOverride : OLLMrpc.Bin.TypeOverride
	{
		static Gee.ArrayList<void*>? held;

		[CCode (cname = "gsr_key_binding_hold")]
		private static extern void gsr_key_binding_hold(void* box, string name,
			uint modifiers, uint mask, bool builtin, bool reversed);

		[CCode (cname = "gsr_key_binding_release")]
		private static extern void gsr_key_binding_release(void* box);

		public override GLib.Type override_type {
			get { return typeof(Meta.KeyBinding); }
		}

		public override void release()
		{
			if (held == null || held.size == 0) {
				return;
			}
			var box = held.get(held.size - 1);
			held.remove_at(held.size - 1);
			gsr_key_binding_release(box);
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			return OLLMrpc.args("suubb", "", (uint) 0, (uint) 0, false, false);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 5;
			var box = GLib.malloc0(1);
			var name = fields.get(index).get_string();
			gsr_key_binding_hold(box, name != null ? name : "",
				fields.get(index + 1).get_uint(), fields.get(index + 2).get_uint(),
				fields.get(index + 3).get_boolean(), fields.get(index + 4).get_boolean());
			if (held == null) {
				held = new Gee.ArrayList<void*>();
			}
			held.add(box);
			var v = GLib.Value(typeof(Meta.KeyBinding));
			v.take_boxed(box);
			return v;
		}

		internal static void register()
		{
			OLLMrpc.Bin.TypeOverride.register(new KeyBindingOverride());
		}
	}
}
