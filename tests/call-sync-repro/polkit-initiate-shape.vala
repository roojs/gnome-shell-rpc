/**
 * Signal shape of {@code Shell.PolkitAuthenticationAgent.initiate}.
 *
 * {@link LengthAgent} is the Vala default: a {@code GStrv} plus a length.
 * {@link StrvAgent} is the stock C shape: a {@code GStrv} and no length.
 * GJS aborts on the length shape inside
 * {@code gjs_value_from_array_and_length_values}.
 */
namespace PolkitInitiateShape
{
	/**
	 * Emits {@code initiate} the way the current Vala signal does.
	 */
	public class LengthAgent : GLib.Object
	{
		/**
		 * Four strings, then {@code user_names} with a generated length.
		 */
		public signal void initiate(
			string action_id,
			string message,
			string icon_name,
			string cookie,
			string[] user_names
		);

		/**
		 * Emit one user name. GJS is expected to abort in the handler setup.
		 */
		public void fire()
		{
			this.initiate(
				"com.ubuntu.release-upgrader.release-upgrade",
				"upgrade",
				"system-software-update",
				"cookie",
				{ "alan" }
			);
		}
	}

	/**
	 * Emits {@code initiate} the way stock {@code g_signal_new} does.
	 */
	public class StrvAgent : GLib.Object
	{
		/**
		 * Four strings, then a null-terminated {@code user_names}.
		 */
		public signal void initiate(
			string action_id,
			string message,
			string icon_name,
			string cookie,
			[CCode (array_length = false, array_null_terminated = true)]
			string[] user_names
		);

		/**
		 * Emit one user name. GJS should deliver it as a string array.
		 */
		public void fire()
		{
			this.initiate(
				"com.ubuntu.release-upgrader.release-upgrade",
				"upgrade",
				"system-software-update",
				"cookie",
				{ "alan" }
			);
		}
	}
}
