namespace Gsr.Shared
{
	/**
	 * One {@link Clutter.Event} on the signal wire.
	 *
	 * Named properties, not a positional field list. Actors and the
	 * device tool are lease ids. {@link related_object},
	 * {@link source_object}, and {@link tool_object} are filled by the
	 * compositor and exported while this object is written.
	 *
	 * == Example ==
	 *
	 * {{{
	 * OLLMrpc.Bin.register("Clutter-EventState", typeof(Gsr.Shared.ClutterEventState));
	 * var row = new Gsr.Shared.ClutterEventState() {
	 *     event_type = 4, x = 10, y = 20,
	 * };
	 * }}}
	 */
	public class ClutterEventState : GLib.Object, OLLMrpc.Bin.Serializable
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register(
				"Clutter-EventState", typeof(ClutterEventState));
		}

		public int event_type { get; set; default = 0; }
		public uint flags { get; set; default = 0; }
		public uint time { get; set; default = 0; }
		public int64 time_us { get; set; default = 0; }
		public uint state { get; set; default = 0; }
		public int device_type { get; set; default = -1; }
		public double x { get; set; default = 0; }
		public double y { get; set; default = 0; }
		public uint button { get; set; default = 0; }
		public uint key_symbol { get; set; default = 0; }
		public uint key_code { get; set; default = 0; }
		public uint key_unicode { get; set; default = 0; }
		public uint key_pressed { get; set; default = 0; }
		public uint key_latched { get; set; default = 0; }
		public uint key_locked { get; set; default = 0; }
		public uint scroll_direction { get; set; default = 0; }
		public double scroll_dx { get; set; default = 0; }
		public double scroll_dy { get; set; default = 0; }
		public uint scroll_source { get; set; default = 0; }
		public uint scroll_finish { get; set; default = 0; }
		public int sequence_slot { get; set; default = -1; }
		public uint touchpad_fingers { get; set; default = 0; }
		public double pinch_angle { get; set; default = 0; }
		public double pinch_scale { get; set; default = 0; }
		public uint gesture_phase { get; set; default = 0; }
		public double gesture_dx { get; set; default = 0; }
		public double gesture_dy { get; set; default = 0; }
		public double gesture_udx { get; set; default = 0; }
		public double gesture_udy { get; set; default = 0; }
		public uint mode_group { get; set; default = 0; }
		public bool pad_ok { get; set; default = false; }
		public uint pad_number { get; set; default = 0; }
		public uint pad_mode { get; set; default = 0; }
		public uint pad_source { get; set; default = 0; }
		public double pad_value { get; set; default = 0; }
		public uint event_code { get; set; default = 0; }
		public bool rel_ok { get; set; default = false; }
		public double rel_dx { get; set; default = 0; }
		public double rel_dy { get; set; default = 0; }
		public double rel_udx { get; set; default = 0; }
		public double rel_udy { get; set; default = 0; }
		public double rel_cdx { get; set; default = 0; }
		public double rel_cdy { get; set; default = 0; }
		public string im_text { get; set; default = ""; }
		public int im_offset { get; set; default = 0; }
		public int im_anchor { get; set; default = 0; }
		public bool im_loc { get; set; default = false; }
		public uint im_delete { get; set; default = 0; }
		public uint im_preedit { get; set; default = 0; }
		/** Comma-separated axis values. Empty when the event has none. */
		public string axes { get; set; default = ""; }
		public uint64 related { get; set; default = 0; }
		public uint64 source { get; set; default = 0; }
		public uint64 device_tool { get; set; default = 0; }

		/** Filled by the compositor. Exported into {@link related}. */
		public GLib.Object? related_object;
		/** Filled by the compositor. Exported into {@link source}. */
		public GLib.Object? source_object;
		/** Filled by the compositor. Exported into {@link device_tool}. */
		public GLib.Object? tool_object;

		/**
		 * Export nested actors, then write the property.
		 *
		 * @param ctx active bin session
		 * @param prop property metadata
		 */
		public override void bin_write_prop(
			OLLMrpc.Bin.Stream ctx,
			GLib.ParamSpec prop
		) throws GLib.Error
		{
			switch (prop.name) {
				case "related":
					if (this.related_object != null) {
						this.related = ctx.connection.export(this.related_object);
					}
					break;
				case "source":
					if (this.source_object != null) {
						this.source = ctx.connection.export(this.source_object);
					}
					break;
				case "device-tool":
					if (this.tool_object != null) {
						this.device_tool = ctx.connection.export(this.tool_object);
					}
					break;
				default:
					break;
			}
			this.bin_default_write_prop(ctx, prop);
		}
	}
}
