/**
 * Client {@link Clutter.Event}. The GIR union is denied; this compact
 * class is what GJS calls. Fields through {@code time} match
 * {@code header-overrides/Event.h}.
 */
namespace Clutter
{
	/**
	 * Opaque sequence handle. {@link get_slot} is still a stub.
	 */
	public struct EventSequence
	{
		public uint8 _unused;

		public int get_slot()
		{
			GLib.error("gi-stub: Clutter-EventSequence.get_slot not implemented");
			return -1;
		}
	}

	/**
	 * Compact {@code ClutterEvent}. {@code copy_function} is required
	 * for Vala to emit {@code clutter_event_get_type}.
	 */
	[CCode (cname = "ClutterEvent", copy_function = "clutter_event_copy", free_function = "clutter_event_free", has_type_id = true)]
	[Compact]
	public class Event
	{
		[CCode (cname = "type")]
		public EventType event_type;
		public float x;
		public float y;
		public uint32 button;
		public uint32 state;
		public uint32 keyval;
		public Actor? related;
		public uint32 scroll_source;
		public InputDevice? source_device;
		public uint32 time;
		public uint32 scroll_direction;
		public double scroll_dx;
		public double scroll_dy;
		public uint32 flags;
		/** {@code -1} when the event has no touch sequence. */
		public int sequence_slot = -1;

		public Event.local(
			EventType type,
			float x,
			float y,
			uint32 button,
			uint32 state = 0,
			uint32 keyval = 0,
			Actor? related = null,
			ScrollSource scroll_source = ScrollSource.unknown,
			InputDevice? source_device = null,
			uint32 time = 0
		) {
			this.event_type = type;
			this.x = x;
			this.y = y;
			this.button = button;
			this.state = state;
			this.keyval = keyval;
			this.related = related;
			this.scroll_source = (uint32) scroll_source;
			this.source_device = source_device;
			this.time = time;
		}

		public static Event from_local(
			EventType type,
			float x,
			float y,
			uint32 button,
			uint32 state = 0,
			uint32 keyval = 0,
			Actor? related = null,
			ScrollSource scroll_source = ScrollSource.unknown,
			InputDevice? source_device = null
		) {
			return new Event.local(
				type, x, y, button, state, keyval, related,
				scroll_source, source_device);
		}

		/**
		 * Scroll source, source-device type, then event time, packed after
		 * the event's other fields. Device type {@code -1} means there is
		 * no device. Time is {@code clutter_event_get_time}.
		 */
		public void read_scroll_tail(
			Gee.ArrayList<GLib.Value?> fields,
			int index
		) {
			if (fields.size <= index) {
				return;
			}
			this.scroll_source = fields.get(index).get_uint();
			if (fields.size > index + 1) {
				var device_type = fields.get(index + 1).get_int();
				if (device_type >= 0) {
					var device = new InputDevice();
					device.device_type = (InputDeviceType) device_type;
					this.source_device = device;
				}
			}
			if (fields.size > index + 2) {
				this.time = fields.get(index + 2).get_uint();
			}
			if (fields.size > index + 3) {
				this.scroll_direction = fields.get(index + 3).get_uint();
			}
			if (fields.size > index + 5) {
				this.scroll_dx = fields.get(index + 4).get_double();
				this.scroll_dy = fields.get(index + 5).get_double();
			}
		}

		/**
		 * Related actor from a wire field. Uint64 0 is none. An object
		 * is the leased actor. A non-zero uint64 is that actor's lease id.
		 */
		public static Actor? actor_from_value(GLib.Value src)
		{
			if (src.holds(typeof(uint64))) {
				var lid = (int) src.get_uint64();
				if (lid == 0 || Gsr.Client.Rpc.client == null) {
					return null;
				}
				return Gsr.Client.Rpc.client.proxies.get(lid) as Actor;
			}
			if (src.type().is_a(typeof(GLib.Object))) {
				return src.get_object() as Actor;
			}
			return null;
		}

		[CCode (cname = "clutter_event_copy")]
		public Event copy() {
			var ev = new Event.local(
				this.event_type, this.x, this.y, this.button,
				this.state, this.keyval, this.related,
				(ScrollSource) this.scroll_source, this.source_device,
				this.time);
			ev.scroll_direction = this.scroll_direction;
			ev.scroll_dx = this.scroll_dx;
			ev.scroll_dy = this.scroll_dy;
			ev.flags = this.flags;
			ev.sequence_slot = this.sequence_slot;
			return ev;
		}

