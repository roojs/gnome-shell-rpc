/**
 * Signal shape of {@code Shell.PolkitAuthenticationAgent.initiate}.
 *
 * {@link LengthAgent} is the Vala default: a {@code GStrv} plus a length.
 * GJS aborts on that shape. {@link StrvAgent} registers five parameters
 * ending in {@code G_TYPE_STRV}, from {@code polkit-initiate-shape-strv.c}.
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

	[CCode (cname = "polkit_initiate_shape_strv_agent_register_initiate")]
	public extern void register_strv_initiate(GLib.Type type);

	/**
	 * Stock shape: five parameters, last is {@code G_TYPE_STRV}.
	 * A Vala signal still registers a sixth {@code int} length.
	 */
	public class StrvAgent : GLib.Object
	{
		/**
		 * Register during class init. GJS does not see a signal
		 * added from the instance constructor.
		 */
		static construct
		{
			register_strv_initiate(typeof(StrvAgent));
		}

		/**
		 * Emit one user name. No length argument.
		 */
		public void fire()
		{
			string[] names = { "alan" };
			GLib.Signal.emit_by_name(
				this,
				"initiate",
				"com.ubuntu.release-upgrader.release-upgrade",
				"upgrade",
				"system-software-update",
				"cookie",
				names
			);
		}
	}
}
