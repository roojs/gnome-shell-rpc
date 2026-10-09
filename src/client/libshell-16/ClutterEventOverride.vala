/**
 * Wire form of a {@link Clutter.Event}: one
 * {@link Gsr.Shared.ClutterEventState}.
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
		 * One {@link Gsr.Shared.ClutterEventState}.
		 *
		 * @param src the signal argument
		 * @return that object
		 */
		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			unowned var ev = (Clutter.Event) src.get_boxed();
			var state = new Gsr.Shared.ClutterEventState();
			ClutterEventOverride.fill(state, ev);
			var fields = new Gee.ArrayList<GLib.Value?>();
			fields.add(OLLMrpc.val("o", state));
			return fields;
		}

		/**
		 * Copy the compact fields this event type stores.
		 *
		 * @param state the object to send
		 * @param ev the local event
		 */
		static void fill(Gsr.Shared.ClutterEventState state, Clutter.Event ev)
		{
			var x = 0f;
			var y = 0f;
			ev.get_coords(out x, out y);
			state.event_type = (int) ev.type();
			state.flags = ev.get_flags();
			state.time = ev.get_time();
			var device = ev.get_source_device();
			if (device != null) {
				state.device_type = (int) device.device_type;
			}
			switch (ev.type()) {
				case Clutter.EventType.button_press:
				case Clutter.EventType.button_release:
				case Clutter.EventType.motion:
				case Clutter.EventType.scroll:
				case Clutter.EventType.enter:
				case Clutter.EventType.leave:
				case Clutter.EventType.touch_begin:
				case Clutter.EventType.touch_update:
				case Clutter.EventType.touch_end:
				case Clutter.EventType.touchpad_pinch:
				case Clutter.EventType.touchpad_swipe:
				case Clutter.EventType.touchpad_hold:
					state.x = x;
					state.y = y;
					break;
				default:
					break;
			}
			switch (ev.type()) {
				case Clutter.EventType.button_press:
				case Clutter.EventType.button_release:
					state.button = ev.get_button();
					state.state = (uint) ev.get_state();
					break;
				case Clutter.EventType.pad_button_press:
				case Clutter.EventType.pad_button_release:
					state.button = ev.get_button();
					break;
				case Clutter.EventType.motion:
					state.state = (uint) ev.get_state();
					break;
				case Clutter.EventType.key_press:
				case Clutter.EventType.key_release:
					state.key_symbol = ev.get_key_symbol();
					state.state = (uint) ev.get_state();
					break;
				case Clutter.EventType.scroll:
					state.state = (uint) ev.get_state();
					state.scroll_direction = (uint) ev.get_scroll_direction();
					var dx = 0.0;
					var dy = 0.0;
					ev.get_scroll_delta(out dx, out dy);
					state.scroll_dx = dx;
					state.scroll_dy = dy;
					state.scroll_source = (uint) ev.get_scroll_source();
					break;
				case Clutter.EventType.enter:
				case Clutter.EventType.leave:
					if (ev.get_related() != null && ev.get_related().rpc_lid != 0) {
						state.related = ev.get_related().rpc_lid;
					}
					break;
				case Clutter.EventType.touch_begin:
				case Clutter.EventType.touch_update:
				case Clutter.EventType.touch_end:
					state.state = (uint) ev.get_state();
					if (ev.sequence_slot >= 0) {
						state.sequence_slot = ev.sequence_slot;
					}
					break;
				case Clutter.EventType.touch_cancel:
					if (ev.sequence_slot >= 0) {
						state.sequence_slot = ev.sequence_slot;
					}
					break;
				default:
					break;
			}
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
			consumed = 1;
			var ev = new Clutter.Event.local(
				Clutter.EventType.nothing, 0, 0, 0);
			if (index < fields.size) {
				var state = fields.get(index).get_object()
					as Gsr.Shared.ClutterEventState;
				if (state != null) {
					ev.apply_state(state);
				}
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