		/**
		 * Copy the fields this event type stores.
		 *
		 * @param state the object from the notification
		 */
		public void apply_state(Gsr.Shared.ClutterEventState state)
		{
			this.event_type = (EventType) state.event_type;
			this.flags = state.flags;
			this.time = state.time;
			if (state.device_type >= 0) {
				var device = new InputDevice();
				device.device_type = (InputDeviceType) state.device_type;
				this.source_device = device;
			}
			switch (this.event_type) {
				case EventType.button_press:
				case EventType.button_release:
					this.x = (float) state.x;
					this.y = (float) state.y;
					this.button = state.button;
					this.state = state.state;
					break;
				case EventType.key_press:
				case EventType.key_release:
					this.keyval = state.key_symbol;
					this.state = state.state;
					break;
				case EventType.motion:
					this.x = (float) state.x;
					this.y = (float) state.y;
					this.state = state.state;
					break;
				case EventType.enter:
				case EventType.leave:
					this.x = (float) state.x;
					this.y = (float) state.y;
					this.sequence_slot = state.sequence_slot;
					if (state.related != 0 && Gsr.Client.Rpc.client != null) {
						this.related = Gsr.Client.Rpc.client.proxies.get(
							(int) state.related) as Actor;
					}
					break;
				case EventType.scroll:
					this.x = (float) state.x;
					this.y = (float) state.y;
					this.state = state.state;
					this.scroll_direction = state.scroll_direction;
					this.scroll_dx = state.scroll_dx;
					this.scroll_dy = state.scroll_dy;
					this.scroll_source = state.scroll_source;
					break;
				case EventType.touch_begin:
				case EventType.touch_update:
				case EventType.touch_end:
					this.x = (float) state.x;
					this.y = (float) state.y;
					this.state = state.state;
					this.sequence_slot = state.sequence_slot;
					break;
				case EventType.touch_cancel:
					this.sequence_slot = state.sequence_slot;
					break;
				case EventType.touchpad_pinch:
				case EventType.touchpad_swipe:
				case EventType.touchpad_hold:
					this.x = (float) state.x;
					this.y = (float) state.y;
					break;
				default:
					break;
			}
		}

		[CCode (cname = "clutter_event_type")]
		public EventType @type() {
			return this.event_type;
		}

		[CCode (cname = "clutter_event_get_coords")]
		public void get_coords(out float x, out float y) {
			x = this.x;
			y = this.y;
		}

		[CCode (cname = "clutter_event_get_button")]
		public uint32 get_button() {
			return this.button;
		}

		[CCode (cname = "clutter_event_get_state")]
		public ModifierType get_state() {
			return (ModifierType) this.state;
		}

		[CCode (cname = "clutter_event_get_flags")]
		public uint get_flags() {
			return this.flags;
		}

		[CCode (cname = "clutter_event_get_key_symbol")]
		public uint get_key_symbol() {
			return this.keyval;
		}

		/**
		 * Stock {@code clutter_event_get_related}. The other actor of a
		 * crossing event, packed with the event. Null when the event has none.
		 */
		[CCode (cname = "clutter_event_get_related")]
		public unowned Actor? get_related() {
			return this.related;
		}

		/**
		 * Stock {@code clutter_event_get_scroll_source}.
		 */
		[CCode (cname = "clutter_event_get_scroll_source")]
		public ScrollSource get_scroll_source() {
			return (ScrollSource) this.scroll_source;
		}

		/**
		 * Stock {@code clutter_event_get_source_device}. Null when the
		 * packed event has no device.
		 */
		[CCode (cname = "clutter_event_get_source_device")]
		public unowned InputDevice? get_source_device() {
			return this.source_device;
		}

		/**
		 * Stock name shell JS still calls. Mutter 48 removed
		 * {@code clutter_event_get_device}; the packed device is
		 * {@link source_device}.
		 */
		[CCode (cname = "clutter_event_get_device")]
		public unowned InputDevice? get_device() {
			return this.source_device;
		}

		/**
		 * A pointer button has no touch sequence, so this is null.
		 * Slider {@code startDragging} reads it before it moves the handle.
		 */
		public unowned EventSequence? get_event_sequence() {
			return null;
		}

		/**
		 * Wheel notches are up or down. Smooth scrolls use
		 * {@link get_scroll_delta}.
		 */
		public ScrollDirection get_scroll_direction() {
			return (ScrollDirection) this.scroll_direction;
		}

		/**
		 * Zero for a discrete wheel notch.
		 */
		public void get_scroll_delta(out double dx, out double dy) {
			dx = this.scroll_dx;
			dy = this.scroll_dy;
		}

		/**
		 * Stock {@code clutter_event_get_time}. Shell drag code reads this
		 * from a button press. Zero when the packed event carried no time.
		 */
		[CCode (cname = "clutter_event_get_time")]
		public uint32 get_time() {
			return this.time;
		}
	}
}
