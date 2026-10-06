	[CCode (cname = "clutter_get_default_text_direction")]
	public static TextDirection get_default_text_direction()
	{
		return TextDirection.ltr;
	}

	/**
	 * Stock {@code clutter_get_current_event} — compositor packs type / coords /
	 * button / state into Compact {@link Event} (transfer none via cache).
	 */
	private static Event? current_event_cache;

	[CCode (cname = "clutter_get_current_event")]
	public static unowned Event? get_current_event()
	{
		var response = Gsr.Client.Rpc.call_value(
			"Gsr-Clutter.get_current_event");
		current_event_cache = event_from_values(response.args);
		return current_event_cache;
	}

	private static Event? event_from_values(
		Gee.ArrayList<GLib.Value?> fields
	)
	{
		if (fields.size < 5) {
			return null;
		}
		var keyval = 0u;
		if (fields.size > 5) {
			keyval = fields.get(5).get_uint();
		}
		Actor? related = null;
		if (fields.size > 6) {
			related = Event.actor_from_value(fields.get(6));
		}
		var ev = new Event.local(
			(EventType) fields.get(0).get_int(),
			(float) fields.get(1).get_double(),
			(float) fields.get(2).get_double(),
			fields.get(3).get_uint(),
			fields.get(4).get_uint(),
			keyval,
			related);
		ev.read_scroll_tail(fields, 7);
		return ev;
	}

	/**
	 * Stock filter callback: event, the device actor, user data.
	 * {@code CLUTTER_EVENT_STOP} / {@code TRUE} swallows the event.
	 */
	[CCode (has_target = false)]
	public delegate bool EventFilterFunc(
		Event event,
		Actor? event_actor,
		void* user_data
	);

	private class EventFilterRegistration : GLib.Object
	{
		public uint id;
		public uint64 callback_id;
		public GLib.DestroyNotify? destroy_notify;
		public void* user_data;
	}

	private static EventFilterRegistration[] event_filters;

	/**
	 * Stock {@code clutter_event_add_filter}. The filter runs synchronously
	 * in the compositor and relays the event here; the returned boolean keeps
	 * Clutter's stop/propagate semantics.
	 */
	public static uint event_add_filter(
		Stage? stage,
		EventFilterFunc func,
		GLib.DestroyNotify? notify,
		void* user_data
	) {
		var callback_id = Gsr.Client.Rpc.callback_bind((call) => {
			var event = event_from_values(call.args);
			if (event == null) {
				return OLLMrpc.args("b", false);
			}
			Actor? event_actor = null;
			if (call.args.size > 9) {
				event_actor = Event.actor_from_value(call.args.get(9));
			}
			return OLLMrpc.args(
				"b", func(event, event_actor, user_data));
		});
		var stage_lid = stage == null ? 0 : stage.rpc_lid;
		var response = Gsr.Client.Rpc.call_value(
			"Gsr-Clutter.event_add_filter", null,
			OLLMrpc.args("tt", stage_lid, callback_id));
		var row = new EventFilterRegistration() {
			id = response.retval.get_uint(),
			callback_id = callback_id,
			destroy_notify = notify,
			user_data = user_data,
		};
		event_filters += row;
		return row.id;
	}

	/**
	 * Stock {@code clutter_event_remove_filter}. Drops a registration
	 * from {@link event_add_filter} and runs its destroy notify.
	 */
	public static void event_remove_filter(uint id)
	{
		EventFilterRegistration[] kept = {};
		foreach (var row in event_filters) {
			if (row.id != id) {
				kept += row;
				continue;
			}
			Gsr.Client.Rpc.call_value(
				"Gsr-Clutter.event_remove_filter", null,
				OLLMrpc.args("u", id));
			Gsr.Client.Rpc.callback_unbind(row.callback_id);
			if (row.destroy_notify != null) {
				row.destroy_notify(row.user_data);
			}
		}
		event_filters = kept;
	}

	/**
	 * Stock {@code clutter_event_get}: pop on the compositor's Clutter
	 * queue, then rebuild the event locally from its packed fields.
	 */
	public static Event? event_get()
	{
		return event_from_values(Gsr.Client.Rpc.call_value(
			"Gsr-Clutter.event_get").args);
	}

	/**
	 * Opaque sequence handle; {@link get_slot} stub until Clutter Event RPC exists.
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
	 * Opaque boxed {@code ClutterFrame} (GIR record, size 0). Compact so
	 * {@code typeof(Frame)} is a boxed GType for {@code Bin.register}
	 * {@code Clutter-Frame} — {@code before-update} arg. GType lives in
	 * {@code c-clutter-abi.c} (same boxed pattern as Event).
	 *
	 * GIR {@code get_count} / {@code set_result} / … take mutter's
	 * {@code ClutterFrame*}. This peer has no such object (size-0 boxed,
	 * no {@code rpc_lid}). Do not stub them.
	 */
	[CCode (cname = "ClutterFrame", cheader_filename = "namespace.h", copy_function = "clutter_frame_copy", free_function = "clutter_frame_free", type_id = "CLUTTER_TYPE_FRAME")]
	[Compact]
	public class Frame
	{
		public uint8 _unused;

		[CCode (cname = "clutter_frame_copy")]
		public Frame copy()
		{
			var copy = new Frame();
			copy._unused = this._unused;
			return copy;
		}
	}

	/**
	 * Compact ClutterEvent* (GJS typelib union). Sole Clutter GIR union —
	 * denied in Clutter.deny; fields match header-overrides/Event.h.
	 * copy_function is required for Vala to emit clutter_event_get_type.
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

		public Event.local(
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
			this.event_type = type;
			this.x = x;
			this.y = y;
			this.button = button;
			this.state = state;
			this.keyval = keyval;
			this.related = related;
			this.scroll_source = (uint32) scroll_source;
			this.source_device = source_device;
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
		 * Scroll source and source-device type packed after the event's
		 * other fields. Device type {@code -1} means there is no device.
		 */
		public void read_scroll_tail(
			Gee.ArrayList<GLib.Value?> fields,
			int index
		) {
			if (fields.size <= index) {
				return;
			}
			this.scroll_source = fields.get(index).get_uint();
			if (fields.size <= index + 1) {
				return;
			}
			var device_type = fields.get(index + 1).get_int();
			if (device_type < 0) {
				return;
			}
			var device = new InputDevice();
			device.device_type = (InputDeviceType) device_type;
			this.source_device = device;
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
			return new Event.local(
				this.event_type, this.x, this.y, this.button,
				this.state, this.keyval, this.related,
				(ScrollSource) this.scroll_source, this.source_device);
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
			/* Locally reconstructed relay events currently carry no flags. */
			return 0;
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
	}

	/**
	 * GType-struct methods (generator skips is_gtype_struct). St class_init +
	 * typelib.
	 *
	 * @param actor_class {@code ClutterActorClass*}
	 * @param type layout manager {@link GLib.Type}
	 */
	[CCode (cname = "clutter_actor_class_set_layout_manager_type")]
	public static void actor_class_set_layout_manager_type(
		GLib.TypeClass actor_class,
		GLib.Type type
	) {
		actor_class.get_type().set_qdata(
			GLib.Quark.from_string("gsr-layout-manager-type"),
			(void*) (uint64) type
		);
	}

	/**
	 * @param actor_class {@code ClutterActorClass*}
	 * @return layout manager type, or {@link GLib.Type.INVALID}
	 */
	[CCode (cname = "clutter_actor_class_get_layout_manager_type")]
	public static GLib.Type actor_class_get_layout_manager_type(
		GLib.TypeClass actor_class
	) {
		return (GLib.Type) (uint64) actor_class.get_type().get_qdata(
			GLib.Quark.from_string("gsr-layout-manager-type"));
	}

	/**
	 * C {@code GSourceFunc} — {@code has_target = false} so the export matches
	 * stock {@code clutter_threads_add_repaint_func} (no Vala delegate target).
	 */
	[CCode (has_target = false)]
	public delegate bool ThreadsRepaintFunc(void* data);

	/**
	 * Register a compositor-side repaint hook; fires back via live callback
	 * (same pattern as {@link Meta.IdleMonitor.add_idle_watch}).
	 *
	 * @param flags pre/post paint section
	 * @param func C function pointer from libshell
	 * @param data user data for {@code func}
	 * @param notify destroy notify (unused when null; shell passes null)
	 * @return handle for {@link threads_remove_repaint_func}
	 */
	[CCode (cname = "clutter_threads_add_repaint_func")]
	public static uint32 threads_add_repaint_func(
		RepaintFlags flags,
		ThreadsRepaintFunc func,
		void* data,
		GLib.DestroyNotify? notify
	) {
		var callback_id = Gsr.Client.Rpc.callback_bind((call) => {
			return OLLMrpc.args("b", func(data));
		});
		var response = Gsr.Client.Rpc.call_value(
			"Gsr-Clutter-Threads.threads_add_repaint_func",
			null,
			OLLMrpc.args("ut", (uint) flags, callback_id));
		return (uint32) response.retval.get_uint();
	}
