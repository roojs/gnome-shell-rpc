/**
 * Server pack of a {@link global::Clutter.Event}: type, x, y, button, key symbol,
 * related actor.
 *
 * The client rebuilds the event. A crossing event's related actor is the
 * last field. Uint64 0 means there is none.
 */
namespace Gsr.Server.Clutter
{
	public class ClutterEventOverride : OLLMrpc.Bin.TypeOverride
	{
		/**
		 * GType this override replaces on the wire.
		 */
		public override GLib.Type override_type {
			get {
				return typeof(global::Clutter.Event);
			}
		}

		/**
		 * Write src as type, x, y, button, key symbol, related actor.
		 *
		 * @param src the signal argument
		 * @return fields in wire order
		 */
		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			var ev = (global::Clutter.Event) src.get_boxed();
			var x = 0f;
			var y = 0f;
			ev.get_coords(out x, out y);
			var button = 0u;
			var key = 0u;
			global::Clutter.Actor? related = null;
			switch (ev.get_type()) {
				case global::Clutter.EventType.BUTTON_PRESS:
				case global::Clutter.EventType.BUTTON_RELEASE:
				case global::Clutter.EventType.PAD_BUTTON_PRESS:
				case global::Clutter.EventType.PAD_BUTTON_RELEASE:
					button = ev.get_button();
					break;
				case global::Clutter.EventType.KEY_PRESS:
				case global::Clutter.EventType.KEY_RELEASE:
					key = ev.get_key_symbol();
					break;
				case global::Clutter.EventType.ENTER:
				case global::Clutter.EventType.LEAVE:
					related = ev.get_related();
					break;
				default:
					break;
			}
			var fields = OLLMrpc.args("idduu",
				(int) ev.get_type(),
				(double) x, (double) y,
				button,
				key);
			if (related == null) {
				fields.add(OLLMrpc.val("t", (uint64) 0));
			} else {
				fields.add(OLLMrpc.val("o", related));
			}
			var scroll = 0u;
			if (ev.get_type() == global::Clutter.EventType.SCROLL) {
				scroll = (uint) ev.get_scroll_source();
			}
			fields.add(OLLMrpc.val("u", scroll));
			var device_type = -1;
			unowned var device = ev.get_source_device();
			if (device != null) {
				device_type = (int) device.get_device_type();
			}
			fields.add(OLLMrpc.val("i", device_type));
			return fields;
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
			consumed = 8;
			return GLib.Value(typeof(global::Clutter.Event));
		}
	}
}
