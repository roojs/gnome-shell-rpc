/**
 * Wire form of a {@link Clutter.Event}: type, x, y, button, key symbol,
 * related actor.
 */
namespace Shell
{
	internal class ClutterEventOverride : OLLMrpc.Bin.TypeOverride
	{
		static Gee.ArrayList<void*>? held;

		[CCode (cname = "clutter_event_free")]
		private static extern void free_stacked(Clutter.Event ev);

		/**
		 * Drop the event pushed by the latest {@link unpack}.
		 */
		public override void release()
		{
			if (held == null || held.size == 0) {
				return;
			}
			var raw = held.get(held.size - 1);
			held.remove_at(held.size - 1);
			ClutterEventOverride.free_stacked((Clutter.Event) raw);
		}

		/**
		 * GType this override replaces on the wire.
		 */
		public override GLib.Type override_type {
			get {
				return typeof(Clutter.Event);
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
			unowned var ev = (Clutter.Event) src.get_boxed();
			var x = 0f;
			var y = 0f;
			ev.get_coords(out x, out y);
			var button = 0u;
			var key = 0u;
			Clutter.Actor? related = null;
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
				case Clutter.EventType.enter:
				case Clutter.EventType.leave:
					related = ev.get_related();
					break;
				default:
					break;
			}
			var fields = OLLMrpc.args("idduu",
				(int) ev.type(),
				(double) x, (double) y,
				button,
				key);
			if (related == null) {
				fields.add(OLLMrpc.val("t", (uint64) 0));
			} else {
				fields.add(OLLMrpc.val("o", related));
			}
			fields.add(OLLMrpc.val("u", (uint) ev.get_scroll_source()));
			var device_type = -1;
			var device = ev.get_source_device();
			if (device != null) {
				device_type = (int) device.device_type;
			}
			fields.add(OLLMrpc.val("i", device_type));
			fields.add(OLLMrpc.val("u", ev.get_time()));
			return fields;
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
			consumed = 9;
			var ev = Clutter.Event.from_local(
				(Clutter.EventType) fields.get(index).get_int(),
				(float) fields.get(index + 1).get_double(),
				(float) fields.get(index + 2).get_double(),
				fields.get(index + 3).get_uint(),
				0,
				fields.get(index + 4).get_uint(),
				Clutter.Event.actor_from_value(fields.get(index + 5)));
			ev.read_scroll_tail(fields, index + 6);
			if (ev.type() == Clutter.EventType.button_press
					|| ev.type() == Clutter.EventType.button_release) {
				GLib.debug("type=%d button=%u time=%u",
					(int) ev.type(), ev.get_button(), ev.get_time());
			}
			if (ClutterEventOverride.held == null) {
				ClutterEventOverride.held = new Gee.ArrayList<void*>();
			}
			var copy = ev.copy();
			void* raw = (owned) copy;
			ClutterEventOverride.held.add(raw);
			var v = GLib.Value(typeof(Clutter.Event));
			v.set_pointer(raw);
			return v;
		}

		internal static void register()
		{
			OLLMrpc.Bin.TypeOverride.register(new ClutterEventOverride());
		}
	}
}
