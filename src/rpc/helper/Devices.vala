/**
 * Resolve a compositor {@link Clutter.InputDevice} from lease id and/or name.
 *
 * Used by grab / pad Helpers (plan 0.5.5 D). Lease wins; else match
 * {@link Clutter.InputDevice.get_device_name}; else default pointer (or
 * first pad when {@code want_pad}).
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Devices : GLib.Object
	{
		public static Clutter.InputDevice? resolve(
			OLLMrpc.Transport.Connection connection,
			uint64 lease_id,
			string name,
			bool want_pad = false
		) {
			if (lease_id != 0) {
				return (Clutter.InputDevice) connection.leases.get(
					(int) lease_id);
			}
			var seat = Clutter.get_default_backend().get_default_seat();
			if (name.length > 0) {
				foreach (var device in seat.list_devices()) {
					if (device.get_device_name() == name) {
						return device;
					}
				}
			}
			if (want_pad) {
				foreach (var device in seat.list_devices()) {
					if (device.get_device_type() ==
							Clutter.InputDeviceType.PAD_DEVICE) {
						return device;
					}
				}
				return null;
			}
			return seat.get_pointer();
		}
	}
}
