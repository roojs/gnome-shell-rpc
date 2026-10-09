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
		return event_from_values(Gsr.Client.Rpc.call_value("Gsr-Clutter.event_get").args);
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
