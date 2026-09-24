/**
 * Wire form of a {@link Clutter.Event}: type, x, y, button, key symbol.
 *
 * Registered from {@link GnomeShellRpc.GiStub.Runtime.register} with the
 * other client bin types.
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
		 * Write src as type, x, y, button, key symbol.
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
				default:
					break;
			}
			return OLLMrpc.args("idduu",
				(int) ev.type(),
				(double) x, (double) y,
				button,
				key);
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
			consumed = 5;
			var ev = Clutter.Event.from_local(
				(Clutter.EventType) fields.get(index).get_int(),
				(float) fields.get(index + 1).get_double(),
				(float) fields.get(index + 2).get_double(),
				fields.get(index + 3).get_uint(),
				0,
				fields.get(index + 4).get_uint());
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
	}

	/**
	 * FIXME - this is horrible 
	 Register the client {@link ClutterEventOverride}.
	 *
	 * gi-stub cannot name this internal class. {@link GnomeShellRpc.GiStub.Runtime.register}
	 * calls this C trampoline next to the other bin registrations.
	 */
	[CCode (cname = "shell_clutter_event_override_register")]
	public void clutter_event_override_register()
	{
		OLLMrpc.Bin.TypeOverride.register(new ClutterEventOverride());
	}
}
