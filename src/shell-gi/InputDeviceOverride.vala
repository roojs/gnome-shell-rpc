/**
 * Client rebuild of a {@link Clutter.InputDevice} from a signal argument.
 *
 * The server packs {@code MetaInputDeviceX11} as its device type.
 * A leased device arrives as the object.
 */
namespace Shell
{
	internal class InputDeviceOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get {
				return typeof(Clutter.InputDevice);
			}
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			var fields = new Gee.ArrayList<GLib.Value?>();
			fields.add(src);
			return fields;
		}

		/**
		 * One uint becomes a local device with that type. An object
		 * is the leased device.
		 *
		 * @param fields the notification arguments
		 * @param index first field for this argument
		 * @param consumed how many fields this argument used
		 */
		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 1;
			var v = GLib.Value(typeof(Clutter.InputDevice));
			if (index >= fields.size) {
				consumed = 0;
				return v;
			}
			var src = fields.get(index);
			if (src.holds(typeof(uint))) {
				var dev = new Clutter.InputDevice();
				dev.device_type = (Clutter.InputDeviceType) src.get_uint();
				v.set_object(dev);
				return v;
			}
			if (src.holds(typeof(GLib.Object))) {
				v.set_object(src.get_object());
			}
			return v;
		}
	}

	[CCode (cname = "shell_input_device_override_register")]
	public void input_device_override_register()
	{
		OLLMrpc.Bin.TypeOverride.register(new InputDeviceOverride());
	}
}
