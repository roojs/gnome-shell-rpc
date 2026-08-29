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
	 * GType-struct method; not emitted (is_gtype_struct skipped). St class_init needs it.
	 */
	[CCode (cname = "clutter_actor_class_set_layout_manager_type")]
	public static void actor_class_set_layout_manager_type(
		void* actor_class,
		GLib.Type type
	) {
		GLib.error("gi-stub: Clutter.actor_class_set_layout_manager_type not wired");
	}
