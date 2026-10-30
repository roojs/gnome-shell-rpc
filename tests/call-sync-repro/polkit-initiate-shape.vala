/**
 * Signal shape of {@code Shell.PolkitAuthenticationAgent.initiate}.
 *
 * {@link LengthAgent} is the Vala default: a {@code GStrv} plus a length.
 * GJS aborts on that shape. {@link StrvAgent} marks {@code user_names} as a
 * null-terminated string array.
 */
namespace PolkitInitiateShape
{
	/**
	 * Emits {@code initiate} the way the Vala signal does.
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
	 * Same signal, with {@code user_names} null-terminated and no length.
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
		 * Emit one user name.
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
