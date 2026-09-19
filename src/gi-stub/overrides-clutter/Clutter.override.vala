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
		var response = GnomeShellRpc.call_value(
			"Helper-Clutter.get_current_event", null);
		if (response.args.size < 5) {
			current_event_cache = null;
			return null;
		}
		var keyval = 0u;
		if (response.args.size > 5) {
			keyval = response.args.get(5).get_uint();
		}
		current_event_cache = new Event.local(
			(EventType) response.args.get(0).get_int(),
			(float) response.args.get(1).get_double(),
			(float) response.args.get(2).get_double(),
			response.args.get(3).get_uint(),
			response.args.get(4).get_uint(),
			keyval);
		return current_event_cache;
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
	 * {@code c-clutter-frame-type.c} (same boxed pattern as Event).
	 *
	 * GIR {@code get_count} / {@code set_result} / … take mutter's
	 * {@code ClutterFrame*}. This peer has no such object (size-0 boxed,
	 * no {@code rpc_lid}). Do not stub them.
	 */
	[CCode (cname = "ClutterFrame", cheader_filename = "gsr-clutter-effect-abi.h", copy_function = "clutter_frame_copy", free_function = "clutter_frame_free", type_id = "CLUTTER_TYPE_FRAME")]
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
	 * denied in generator; fields match header-overrides/Event.h.
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

		public Event.local(
			EventType type,
			float x,
			float y,
			uint32 button,
			uint32 state = 0,
			uint32 keyval = 0
		) {
			this.event_type = type;
			this.x = x;
			this.y = y;
			this.button = button;
			this.state = state;
			this.keyval = keyval;
		}

		public static Event from_local(
			EventType type,
			float x,
			float y,
			uint32 button,
			uint32 state = 0,
			uint32 keyval = 0
		) {
			return new Event.local(type, x, y, button, state, keyval);
		}

		[CCode (cname = "clutter_event_copy")]
		public Event copy() {
			return new Event.local(
				this.event_type, this.x, this.y, this.button,
				this.state, this.keyval);
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

		[CCode (cname = "clutter_event_get_key_symbol")]
		public uint get_key_symbol() {
			return this.keyval;
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
		var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			return OLLMrpc.args("b", func(data));
		});
		var response = GnomeShellRpc.call_value(
			"Helper-ClutterThreads.threads_add_repaint_func", null,
			OLLMrpc.args("ut", (uint) flags, callback_id));
		return (uint32) response.retval.get_uint();
	}
