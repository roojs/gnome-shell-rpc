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
		var response = GnomeShellRpc.GiStub.Runtime.call_values(
			"Helper-ClutterThreads.threads_add_repaint_func", null,
			OLLMrpc.args("ut", (uint) flags, callback_id));
		return (uint32) response.args.get(0).get_uint();
	}
