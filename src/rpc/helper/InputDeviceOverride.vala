/**
 * Server pack of a {@link Clutter.InputDevice}.
 *
 * A {@code MetaInputDeviceX11} is dropped. Any other device is written
 * unchanged.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class InputDeviceOverride : OLLMrpc.Bin.TypeOverride
	{
		/**
		 * GType this override replaces on the wire.
		 */
		public override GLib.Type override_type {
			get {
				return typeof(Clutter.InputDevice);
			}
		}

		/**
		 * Drop an X11 device. Pass any other device through.
		 *
		 * @param src the signal argument
		 * @return no fields for {@code MetaInputDeviceX11}, otherwise src
		 */
		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			var device = src.get_object();
			if (device != null
					&& device.get_type().name() == "MetaInputDeviceX11") {
				return new Gee.ArrayList<GLib.Value?>();
			}
			var fields = new Gee.ArrayList<GLib.Value?>();
			fields.add(src);
			return fields;
		}

		/**
		 * Unused on the compositor. The client does not rebuild a device.
		 *
		 * @param fields the notification arguments
		 * @param index first field for this argument
		 * @param consumed how many fields this argument used
		 * @return an empty device value
		 */
		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 0;
			return GLib.Value(typeof(Clutter.InputDevice));
		}
	}
}
