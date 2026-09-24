/**
 * Wire form of a {@link Clutter.Event}: type, x, y, button, key symbol.
 *
 * Registered from {@link Shell.Signals} so client unpack and any emit in
 * this process share one override.
 */
namespace Shell
{
	internal class ClutterEventOverride : OLLMrpc.Bin.TypeOverride
	{
		/**
		 * GType this override replaces on the wire.
		 */
		public override GLib.Type override_type {
			get {
				return typeof(Clutter.Event);
			}
		}

		/**
		 * Write src as type, x, y, button, key symbol.
		 *
		 * @param src the signal argument
		 * @return fields in wire order
		 */
		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			unowned var ev = (Clutter.Event) src.get_boxed();
			var x = 0f;
			var y = 0f;
			ev.get_coords(out x, out y);
			var button = 0u;
			var key = 0u;
			switch (ev.type()) {
				case Clutter.EventType.button_press:
				case Clutter.EventType.button_release:
				case Clutter.EventType.pad_button_press:
				case Clutter.EventType.pad_button_release:
					button = ev.get_button();
					break;
				case Clutter.EventType.key_press:
				case Clutter.EventType.key_release:
					key = ev.get_key_symbol();
					break;
				default:
					break;
			}
			return OLLMrpc.args("idduu",
				(int) ev.type(),
				(double) x, (double) y,
				button,
				key);
		}

		/**
		 * Build a local {@link Clutter.Event} from wire fields.
		 *
		 * @param fields the notification arguments
		 * @param index first field for this argument
		 * @param consumed how many fields this argument used
		 * @return the argument value
		 */
		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 5;
			var ev = Clutter.Event.from_local(
				(Clutter.EventType) fields.get(index).get_int(),
				(float) fields.get(index + 1).get_double(),
				(float) fields.get(index + 2).get_double(),
				fields.get(index + 3).get_uint(),
				0,
				fields.get(index + 4).get_uint());
			var v = GLib.Value(typeof(Clutter.Event));
			v.set_boxed(ev);
			return v;
		}
	}
}
