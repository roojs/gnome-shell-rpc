/**
 * Resolve a compositor {@link Clutter.InputDevice} from a live peer and/or
 * name.
 *
 * Used by grab / pad Helpers (plan 0.5.5 D). Object wins; else match
 * {@link Clutter.InputDevice.get_device_name}; else default pointer (or
 * first pad when {@code want_pad}).
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Devices : GLib.Object
	{
		public static Clutter.InputDevice? resolve(
			Clutter.InputDevice? device,
			string name,
			bool want_pad = false
		) {
			if (device != null) {
				return device;
			}
			var seat = Clutter.get_default_backend().get_default_seat();
			if (name.length > 0) {
				foreach (var d in seat.list_devices()) {
					if (d.get_device_name() == name) {
						return d;
					}
				}
			}
			if (want_pad) {
				foreach (var d in seat.list_devices()) {
					if (d.get_device_type() ==
							Clutter.InputDeviceType.PAD_DEVICE) {
						return d;
					}
				}
				return null;
			}
			return seat.get_pointer();
		}
	}
}
