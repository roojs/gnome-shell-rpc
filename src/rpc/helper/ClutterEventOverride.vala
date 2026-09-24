/**
 * Server pack of a {@link Clutter.Event}: type, x, y, button, key symbol.
 *
 * The client rebuilds the event. This process only writes the fields.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class ClutterEventOverride : OLLMrpc.Bin.TypeOverride
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
			var ev = (Clutter.Event) src.get_boxed();
			var x = 0f;
			var y = 0f;
			ev.get_coords(out x, out y);
			var button = 0u;
			var key = 0u;
			switch (ev.get_type()) {
				case Clutter.EventType.BUTTON_PRESS:
				case Clutter.EventType.BUTTON_RELEASE:
				case Clutter.EventType.PAD_BUTTON_PRESS:
				case Clutter.EventType.PAD_BUTTON_RELEASE:
					button = ev.get_button();
					break;
				case Clutter.EventType.KEY_PRESS:
				case Clutter.EventType.KEY_RELEASE:
					key = ev.get_key_symbol();
					break;
				default:
					break;
			}
			return OLLMrpc.args("idduu",
				(int) ev.get_type(),
				(double) x, (double) y,
				button,
				key);
		}

		/**
		 * Unused on the compositor. The client owns {@code from_local}.
		 *
		 * @param fields the notification arguments
		 * @param index first field for this argument
		 * @param consumed how many fields this argument used
		 * @return an empty event value
		 */
		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 5;
			return GLib.Value(typeof(Clutter.Event));
		}
	}
}
